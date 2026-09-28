import Foundation
import SwiftData

/// 解析キャッシュ（写真ごとの特徴ベクトルとスコア）。写真そのものは入れない。
///
/// ファイルアプリの「このiPhone内 › SimilarPhotoCleaner › 解析キャッシュ」に置く。
/// フォルダごと消されても写真は消えず、次のスキャンで作り直して解析し直す。
final class AnalysisCache {
    /// 保存形式を変えたら上げる。違う値のキャッシュは開くときに捨てて作り直す。
    static let formatVersion = "1"
    static let folderName = "解析キャッシュ"

    let folderURL: URL
    private(set) var container: ModelContainer

    var context: ModelContext { container.mainContext }

    private var storeURL: URL { Self.storeURL(in: folderURL) }

    init(baseURL: URL = .documentsDirectory) throws {
        folderURL = baseURL.appending(path: Self.folderName, directoryHint: .isDirectory)
        try Self.prepareFolder(at: folderURL)
        container = try Self.makeContainer(in: folderURL)
    }

    /// フォルダ（またはデータベース）が外から消されていたら作り直す。作り直したら true。
    @discardableResult
    func reopenIfRemoved() throws -> Bool {
        guard !FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)) else { return false }
        try Self.prepareFolder(at: folderURL)
        container = try Self.makeContainer(in: folderURL)
        return true
    }

    /// キャッシュを空にする（フォルダを消して作り直す）。
    func clear() throws {
        if FileManager.default.fileExists(atPath: folderURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: folderURL)
        }
        try Self.prepareFolder(at: folderURL)
        container = try Self.makeContainer(in: folderURL)
    }

    var count: Int {
        (try? context.fetchCount(FetchDescriptor<AnalyzedPhoto>())) ?? 0
    }

    /// フォルダの中のファイルの合計サイズ。
    var sizeInBytes: Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let files = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    func fetchRecords() -> [PhotoRecord] {
        ((try? context.fetch(FetchDescriptor<AnalyzedPhoto>())) ?? []).map(\.record)
    }

    /// 指定した写真の保存済みの結果だけを取り出す（全件を読み込まない）。
    func fetch(ids: some Collection<String>) -> [AnalyzedPhoto] {
        Array(ids).chunked(into: 500).flatMap { chunk -> [AnalyzedPhoto] in
            let wanted = Array(chunk)
            let descriptor = FetchDescriptor<AnalyzedPhoto>(predicate: #Predicate { wanted.contains($0.localIdentifier) })
            return (try? context.fetch(descriptor)) ?? []
        }
    }

    // MARK: - フォルダとデータベース

    private static func storeURL(in folder: URL) -> URL {
        folder.appending(path: "analysis.store")
    }

    private static func prepareFolder(at folder: URL) throws {
        let fileManager = FileManager.default
        let versionURL = folder.appending(path: "version.txt")
        if fileManager.fileExists(atPath: folder.path(percentEncoded: false)),
           (try? String(contentsOf: versionURL, encoding: .utf8)) != formatVersion {
            try fileManager.removeItem(at: folder)
        }
        guard !fileManager.fileExists(atPath: folder.path(percentEncoded: false)) else { return }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try formatVersion.write(to: versionURL, atomically: true, encoding: .utf8)
        try readme.write(to: folder.appending(path: "このフォルダについて.txt"), atomically: true, encoding: .utf8)
    }

    private static func makeContainer(in folder: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Analysis", schema: Schema([AnalyzedPhoto.self]), url: storeURL(in: folder))
        return try ModelContainer(for: AnalyzedPhoto.self, configurations: configuration)
    }

    private static let readme = """
    このフォルダには、似た写真を探すための解析結果（写真ごとの特徴ベクトルとスコア）が入っています。
    写真そのものは入っていません。

    フォルダごと削除しても写真は消えません。次にアプリでスキャンするときに解析し直します。
    アプリの「設定 › データ › キャッシュを削除」からも削除できます。
    """
}
