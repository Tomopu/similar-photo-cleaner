import Foundation
import Testing
@testable import SimilarPhotoCleaner

private let base = Date(timeIntervalSince1970: 1_790_000_000)

private func photo(
    _ id: String,
    at seconds: TimeInterval,
    vector: [Float] = [1, 0, 0],
    burst: String? = nil,
    location: Coordinate? = nil,
    dHash: UInt64 = 0
) -> PhotoFeature {
    PhotoFeature(
        id: id,
        creationDate: base.addingTimeInterval(seconds),
        location: location,
        burstIdentifier: burst,
        vector: FeatureVector(vector),
        dHash: dHash
    )
}

struct FeatureVectorTests {
    @Test func distanceIsEuclidean() {
        let a = FeatureVector([0, 0, 0])
        let b = FeatureVector([3, 4, 0])
        #expect(a.distance(to: b) == 5)
    }

    @Test func roundTripsThroughData() {
        let vector = FeatureVector([0.25, -1.5, 3])
        #expect(FeatureVector(data: vector.data) == vector)
    }
}

struct UnionFindTests {
    @Test func returnsOnlyGroupsOfTwoOrMore() {
        var unionFind = UnionFind(count: 5)
        unionFind.union(0, 2)
        unionFind.union(2, 4)
        #expect(unionFind.components() == [[0, 2, 4]])
    }

    @Test func separateGroupsAreSortedByFirstIndex() {
        var unionFind = UnionFind(count: 6)
        unionFind.union(4, 5)
        unionFind.union(0, 1)
        #expect(unionFind.components() == [[0, 1], [4, 5]])
    }
}

struct SceneSplitterTests {
    @Test func splitsWhenGapExceedsInterval() {
        let photos = [photo("a", at: 0), photo("b", at: 30), photo("c", at: 200), photo("d", at: 230)]
        let scenes = SceneSplitter(maxInterval: 60).split(photos)
        #expect(scenes.map { $0.map(\.id) } == [["a", "b"], ["c", "d"]])
    }

    @Test func splitsWhenLocationIsFarApart() {
        let tokyo = Coordinate(latitude: 35.6812, longitude: 139.7671)
        let yokohama = Coordinate(latitude: 35.4658, longitude: 139.6223)
        let photos = [photo("a", at: 0, location: tokyo), photo("b", at: 10, location: yokohama)]
        #expect(SceneSplitter().split(photos).count == 2)
    }

    @Test func keepsBurstTogetherEvenAcrossLongGaps() {
        let photos = [photo("a", at: 0, burst: "B"), photo("b", at: 120, burst: "B")]
        #expect(SceneSplitter(maxInterval: 60).split(photos).count == 1)
    }

    @Test func emptyInputHasNoScenes() {
        #expect(SceneSplitter().split([]).isEmpty)
    }
}

struct SimilarityGrouperTests {
    @Test func groupsVectorsWithinThreshold() {
        let scene = [
            photo("a", at: 0, vector: [1, 0, 0], dHash: 0),
            photo("b", at: 1, vector: [1, 0.1, 0], dHash: UInt64.max),
            photo("c", at: 2, vector: [0, 1, 0], dHash: 0x0F0F_0F0F_0F0F_0F0F),
        ]
        let groups = SimilarityGrouper(sensitivity: .standard).groups(in: scene)
        #expect(groups == [["a", "b"]])
    }

    @Test func burstPhotosAreAlwaysGrouped() {
        let scene = [
            photo("a", at: 0, vector: [1, 0, 0], burst: "B", dHash: 0),
            photo("b", at: 1, vector: [0, 1, 0], burst: "B", dHash: UInt64.max),
        ]
        #expect(SimilarityGrouper().groups(in: scene) == [["a", "b"]])
    }

    @Test func nearDuplicateHashesAreGroupedEvenIfVectorsDiffer() {
        let scene = [
            photo("a", at: 0, vector: [1, 0, 0], dHash: 0b1010),
            photo("b", at: 1, vector: [0, 1, 0], dHash: 0b1011),
        ]
        #expect(SimilarityGrouper().groups(in: scene) == [["a", "b"]])
    }

    @Test func similarityIsTransitive() {
        let scene = [
            photo("a", at: 0, vector: [0, 0, 0], dHash: 0),
            photo("b", at: 1, vector: [0.4, 0, 0], dHash: UInt64.max),
            photo("c", at: 2, vector: [0.8, 0, 0], dHash: 0x00FF_00FF_00FF_00FF),
        ]
        #expect(SimilarityGrouper(sensitivity: .standard).groups(in: scene) == [["a", "b", "c"]])
    }

    @Test func thresholdsWidenFromStrictToLoose() {
        #expect(Sensitivity.strict.distanceThreshold < Sensitivity.standard.distanceThreshold)
        #expect(Sensitivity.standard.distanceThreshold < Sensitivity.loose.distanceThreshold)
    }
}
