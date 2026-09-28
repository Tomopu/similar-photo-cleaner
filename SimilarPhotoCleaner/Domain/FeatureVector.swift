import Accelerate
import Foundation

/// Vision の Image Feature Print から取り出した特徴ベクトル。
/// 距離は Vision と同じユークリッド距離で計算する。
nonisolated struct FeatureVector: Sendable, Hashable {
    let values: [Float]

    init(_ values: [Float]) {
        self.values = values
    }

    /// Vision の `FeaturePrintObservation.data`（Float の生データ）から作る。
    init(data: Data) {
        values = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    var data: Data {
        values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    func distance(to other: FeatureVector) -> Float {
        precondition(values.count == other.values.count, "特徴ベクトルの次元が違う")
        return vDSP.distanceSquared(values, other.values).squareRoot()
    }
}
