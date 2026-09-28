import Foundation
import Testing
@testable import SimilarPhotoCleaner

@MainActor
struct LibraryDiffTests {
    private func snapshot(_ id: String, width: Int = 100, favorite: Bool = false, edited: Bool = false) -> AssetSnapshot {
        AssetSnapshot(id: id, creationDate: .distantPast, pixelWidth: width, pixelHeight: 100, isFavorite: favorite, hasAdjustments: edited)
    }

    private func record(_ id: String, width: Int = 100, favorite: Bool = false, edited: Bool = false) -> PhotoRecord {
        PhotoRecord(
            id: id, creationDate: .distantPast, location: nil, burstIdentifier: nil, vector: FeatureVector([1]),
            dHash: 0, aesthetics: nil, isUtility: false, faceQuality: nil, sharpness: 1,
            pixelWidth: width, pixelHeight: 100, isScreenshot: false, isFavorite: favorite, hasAdjustments: edited
        )
    }

    @Test func onlyNewPhotosAreAnalyzed() {
        let diff = LibraryDiff.compute(
            snapshots: [snapshot("cached"), snapshot("new")],
            cached: ["cached": record("cached")]
        )
        #expect(diff.toAnalyze.map(\.id) == ["new"])
        #expect(diff.toRemove.isEmpty)
        #expect(diff.toUpdate.isEmpty)
    }

    @Test func deletedPhotosAreRemovedFromTheCache() {
        let diff = LibraryDiff.compute(snapshots: [snapshot("a")], cached: ["a": record("a"), "gone": record("gone")])
        #expect(diff.toRemove == ["gone"])
    }

    @Test func editedPhotosAreReanalyzed() {
        let diff = LibraryDiff.compute(snapshots: [snapshot("a", edited: true)], cached: ["a": record("a")])
        #expect(diff.toAnalyze.map(\.id) == ["a"])
        #expect(diff.toRemove == ["a"])
    }

    @Test func favoriteChangesOnlyUpdateMetadata() {
        let diff = LibraryDiff.compute(snapshots: [snapshot("a", favorite: true)], cached: ["a": record("a")])
        #expect(diff.toAnalyze.isEmpty)
        #expect(diff.toUpdate.map(\.id) == ["a"])
    }
}
