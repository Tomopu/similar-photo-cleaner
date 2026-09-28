/// 写真ライブラリの今の状態と、キャッシュ済みの解析結果を比べた差分。
struct LibraryDiff {
    /// まだ解析していない写真と、編集で見た目が変わって解析し直す写真。
    let toAnalyze: [AssetSnapshot]
    /// ライブラリから消えた写真と、解析し直す写真（古い結果を消す）。
    let toRemove: Set<String>
    /// お気に入りなど、解析し直さずに情報だけ更新する写真。
    let toUpdate: [AssetSnapshot]

    static func compute(snapshots: [AssetSnapshot], cached: [String: PhotoRecord]) -> LibraryDiff {
        var toAnalyze: [AssetSnapshot] = []
        var toUpdate: [AssetSnapshot] = []
        var reanalyzed: Set<String> = []
        for snapshot in snapshots {
            guard let record = cached[snapshot.id] else {
                toAnalyze.append(snapshot)
                continue
            }
            if record.hasAdjustments != snapshot.hasAdjustments
                || record.pixelWidth != snapshot.pixelWidth
                || record.pixelHeight != snapshot.pixelHeight {
                toAnalyze.append(snapshot)
                reanalyzed.insert(snapshot.id)
            } else if record.isFavorite != snapshot.isFavorite {
                toUpdate.append(snapshot)
            }
        }
        let current = Set(snapshots.map(\.id))
        let gone = Set(cached.keys).subtracting(current)
        return LibraryDiff(toAnalyze: toAnalyze, toRemove: gone.union(reanalyzed), toUpdate: toUpdate)
    }
}
