import Foundation
import Observation

/// 削除予定トレイ。どの整理モードで選んだ写真もここに集め、最後にまとめて削除する。
/// 中身は写真の ID と見積もり容量だけで、アプリを閉じても残るよう UserDefaults に保存する。
@Observable
final class DeletionTray {
    struct Item: Codable, Hashable, Identifiable {
        let id: String
        let source: DeletionSource
        let bytes: Int64
    }

    private(set) var items: [Item] = []
    private var ids: Set<String> = []
    private let defaults: UserDefaults
    private let storageKey = "deletionTray"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = saved
            ids = Set(saved.map(\.id))
        }
    }

    var count: Int { items.count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func items(from source: DeletionSource) -> [Item] {
        items.filter { $0.source == source }
    }

    var bytesBySource: [DeletionSource: Int64] {
        items.reduce(into: [:]) { $0[$1.source, default: 0] += $1.bytes }
    }

    /// 既に入っている写真は無視する（最初に入れた経路のまま）。
    func add(_ records: [PhotoRecord], from source: DeletionSource) {
        for record in records where !ids.contains(record.id) {
            items.append(Item(id: record.id, source: source, bytes: record.estimatedBytes))
            ids.insert(record.id)
        }
        save()
    }

    func remove(_ removed: Set<String>) {
        items.removeAll { removed.contains($0.id) }
        ids.subtract(removed)
        save()
    }

    func clear() {
        items = []
        ids = []
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: storageKey)
    }
}
