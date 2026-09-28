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

/// 写真ライブラリのスキャン（差分解析 → キャッシュへ保存 → グループ作成）を進める。
///
/// 解析結果はメモリ上の `records` とキャッシュ（`AnalysisCache`）の両方に持つ。
/// グループの作り直し（設定変更・削除後）はメモリ上の結果だけで行い、キャッシュを読み直さない。
@Observable
final class ScanCoordinator {
    enum Phase: Equatable {
        case idle
        case scanning
        case finished
    }

    let cache: AnalysisCache

    private(set) var authorization = PhotoLibrary.authorizationStatus
    private(set) var phase: Phase = .idle
    private(set) var processed = 0
    private(set) var total = 0
    private(set) var screenshotCount = 0
    private(set) var index = LibraryIndex.empty
    /// 解析済みの写真（ID → 結果）。キャッシュの中身をメモリに持ったもの。
    private(set) var records: [String: PhotoRecord] = [:]
    private(set) var lastScanDate: Date?

    /// 解析が必要な枚数が決まったとき（バックグラウンド継続の判断に使う）。
    var onScanPlanned: ((Int) -> Void)?
    /// 進み具合（解析済み、全体）。
    var onProgress: ((Int, Int) -> Void)?
    /// スキャンが終わったとき。最後まで終わったら true、途中で止めたら false。
    var onFinished: ((Bool) -> Void)?

    private var task: Task<Void, Never>?
    private var hasLoadedCache = false
    private let batchSize = 32
    private let maxConcurrentAnalyses = 4

    init(cache: AnalysisCache) {
        self.cache = cache
    }

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var progress: Double { total == 0 ? 0 : Double(processed) / Double(total) }
    /// 解析済みの写真が1枚でもあるか。
    var hasAnalyzedPhotos: Bool { !records.isEmpty }

    func refreshAuthorization() {
        authorization = PhotoLibrary.authorizationStatus
    }

    func requestAccess() async {
        authorization = await PhotoLibrary.requestAuthorization()
    }

    /// 起動後に一度だけ、キャッシュをメモリに読み込んでグループを作る。
    func loadFromCache() async {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true
        reopenCacheIfRemoved()
        records = Dictionary(cache.fetchRecords().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        await rebuildIndex()
    }

    /// メモリ上の解析結果からグループを作り直す（設定変更・削除のあと）。キャッシュは読み直さない。
    func rebuildIndex() async {
        let snapshot = Array(records.values)
        let settings = ScanSettings.current()
        index = await Task.detached(priority: .userInitiated) {
            LibraryIndex.build(
                from: snapshot,
                sensitivity: settings.sensitivity,
                excludeFavorites: settings.excludeFavorites,
                excludeEdited: settings.excludeEdited
            )
        }.value
        screenshotCount = index.screenshots.count
        logger.debug("解析済み \(snapshot.count) 枚、グループ \(self.index.groups.map(\.photoIDs.count), privacy: .public)")
    }

    func startScan() {
        guard isAuthorized, phase != .scanning else { return }
        task = Task { await run() }
    }

    func pause() {
        task?.cancel()
    }

    /// 削除した写真の解析結果を消して、グループを作り直す。
    func removeDeleted(_ ids: Set<String>) async {
        for photo in cache.fetch(ids: ids) {
            cache.context.delete(photo)
        }
        try? cache.context.save()
        for id in ids { records[id] = nil }
        await rebuildIndex()
    }

    /// 解析キャッシュを消す。写真は消えない。次のスキャンで全部を解析し直す。
    func clearCache() async throws {
        task?.cancel()
        await task?.value
        try cache.clear()
        records = [:]
        index = .empty
        screenshotCount = 0
        processed = 0
        total = 0
        lastScanDate = nil
        phase = .idle
    }

    private func run() async {
        phase = .scanning
        reopenCacheIfRemoved()
        let snapshots = await Task.detached(priority: .userInitiated) { PhotoLibrary.fetchImageSnapshots() }.value
        let diff = LibraryDiff.compute(snapshots: snapshots, cached: records)
        apply(diff)

        total = snapshots.count
        processed = total - diff.toAnalyze.count
        screenshotCount = snapshots.filter(\.isScreenshot).count
        onScanPlanned?(diff.toAnalyze.count)
        onProgress?(processed, total)

        for chunk in diff.toAnalyze.chunked(into: batchSize) {
            if Task.isCancelled { break }
            let results = await Self.analyze(Array(chunk), maxConcurrent: maxConcurrentAnalyses)
            for (snapshot, analysis) in results {
                let photo = AnalyzedPhoto(snapshot: snapshot, analysis: analysis)
                cache.context.insert(photo)
                records[snapshot.id] = photo.record
            }
            try? cache.context.save()
            processed += chunk.count
            onProgress?(processed, total)
        }

        await rebuildIndex()
        if Task.isCancelled {
            phase = .idle
        } else {
            phase = .finished
            lastScanDate = .now
        }
        onFinished?(phase == .finished)
    }

    /// 消えた写真・解析し直す写真の古い結果を消し、お気に入りなどの変化を反映する。
    private func apply(_ diff: LibraryDiff) {
        if !diff.toRemove.isEmpty {
            for photo in cache.fetch(ids: diff.toRemove) {
                cache.context.delete(photo)
            }
            for id in diff.toRemove { records[id] = nil }
        }
        if !diff.toUpdate.isEmpty {
            let snapshots = Dictionary(diff.toUpdate.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for photo in cache.fetch(ids: snapshots.keys) {
                guard let snapshot = snapshots[photo.localIdentifier] else { continue }
                photo.updateMetadata(from: snapshot)
                records[photo.localIdentifier] = photo.record
            }
        }
        try? cache.context.save()
    }

    /// ファイルアプリなどでキャッシュのフォルダが消されていたら、作り直して全部を解析し直す。
    private func reopenCacheIfRemoved() {
        do {
            if try cache.reopenIfRemoved() {
                logger.info("解析キャッシュが見つからないため作り直した")
                records = [:]
            }
        } catch {
            logger.error("解析キャッシュを開けない: \(error.localizedDescription, privacy: .public)")
        }
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
