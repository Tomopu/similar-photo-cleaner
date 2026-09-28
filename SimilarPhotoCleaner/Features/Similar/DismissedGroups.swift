import Foundation

/// 「このグループは似ていない」と言われたグループ（先頭の写真 ID）。@AppStorage に Data で保存する。
enum DismissedGroups {
    static let storageKey = "dismissedGroups"

    static func decode(_ data: Data) -> Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    static func adding(_ id: String, to data: Data) -> Data {
        var ids = decode(data)
        ids.insert(id)
        return (try? JSONEncoder().encode(ids)) ?? data
    }
}
