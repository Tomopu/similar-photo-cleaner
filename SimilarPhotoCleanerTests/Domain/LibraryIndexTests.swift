import Foundation
import Testing
@testable import SimilarPhotoCleaner

private let base = Date(timeIntervalSince1970: 1_790_000_000)

private func record(
    _ id: String,
    at seconds: TimeInterval,
    vector: [Float],
    sharpness: Double = 100,
    screenshot: Bool = false,
    favorite: Bool = false,
    edited: Bool = false,
    size: (Int, Int) = (4000, 3000)
) -> PhotoRecord {
    PhotoRecord(
        id: id, creationDate: base.addingTimeInterval(seconds), location: nil, burstIdentifier: nil,
        vector: FeatureVector(vector), dHash: UInt64(seconds) &* 0x9E37_79B9_7F4A_7C15,
        aesthetics: 0, isUtility: false, faceQuality: nil, sharpness: sharpness,
        pixelWidth: size.0, pixelHeight: size.1, isScreenshot: screenshot, isFavorite: favorite, hasAdjustments: edited
    )
}

struct LibraryIndexTests {
    @Test func groupsSimilarPhotosAndKeepsTheSharpestOne() throws {
        let records = [
            record("a", at: 0, vector: [1, 0], sharpness: 50),
            record("b", at: 5, vector: [1, 0.1], sharpness: 200),
            record("c", at: 10, vector: [1, 0.05], sharpness: 80),
            record("far", at: 10_000, vector: [1, 0]),
        ]
        let index = LibraryIndex.build(from: records, sensitivity: .standard)
        let group = try #require(index.groups.first)
        #expect(index.groups.count == 1)
        #expect(group.photoIDs == ["a", "b", "c"])
        #expect(group.bestID == "b")
        #expect(Set(group.candidateIDs) == ["a", "c"])
        #expect(group.reclaimableBytes == 2 * FileSizeEstimator.estimate(pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false))
    }

    @Test func screenshotsAreListedSeparatelyNewestFirst() {
        let records = [
            record("s1", at: 0, vector: [1, 0], screenshot: true),
            record("s2", at: 1, vector: [1, 0], screenshot: true),
        ]
        let index = LibraryIndex.build(from: records, sensitivity: .standard)
        #expect(index.groups.isEmpty)
        #expect(index.screenshots.map(\.id) == ["s2", "s1"])
    }

    @Test func protectedPhotosAreKeptAndNeverCandidates() throws {
        let records = [
            record("sharp", at: 0, vector: [1, 0], sharpness: 300),
            record("fav", at: 1, vector: [1, 0.01], sharpness: 10, favorite: true),
            record("edited", at: 2, vector: [1, 0.02], sharpness: 10, edited: true),
            record("plain", at: 3, vector: [1, 0.03], sharpness: 10),
        ]
        let group = try #require(LibraryIndex.build(from: records, sensitivity: .standard).groups.first)
        // お気に入り・編集済みがあれば、そちらを残す1枚にする
        #expect(["fav", "edited"].contains(group.bestID))
        #expect(Set(group.candidateIDs) == ["sharp", "plain"])
    }

    @Test func protectionCanBeTurnedOff() throws {
        let records = [
            record("sharp", at: 0, vector: [1, 0], sharpness: 300),
            record("fav", at: 1, vector: [1, 0.01], sharpness: 10, favorite: true),
        ]
        let group = try #require(LibraryIndex.build(from: records, sensitivity: .standard, excludeFavorites: false).groups.first)
        #expect(group.candidateIDs == ["sharp"])
    }

    @Test func groupWithNothingToDeleteIsDropped() {
        let records = [
            record("fav1", at: 0, vector: [1, 0], favorite: true),
            record("fav2", at: 1, vector: [1, 0.01], favorite: true),
        ]
        #expect(LibraryIndex.build(from: records, sensitivity: .standard).groups.isEmpty)
    }

    @Test func groupsAreSortedByReclaimableBytes() {
        let records = [
            record("small1", at: 0, vector: [1, 0], size: (1000, 1000)),
            record("small2", at: 1, vector: [1, 0.01], size: (1000, 1000)),
            record("big1", at: 5000, vector: [1, 0], size: (4000, 3000)),
            record("big2", at: 5001, vector: [1, 0.01], size: (4000, 3000)),
        ]
        let index = LibraryIndex.build(from: records, sensitivity: .standard)
        #expect(index.groups.map { $0.photoIDs.first } == ["big1", "small1"])
    }
}

struct UtilityPhotoTests {
    @Test func utilityPhotosExcludeScreenshots() {
        func utility(_ id: String, at seconds: TimeInterval, screenshot: Bool) -> PhotoRecord {
            PhotoRecord(
                id: id, creationDate: Date(timeIntervalSince1970: seconds), location: nil, burstIdentifier: nil,
                vector: FeatureVector([Float(seconds), 1]), dHash: UInt64(seconds), aesthetics: 0, isUtility: true,
                faceQuality: nil, sharpness: 1, pixelWidth: 10, pixelHeight: 10,
                isScreenshot: screenshot, isFavorite: false, hasAdjustments: false
            )
        }
        let index = LibraryIndex.build(
            from: [utility("receipt", at: 0, screenshot: false), utility("shot", at: 100_000, screenshot: true), utility("doc", at: 200_000, screenshot: false)],
            sensitivity: .standard
        )
        #expect(index.utilityPhotos.map(\.id) == ["doc", "receipt"])
    }
}
