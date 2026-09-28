import CoreGraphics
import CoreML
import ImageIO
import Vision

/// サムネイル1枚から、類似判定とベストショット選定に使う指標をまとめて計算する。
nonisolated struct ImageAnalysis: Sendable {
    let vector: FeatureVector
    let dHash: UInt64
    let aesthetics: Float?
    let isUtility: Bool
    let faceQuality: Float?
    let sharpness: Double
}

nonisolated struct ImageAnalyzer: Sendable {
    /// シャープネスを測るときの長辺のピクセル数。
    var sharpnessSide = 256

    func analyze(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> ImageAnalysis {
        let featurePrint = try await Self.prepared(GenerateImageFeaturePrintRequest()).perform(on: image, orientation: orientation)
        let aesthetics = try? await Self.prepared(CalculateImageAestheticsScoresRequest()).perform(on: image, orientation: orientation)
        let faces = (try? await Self.prepared(DetectFaceCaptureQualityRequest()).perform(on: image, orientation: orientation)) ?? []

        let hashPixels = GrayscaleRenderer.render(image, width: DHash.width, height: DHash.height)
        let (width, height) = fittedSize(for: image, longSide: sharpnessSide)
        let sharpnessPixels = GrayscaleRenderer.render(image, width: width, height: height)

        return ImageAnalysis(
            vector: FeatureVector(data: featurePrint.data),
            dHash: DHash.hash(grayscale: hashPixels),
            aesthetics: aesthetics?.overallScore,
            isUtility: aesthetics?.isUtility ?? false,
            faceQuality: faces.compactMap { $0.captureQuality?.score }.max(),
            sharpness: Sharpness.laplacianVariance(grayscale: sharpnessPixels, width: width, height: height)
        )
    }

    /// シミュレータでは Neural Engine / GPU が使えず Vision が失敗するため、CPU で動かす。
    private static func prepared<Request: ImageProcessingRequest>(_ request: Request) -> Request {
        #if targetEnvironment(simulator)
        var request = request
        for (stage, devices) in request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        return request
        #else
        return request
        #endif
    }

    private func fittedSize(for image: CGImage, longSide: Int) -> (Int, Int) {
        let scale = Double(longSide) / Double(max(image.width, image.height))
        return (max(Int(Double(image.width) * scale), 3), max(Int(Double(image.height) * scale), 3))
    }
}

/// CGImage を指定サイズの 8bit グレースケール画素に描き直す。
nonisolated enum GrayscaleRenderer {
    static func render(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}
