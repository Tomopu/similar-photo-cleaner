import Testing
@testable import SimilarPhotoCleaner

struct DHashTests {
    @Test func brighterLeftPixelsSetBits() {
        // どの行も左から右へ暗くなる → 全ビット 1
        let row: [UInt8] = [240, 210, 180, 150, 120, 90, 60, 30, 0]
        let pixels = Array(repeating: row, count: 8).flatMap { $0 }
        #expect(DHash.hash(grayscale: pixels) == UInt64.max)
    }

    @Test func flatImageHashesToZero() {
        let pixels = [UInt8](repeating: 128, count: 72)
        #expect(DHash.hash(grayscale: pixels) == 0)
    }

    @Test func hammingDistanceCountsDifferentBits() {
        #expect(DHash.hammingDistance(0b1011, 0b0001) == 2)
        #expect(DHash.hammingDistance(0, UInt64.max) == 64)
    }
}

struct SharpnessTests {
    @Test func flatImageHasNoSharpness() {
        let pixels = [UInt8](repeating: 100, count: 16 * 16)
        #expect(Sharpness.laplacianVariance(grayscale: pixels, width: 16, height: 16) == 0)
    }

    @Test func checkerboardIsSharperThanGradient() {
        let size = 16
        let checker = (0..<(size * size)).map { i in UInt8(((i / size) + (i % size)).isMultiple(of: 2) ? 255 : 0) }
        let gradient = (0..<(size * size)).map { i in UInt8((i % size) * 16) }
        let sharp = Sharpness.laplacianVariance(grayscale: checker, width: size, height: size)
        let soft = Sharpness.laplacianVariance(grayscale: gradient, width: size, height: size)
        #expect(sharp > soft)
    }
}
