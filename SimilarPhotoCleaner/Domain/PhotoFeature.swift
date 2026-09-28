import Foundation

/// グループ分けに使う、写真1枚ぶんの特徴。
nonisolated struct PhotoFeature: Sendable, Hashable, Identifiable {
    let id: String
    let creationDate: Date
    let location: Coordinate?
    let burstIdentifier: String?
    let vector: FeatureVector
    let dHash: UInt64
}

nonisolated struct Coordinate: Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    /// 2点間の距離（メートル、球面の近似）。
    func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}
