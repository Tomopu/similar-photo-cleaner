import Foundation

/// 似た写真のまとめる範囲（設定の「まとめる範囲」）。
nonisolated enum Sensitivity: Int, CaseIterable, Sendable {
    case strict = 0
    case standard = 1
    case loose = 2

    /// 特徴ベクトルの距離の閾値。値は実データで調整する前提の初期値。
    var distanceThreshold: Float {
        switch self {
        case .strict: 0.35
        case .standard: 0.5
        case .loose: 0.65
        }
    }

    var label: String {
        switch self {
        case .strict: "厳しめ"
        case .standard: "標準"
        case .loose: "ゆるめ"
        }
    }
}

/// 撮影時刻（と位置）で写真を「シーン」に区切る。比較はシーンの中だけで行う。
nonisolated struct SceneSplitter {
    var maxInterval: TimeInterval = 60
    var maxDistanceMeters: Double = 200

    /// 撮影日時の昇順に並べた写真を受け取り、シーンごとに分ける。
    func split(_ photos: [PhotoFeature]) -> [[PhotoFeature]] {
        var scenes: [[PhotoFeature]] = []
        var current: [PhotoFeature] = []
        for photo in photos {
            if let previous = current.last, startsNewScene(previous: previous, next: photo) {
                scenes.append(current)
                current = []
            }
            current.append(photo)
        }
        if !current.isEmpty { scenes.append(current) }
        return scenes
    }

    private func startsNewScene(previous: PhotoFeature, next: PhotoFeature) -> Bool {
        if let burst = previous.burstIdentifier, burst == next.burstIdentifier { return false }
        if next.creationDate.timeIntervalSince(previous.creationDate) > maxInterval { return true }
        if let a = previous.location, let b = next.location, a.distance(to: b) > maxDistanceMeters { return true }
        return false
    }
}

/// シーン内の写真を、似ているもの同士でグループにする。
nonisolated struct SimilarityGrouper {
    var distanceThreshold: Float
    /// dHash のハミング距離がこれ以下なら「ほぼ同一」とみなす。
    var nearDuplicateHamming = 5

    init(sensitivity: Sensitivity = .standard) {
        distanceThreshold = sensitivity.distanceThreshold
    }

    /// 2枚以上のグループだけを、写真 ID の配列で返す。
    func groups(in scene: [PhotoFeature]) -> [[String]] {
        guard scene.count >= 2 else { return [] }
        var unionFind = UnionFind(count: scene.count)
        for i in scene.indices {
            for j in (i + 1)..<scene.count where areSimilar(scene[i], scene[j]) {
                unionFind.union(i, j)
            }
        }
        return unionFind.components().map { indices in indices.map { scene[$0].id } }
    }

    func areSimilar(_ a: PhotoFeature, _ b: PhotoFeature) -> Bool {
        if let burst = a.burstIdentifier, burst == b.burstIdentifier { return true }
        if DHash.hammingDistance(a.dHash, b.dHash) <= nearDuplicateHamming { return true }
        return a.vector.distance(to: b.vector) <= distanceThreshold
    }
}
