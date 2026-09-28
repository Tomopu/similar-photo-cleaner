/// 類似ペアを連結してグループを作るための Union-Find。
nonisolated struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root { root = parent[root] }
        var node = x
        while parent[node] != root {
            let next = parent[node]
            parent[node] = root
            node = next
        }
        return root
    }

    mutating func union(_ a: Int, _ b: Int) {
        let rootA = find(a)
        let rootB = find(b)
        guard rootA != rootB else { return }
        if rank[rootA] < rank[rootB] {
            parent[rootA] = rootB
        } else if rank[rootA] > rank[rootB] {
            parent[rootB] = rootA
        } else {
            parent[rootB] = rootA
            rank[rootA] += 1
        }
    }

    /// 要素数 2 以上の集合を、元の添字の昇順で返す。
    mutating func components() -> [[Int]] {
        var byRoot: [Int: [Int]] = [:]
        for index in parent.indices {
            byRoot[find(index), default: []].append(index)
        }
        return byRoot.values
            .filter { $0.count >= 2 }
            .sorted { $0[0] < $1[0] }
    }
}
