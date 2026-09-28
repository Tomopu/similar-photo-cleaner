/// ラプラシアン分散によるシャープネス（ブレ・ピンボケの少なさ）。値が大きいほどシャープ。
nonisolated enum Sharpness {
    static func laplacianVariance(grayscale pixels: [UInt8], width: Int, height: Int) -> Double {
        precondition(pixels.count == width * height, "画素数が幅×高さと合わない")
        guard width >= 3, height >= 3 else { return 0 }

        var sum = 0.0
        var sumOfSquares = 0.0
        var count = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Double(pixels[y * width + x])
                let laplacian = Double(pixels[(y - 1) * width + x])
                    + Double(pixels[(y + 1) * width + x])
                    + Double(pixels[y * width + x - 1])
                    + Double(pixels[y * width + x + 1])
                    - 4 * center
                sum += laplacian
                sumOfSquares += laplacian * laplacian
                count += 1
            }
        }
        let mean = sum / count
        return sumOfSquares / count - mean * mean
    }
}
