import Testing
@testable import SimilarPhotoCleaner

private func metrics(
    _ id: String,
    aesthetics: Float? = 0,
    face: Float? = nil,
    sharpness: Double = 100,
    pixels: Int = 12_000_000,
    favorite: Bool = false,
    edited: Bool = false
) -> QualityMetrics {
    QualityMetrics(
        id: id, aesthetics: aesthetics, faceQuality: face, sharpness: sharpness,
        pixelCount: pixels, isFavorite: favorite, hasAdjustments: edited
    )
}

struct BestShotScorerTests {
    @Test func picksTheSharperPhotoAndSaysWhy() throws {
        let result = try #require(BestShotScorer().pickBest(from: [
            metrics("blurry", sharpness: 20),
            metrics("sharp", sharpness: 200),
        ]))
        #expect(result.bestID == "sharp")
        #expect(result.reasons.contains(.sharper))
    }

    @Test func faceQualityOutweighsSmallSharpnessDifference() throws {
        let result = try #require(BestShotScorer().pickBest(from: [
            metrics("eyesClosed", face: 0.2, sharpness: 200),
            metrics("eyesOpen", face: 0.9, sharpness: 180),
        ]))
        #expect(result.bestID == "eyesOpen")
        #expect(result.reasons.contains(.betterFace))
    }

    @Test func favoriteIsAlwaysKept() throws {
        let result = try #require(BestShotScorer().pickBest(from: [
            metrics("better", aesthetics: 0.9, sharpness: 300),
            metrics("favorite", aesthetics: -0.5, sharpness: 10, favorite: true),
        ]))
        #expect(result.bestID == "favorite")
        #expect(result.reasons.first == .favorite)
    }

    @Test func missingAestheticsDoesNotBreakScoring() throws {
        let result = try #require(BestShotScorer().pickBest(from: [
            metrics("a", aesthetics: nil, sharpness: 50),
            metrics("b", aesthetics: nil, sharpness: 150),
        ]))
        #expect(result.bestID == "b")
    }

    @Test func emptyGroupHasNoBest() {
        #expect(BestShotScorer().pickBest(from: []) == nil)
    }
}
