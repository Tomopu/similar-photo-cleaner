import Foundation
import SwiftData
import Testing
@testable import SimilarPhotoCleaner

@MainActor
struct AnalysisCacheTests {
    private func makeBase() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "AnalysisCacheTests-\(UUID().uuidString)")
    }

    private func insertPhoto(_ id: String, into cache: AnalysisCache) throws {
        let snapshot = AssetSnapshot(id: id, creationDate: .now, pixelWidth: 100, pixelHeight: 100)
        let analysis = ImageAnalysis(vector: FeatureVector([1, 2, 3]), dHash: 7, aesthetics: 0.5, isUtility: false, faceQuality: nil, sharpness: 10)
        cache.context.insert(AnalyzedPhoto(snapshot: snapshot, analysis: analysis))
        try cache.context.save()
    }

    @Test func createsFolderWithReadmeAndVersion() throws {
        let base = makeBase()
        let cache = try AnalysisCache(baseURL: base)
        let files = try FileManager.default.contentsOfDirectory(atPath: cache.folderURL.path(percentEncoded: false))
        #expect(files.contains("version.txt"))
        #expect(files.contains("このフォルダについて.txt"))
        #expect(cache.folderURL.lastPathComponent == AnalysisCache.folderName)
    }

    @Test func storesAndReadsBackRecords() throws {
        let cache = try AnalysisCache(baseURL: makeBase())
        try insertPhoto("a", into: cache)
        #expect(cache.count == 1)
        let record = try #require(cache.fetchRecords().first)
        #expect(record.vector == FeatureVector([1, 2, 3]))
        #expect(cache.fetch(ids: ["a", "missing"]).map(\.localIdentifier) == ["a"])
    }

    @Test func clearEmptiesTheCacheButKeepsTheFolder() throws {
        let cache = try AnalysisCache(baseURL: makeBase())
        try insertPhoto("a", into: cache)
        try cache.clear()
        #expect(cache.count == 0)
        #expect(FileManager.default.fileExists(atPath: cache.folderURL.path(percentEncoded: false)))
    }

    @Test func recreatesTheCacheWhenTheFolderWasDeletedOutside() throws {
        let cache = try AnalysisCache(baseURL: makeBase())
        try insertPhoto("a", into: cache)
        try FileManager.default.removeItem(at: cache.folderURL)
        #expect(try cache.reopenIfRemoved())
        #expect(cache.count == 0)
        #expect(try !cache.reopenIfRemoved())
    }

    @Test func discardsACacheWithAnOlderFormat() throws {
        let base = makeBase()
        let first = try AnalysisCache(baseURL: base)
        try insertPhoto("a", into: first)
        try "0".write(to: first.folderURL.appending(path: "version.txt"), atomically: true, encoding: .utf8)
        let reopened = try AnalysisCache(baseURL: base)
        #expect(reopened.count == 0)
    }
}
