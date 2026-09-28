import Photos
import UIKit

/// 写真ライブラリ上の1枚の情報（解析前のメタデータ）。
nonisolated struct AssetSnapshot: Sendable, Hashable {
    let id: String
    let creationDate: Date
    let modificationDate: Date?
    let location: Coordinate?
    let burstIdentifier: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let isScreenshot: Bool
    let isFavorite: Bool
    let hasAdjustments: Bool

    init(_ asset: PHAsset) {
        id = asset.localIdentifier
        creationDate = asset.creationDate ?? .distantPast
        modificationDate = asset.modificationDate
        location = asset.location.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        burstIdentifier = asset.burstIdentifier
        pixelWidth = asset.pixelWidth
        pixelHeight = asset.pixelHeight
        isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        isFavorite = asset.isFavorite
        hasAdjustments = asset.hasAdjustments
    }
}

enum DeleteOutcome: Equatable {
    case deleted
    case cancelled
}

/// PhotoKit の窓口。写真の取得・サムネイル・削除をまとめる。
nonisolated enum PhotoLibrary {
    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// ライブラリの写真（動画を除く）を撮影日時の古い順に返す。
    static func fetchImageSnapshots() -> [AssetSnapshot] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var snapshots: [AssetSnapshot] = []
        snapshots.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in snapshots.append(AssetSnapshot(asset)) }
        return snapshots
    }

    static func assets(withIDs ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    /// 端末内にある画像から、長辺 `maxPixel` 程度の画像を取り出す。iCloud からは取得しない。
    static func image(for asset: PHAsset, maxPixel: CGFloat, allowNetwork: Bool = false) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowNetwork
        let size = CGSize(width: maxPixel, height: maxPixel)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// まとめて削除する。iOS の確認ダイアログでキャンセルされた場合は `.cancelled`。
    static func delete(ids: [String]) async throws -> DeleteOutcome {
        let assets = assets(withIDs: ids)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return .deleted
        } catch let error as PHPhotosError where error.code == .userCancelled {
            return .cancelled
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == PHPhotosError.Code.userCancelled.rawValue {
            return .cancelled
        }
    }
}

extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
