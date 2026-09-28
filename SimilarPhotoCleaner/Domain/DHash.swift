/// 知覚ハッシュ（dHash）。ほぼ同一の画像を高速に見つけるために使う。
nonisolated enum DHash {
    static let width = 9
    static let height = 8

    /// 9×8 のグレースケール画素（行優先）から 64bit のハッシュを作る。
    /// 各行で左の画素が右より明るければ 1。
    static func hash(grayscale pixels: [UInt8]) -> UInt64 {
        precondition(pixels.count == width * height, "9×8 の画素が必要")
        var result: UInt64 = 0
        for row in 0..<height {
            for column in 0..<(width - 1) {
                let left = pixels[row * width + column]
                let right = pixels[row * width + column + 1]
                result <<= 1
                if left > right { result |= 1 }
            }
        }
        return result
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
