/// ベストショット選定に使う、写真1枚ぶんの品質指標。
nonisolated struct QualityMetrics: Sendable, Hashable {
    let id: String
    /// Vision の美的スコア（-1〜1）。取得できなければ nil。
    let aesthetics: Float?
    /// 顔の撮影品質（0〜1）。顔がなければ nil。
    let faceQuality: Float?
    /// ラプラシアン分散。グループ内で相対的に比べる。
    let sharpness: Double
    let pixelCount: Int
    let isFavorite: Bool
    let hasAdjustments: Bool
}

/// 選ばれた1枚が他より優れている点。UI の「残す理由」に使う。
nonisolated enum BestShotReason: String, CaseIterable, Sendable {
    case sharper = "ブレが少ない"
    case betterFace = "表情・目の写りが良い"
    case betterComposition = "構図・露出が良い"
    case higherResolution = "解像度が高い"
    case favorite = "お気に入り"
    case edited = "編集済み"
}

nonisolated struct BestShotResult: Sendable, Hashable {
    let bestID: String
    let reasons: [BestShotReason]
    let scores: [String: Float]
}

/// グループの中から残す1枚を選ぶ。
nonisolated struct BestShotScorer {
    var aestheticsWeight: Float = 0.35
    var faceWeight: Float = 0.3
    var sharpnessWeight: Float = 0.25
    var resolutionWeight: Float = 0.1
    /// 理由として挙げるのに必要な、2番手との差（0〜1 の正規化後）。
    var reasonMargin: Float = 0.1

    func pickBest(from group: [QualityMetrics]) -> BestShotResult? {
        guard !group.isEmpty else { return nil }
        let normalized = normalize(group)
        var scores: [String: Float] = [:]
        for item in normalized {
            scores[item.id] = score(item)
        }

        // お気に入り・編集済みは必ず残す（複数あればスコアの高い方）
        let protected = group.filter { $0.isFavorite || $0.hasAdjustments }
        let candidates = protected.isEmpty ? group : protected
        guard let best = candidates.max(by: { scores[$0.id, default: 0] < scores[$1.id, default: 0] }) else { return nil }

        return BestShotResult(bestID: best.id, reasons: reasons(for: best, in: group, normalized: normalized), scores: scores)
    }

    private struct Normalized {
        let id: String
        let aesthetics: Float?
        let face: Float?
        let sharpness: Float
        let resolution: Float
    }

    private func normalize(_ group: [QualityMetrics]) -> [Normalized] {
        let maxSharpness = group.map(\.sharpness).max() ?? 0
        let maxPixels = group.map(\.pixelCount).max() ?? 0
        return group.map { item in
            Normalized(
                id: item.id,
                aesthetics: item.aesthetics.map { ($0 + 1) / 2 },
                face: item.faceQuality,
                sharpness: maxSharpness > 0 ? Float(item.sharpness / maxSharpness) : 0,
                resolution: maxPixels > 0 ? Float(item.pixelCount) / Float(maxPixels) : 0
            )
        }
    }

    /// 取れた指標だけで重み付き平均を取る（顔がない写真は顔の重みを除く）。
    private func score(_ item: Normalized) -> Float {
        var total: Float = 0
        var weights: Float = 0
        if let aesthetics = item.aesthetics {
            total += aestheticsWeight * aesthetics
            weights += aestheticsWeight
        }
        if let face = item.face {
            total += faceWeight * face
            weights += faceWeight
        }
        total += sharpnessWeight * item.sharpness + resolutionWeight * item.resolution
        weights += sharpnessWeight + resolutionWeight
        return total / weights
    }

    private func reasons(for best: QualityMetrics, in group: [QualityMetrics], normalized: [Normalized]) -> [BestShotReason] {
        var reasons: [BestShotReason] = []
        if best.isFavorite { reasons.append(.favorite) }
        if best.hasAdjustments { reasons.append(.edited) }
        guard group.count >= 2, let mine = normalized.first(where: { $0.id == best.id }) else { return reasons }
        let others = normalized.filter { $0.id != best.id }

        func leads(_ value: Float?, _ otherValues: [Float?]) -> Bool {
            guard let value else { return false }
            let runnerUp = otherValues.compactMap { $0 }.max() ?? 0
            return value - runnerUp >= reasonMargin
        }
        if leads(mine.sharpness, others.map(\.sharpness)) { reasons.append(.sharper) }
        if leads(mine.face, others.map(\.face)) { reasons.append(.betterFace) }
        if leads(mine.aesthetics, others.map(\.aesthetics)) { reasons.append(.betterComposition) }
        if leads(mine.resolution, others.map(\.resolution)) { reasons.append(.higherResolution) }
        return reasons
    }
}
