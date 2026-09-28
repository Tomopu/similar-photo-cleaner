import Foundation
import Observation
import OSLog
import Photos
import SwiftData
import UIKit

/// 解析とグループ作成に使う設定値（UserDefaults から読む）。
nonisolated struct ScanSettings: Sendable {
    var sensitivity: Sensitivity
    var excludeFavorites: Bool
    var excludeEdited: Bool

    static func current(_ defaults: UserDefaults = .standard) -> ScanSettings {
        ScanSettings(
            sensitivity: Sensitivity(rawValue: defaults.integer(forKey: SettingsKey.sensitivity)) ?? .standard,
            excludeFavorites: defaults.object(forKey: SettingsKey.excludeFavorites) as? Bool ?? true,
            excludeEdited: defaults.object(forKey: SettingsKey.excludeEdited) as? Bool ?? true
        )
    }
}

/// 写真ライブラリのスキャン（差分解析 → 保存 → グループ作成）を進める。
@Observable
final class ScanCoordinator {
    enum Phase: Equatable {
        case idle
        case scanning
        case finished
    }

    private(set) var authorization = PhotoLibrary.authorizationStatus
    private(set) var phase: Phase = .idle
    private(set) var processed = 0
    private(set) var total = 0
    private(set) var screenshotCount = 0
    private(set) var index = LibraryIndex.empty
    /// 解析済みの写真（ID → 結果）。
    private(set) var records: [String: PhotoRecord] = [:]
    private(set) var lastScanDate: Date?
    /// 解析済みの写真が1枚でもあるか。
    private(set) var hasAnalyzedPhotos = false

    private var task: Task<Void, Never>?
    private let batchSize = 32
    private let maxConcurrentAnalyses = 4

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var progress: Double { total == 0 ? 0 : Double(processed) / Double(total) }

    func refreshAuthorization() {
        authorization = PhotoLibrary.authorizationStatus
    }

    func requestAccess() async {
        authorization = await PhotoLibrary.requestAuthorization()
    }

    /// 保存済みの解析結果からグループを作り直す（起動直後や設定変更時）。
    func reloadIndex(context: ModelContext) async {
        let records = ((try? context.fetch(FetchDescriptor<AnalyzedPhoto>())) ?? []).map(\.record)
        self.records = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        hasAnalyzedPhotos = !records.isEmpty
        let settings = ScanSettings.current()
        index = await Task.detached(priority: .userInitiated) {
            LibraryIndex.build(
                from: records,
                sensitivity: settings.sensitivity,
                excludeFavorites: settings.excludeFavorites,
                excludeEdited: settings.excludeEdited
            )
        }.value
        screenshotCount = index.screenshots.count
        logger.debug("解析済み \(records.count) 枚、グループ \(self.index.groups.map(\.photoIDs.count), privacy: .public)")
    }

    /// 削除した写真の解析結果を消して、グループを作り直す。
    func removeDeleted(_ ids: Set<String>, context: ModelContext) async {
        let stored = (try? context.fetch(FetchDescriptor<AnalyzedPhoto>())) ?? []
        for photo in stored where ids.contains(photo.localIdentifier) {
            context.delete(photo)
        }
        try? context.save()
        await reloadIndex(context: context)
    }

    func startScan(context: ModelContext) {
        guard isAuthorized, phase != .scanning else { return }
        task = Task { await run(context: context) }
    }

    func pause() {
        task?.cancel()
    }

    private func run(context: ModelContext) async {
        phase = .scanning
        let snapshots = await Task.detached(priority: .userInitiated) { PhotoLibrary.fetchImageSnapshots() }.value
        let pending = applyLibraryChanges(snapshots, context: context)

        total = snapshots.count
        processed = total - pending.count
        screenshotCount = snapshots.filter(\.isScreenshot).count

        for chunk in pending.chunked(into: batchSize) {
            if Task.isCancelled { break }
            let results = await Self.analyze(Array(chunk), maxConcurrent: maxConcurrentAnalyses)
            for (snapshot, analysis) in results {
                context.insert(AnalyzedPhoto(snapshot: snapshot, analysis: analysis))
            }
            try? context.save()
            processed += chunk.count
        }

        await reloadIndex(context: context)
        if Task.isCancelled {
            phase = .idle
        } else {
            phase = .finished
            lastScanDate = .now
        }
    }

    /// ライブラリから消えた写真の結果を消し、まだ解析していない写真を返す。
    private func applyLibraryChanges(_ snapshots: [AssetSnapshot], context: ModelContext) -> [AssetSnapshot] {
        let stored = (try? context.fetch(FetchDescriptor<AnalyzedPhoto>())) ?? []
        let storedByID = Dictionary(stored.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        let currentIDs = Set(snapshots.map(\.id))
        for photo in stored where !currentIDs.contains(photo.localIdentifier) {
            context.delete(photo)
        }

        var pending: [AssetSnapshot] = []
        for snapshot in snapshots {
            guard let existing = storedByID[snapshot.id] else {
                pending.append(snapshot)
                continue
            }
            // 編集で見た目が変わった写真だけ解析し直す。お気に入りなどはメタデータの更新で済ませる。
            if existing.hasAdjustments != snapshot.hasAdjustments
                || existing.pixelWidth != snapshot.pixelWidth
                || existing.pixelHeight != snapshot.pixelHeight {
                context.delete(existing)
                pending.append(snapshot)
            } else {
                existing.updateMetadata(from: snapshot)
            }
        }
        try? context.save()
        return pending
    }

    /// サムネイルを読み込んで解析する。同時に `maxConcurrent` 枚まで。端末にない写真は飛ばす。
    nonisolated private static func analyze(_ snapshots: [AssetSnapshot], maxConcurrent: Int) async -> [(AssetSnapshot, ImageAnalysis)] {
        let assetsByID = Dictionary(
            PhotoLibrary.assets(withIDs: snapshots.map(\.id)).map { ($0.localIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let analyzer = ImageAnalyzer()

        return await withTaskGroup(of: (AssetSnapshot, ImageAnalysis)?.self) { group in
            var results: [(AssetSnapshot, ImageAnalysis)] = []
            var remaining = snapshots[...]

            func addNext() {
                guard let snapshot = remaining.popFirst() else { return }
                let asset = assetsByID[snapshot.id]
                group.addTask {
                    guard let asset else { return nil }
                    guard let image = await PhotoLibrary.image(for: asset, maxPixel: 512), let cgImage = image.cgImage else {
                        logger.info("サムネイルを取得できないため解析を飛ばす: \(snapshot.id, privacy: .private)")
                        return nil
                    }
                    do {
                        let analysis = try await analyzer.analyze(cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
                        return (snapshot, analysis)
                    } catch {
                        logger.error("解析に失敗: \(error.localizedDescription, privacy: .public)")
                        return nil
                    }
                }
            }

            for _ in 0..<maxConcurrent { addNext() }
            for await result in group {
                if let result { results.append(result) }
                addNext()
            }
            return results
        }
    }
}

nonisolated private let logger = Logger(subsystem: "com.tomopu.SimilarPhotoCleaner", category: "scan")

extension Array {
    nonisolated func chunked(into size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
    }
}
