import Foundation

/// 解析済みの写真1枚ぶんのスナップショット。保存形式から切り離した値型。
nonisolated struct PhotoRecord: Sendable, Hashable, Identifiable {
    let id: String
    let creationDate: Date
    let location: Coordinate?
    let burstIdentifier: String?
    let vector: FeatureVector
    let dHash: UInt64
    let aesthetics: Float?
    let isUtility: Bool
    let faceQuality: Float?
    let sharpness: Double
    let pixelWidth: Int
    let pixelHeight: Int
    let isScreenshot: Bool
    let isFavorite: Bool
    let hasAdjustments: Bool

    var estimatedBytes: Int64 {
        FileSizeEstimator.estimate(pixelWidth: pixelWidth, pixelHeight: pixelHeight, isScreenshot: isScreenshot)
    }

    var feature: PhotoFeature {
        PhotoFeature(id: id, creationDate: creationDate, location: location, burstIdentifier: burstIdentifier, vector: vector, dHash: dHash)
    }

    var metrics: QualityMetrics {
        QualityMetrics(
            id: id, aesthetics: aesthetics, faceQuality: faceQuality, sharpness: sharpness,
            pixelCount: pixelWidth * pixelHeight, isFavorite: isFavorite, hasAdjustments: hasAdjustments
        )
    }
}

/// 写真1枚の容量の見積もり。公開 API では正確なバイト数が取れないため、解像度から推定する。
nonisolated enum FileSizeEstimator {
    /// HEIC 写真は 1画素あたり約 0.25 バイト、スクリーンショット（PNG）は約 0.5 バイトとして見積もる。
    static func estimate(pixelWidth: Int, pixelHeight: Int, isScreenshot: Bool) -> Int64 {
        let pixels = Double(pixelWidth * pixelHeight)
        return Int64(pixels * (isScreenshot ? 0.5 : 0.25))
    }
}

/// 似た写真のグループ（1グループ = 1カード）。
nonisolated struct SimilarGroup: Sendable, Hashable, Identifiable {
    let id: String
    /// 撮影日時の順。
    let photoIDs: [String]
    let bestID: String
    let reasons: [BestShotReason]
    /// 削除候補（ベストと保護対象を除く）。
    let candidateIDs: [String]
    let reclaimableBytes: Int64
    let date: Date
}

/// 解析結果から、似た写真のグループとスクリーンショットの一覧を作る。
nonisolated struct LibraryIndex: Sendable {
    let groups: [SimilarGroup]
    /// 撮影日時の新しい順。
    let screenshots: [PhotoRecord]
    /// 書類・レシートなど、思い出性の低い実用写真（スクリーンショットを除く）。新しい順。
    let utilityPhotos: [PhotoRecord]

    static let empty = LibraryIndex(groups: [], screenshots: [], utilityPhotos: [])

    static func build(
        from records: [PhotoRecord],
        sensitivity: Sensitivity,
        excludeFavorites: Bool = true,
        excludeEdited: Bool = true,
        splitter: SceneSplitter = SceneSplitter(),
        scorer: BestShotScorer = BestShotScorer()
    ) -> LibraryIndex {
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let photos = records.filter { !$0.isScreenshot }.sorted { $0.creationDate < $1.creationDate }
        let grouper = SimilarityGrouper(sensitivity: sensitivity)

        var groups: [SimilarGroup] = []
        for scene in splitter.split(photos.map(\.feature)) {
            for ids in grouper.groups(in: scene) {
                let members = ids.compactMap { byID[$0] }
                guard let best = scorer.pickBest(from: members.map(\.metrics)) else { continue }
                let candidates = members.filter { member in
                    member.id != best.bestID
                        && !(excludeFavorites && member.isFavorite)
                        && !(excludeEdited && member.hasAdjustments)
                }
                guard !candidates.isEmpty else { continue }
                groups.append(SimilarGroup(
                    id: ids[0],
                    photoIDs: ids,
                    bestID: best.bestID,
                    reasons: best.reasons,
                    candidateIDs: candidates.map(\.id),
                    reclaimableBytes: candidates.reduce(0) { $0 + $1.estimatedBytes },
                    date: members[0].creationDate
                ))
            }
        }

        return LibraryIndex(
            groups: groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes },
            screenshots: records.filter(\.isScreenshot).sorted { $0.creationDate > $1.creationDate },
            utilityPhotos: records.filter { $0.isUtility && !$0.isScreenshot }.sorted { $0.creationDate > $1.creationDate }
        )
    }

    var reclaimableBytes: Int64 { groups.reduce(0) { $0 + $1.reclaimableBytes } }
    var screenshotBytes: Int64 { screenshots.reduce(0) { $0 + $1.estimatedBytes } }
}
