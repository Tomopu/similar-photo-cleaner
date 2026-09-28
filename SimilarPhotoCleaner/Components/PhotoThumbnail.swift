import Photos
import SwiftUI

/// 写真のサムネイル。読み込み中は面の色だけを出す。
struct PhotoThumbnail: View {
    let id: String
    var maxPixel: CGFloat = 400

    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Palette.surface2)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: id) {
                image = await ThumbnailCache.shared.image(for: id, maxPixel: maxPixel)
            }
    }
}

/// 表示用サムネイルのメモリキャッシュ。表示のときだけ iCloud からの取得も許す。
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 300
    }

    func image(for id: String, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(id)#\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let asset = PhotoLibrary.assets(withIDs: [id]).first,
              let image = await PhotoLibrary.image(for: asset, maxPixel: maxPixel, allowNetwork: true)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

extension Int64 {
    /// 「1.4 GB」「42 MB」のような容量表記。
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
