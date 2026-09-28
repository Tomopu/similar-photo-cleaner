import Foundation
import SwiftData

/// 解析結果の保存形式。写真そのものは保存しない。
@Model
final class AnalyzedPhoto {
    @Attribute(.unique) var localIdentifier: String
    var creationDate: Date
    var modificationDate: Date?
    var latitude: Double?
    var longitude: Double?
    var burstIdentifier: String?
    var vector: Data
    /// dHash（UInt64 のビット列を Int64 として保存）。
    var dHashBits: Int64
    var aesthetics: Double?
    var isUtility: Bool
    var faceQuality: Double?
    var sharpness: Double
    var pixelWidth: Int
    var pixelHeight: Int
    var isScreenshot: Bool
    var isFavorite: Bool
    var hasAdjustments: Bool
    var analyzedAt: Date

    init(snapshot: AssetSnapshot, analysis: ImageAnalysis, analyzedAt: Date = .now) {
        localIdentifier = snapshot.id
        creationDate = snapshot.creationDate
        modificationDate = snapshot.modificationDate
        latitude = snapshot.location?.latitude
        longitude = snapshot.location?.longitude
        burstIdentifier = snapshot.burstIdentifier
        vector = analysis.vector.data
        dHashBits = Int64(bitPattern: analysis.dHash)
        aesthetics = analysis.aesthetics.map(Double.init)
        isUtility = analysis.isUtility
        faceQuality = analysis.faceQuality.map(Double.init)
        sharpness = analysis.sharpness
        pixelWidth = snapshot.pixelWidth
        pixelHeight = snapshot.pixelHeight
        isScreenshot = snapshot.isScreenshot
        isFavorite = snapshot.isFavorite
        hasAdjustments = snapshot.hasAdjustments
        self.analyzedAt = analyzedAt
    }

    /// 写真ライブラリ側でお気に入りなどが変わったときに、解析し直さずメタデータだけ更新する。
    func updateMetadata(from snapshot: AssetSnapshot) {
        isFavorite = snapshot.isFavorite
        hasAdjustments = snapshot.hasAdjustments
    }

    var record: PhotoRecord {
        PhotoRecord(
            id: localIdentifier,
            creationDate: creationDate,
            location: latitude.flatMap { lat in longitude.map { Coordinate(latitude: lat, longitude: $0) } },
            burstIdentifier: burstIdentifier,
            vector: FeatureVector(data: vector),
            dHash: UInt64(bitPattern: dHashBits),
            aesthetics: aesthetics.map(Float.init),
            isUtility: isUtility,
            faceQuality: faceQuality.map(Float.init),
            sharpness: sharpness,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            isScreenshot: isScreenshot,
            isFavorite: isFavorite,
            hasAdjustments: hasAdjustments
        )
    }
}
