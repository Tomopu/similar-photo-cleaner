import Foundation

/// 写真を削除予定に入れた経路。
nonisolated enum DeletionSource: String, CaseIterable, Codable, Sendable {
    case similar
    case swipe
    case screenshot

    var label: String {
        switch self {
        case .similar: "似た写真"
        case .swipe: "スワイプ"
        case .screenshot: "スクリーンショット"
        }
    }
}

/// 1回の削除の記録（写真そのものは持たない）。
nonisolated struct DeletionEntry: Sendable, Hashable {
    let date: Date
    let count: Int
    let bytes: Int64
    let bytesBySource: [DeletionSource: Int64]
}

nonisolated struct MonthlyAmount: Sendable, Hashable {
    /// その月の1日 0:00。
    let month: Date
    let bytes: Int64
}

nonisolated struct SourceAmount: Sendable, Hashable {
    let source: DeletionSource
    let bytes: Int64
}

/// 実績画面で表示する集計。
nonisolated struct DeletionSummary: Sendable, Hashable {
    let totalBytes: Int64
    let totalCount: Int
    let firstDate: Date?
    /// 古い月から順に、削除がない月も 0 として含む。
    let monthly: [MonthlyAmount]
    /// 容量の多い順。
    let bySource: [SourceAmount]
    /// 新しい順。
    let recent: [DeletionEntry]

    static func make(
        from entries: [DeletionEntry],
        months: Int,
        now: Date = .now,
        calendar: Calendar = .current,
        recentLimit: Int = 10
    ) -> DeletionSummary {
        let currentMonth = calendar.dateInterval(of: .month, for: now)!.start
        let monthStarts: [Date] = (0..<months).reversed().map {
            calendar.date(byAdding: .month, value: -$0, to: currentMonth)!
        }
        var bytesByMonth: [Date: Int64] = [:]
        var bytesBySource: [DeletionSource: Int64] = [:]
        for entry in entries {
            let month = calendar.dateInterval(of: .month, for: entry.date)!.start
            bytesByMonth[month, default: 0] += entry.bytes
            for (source, bytes) in entry.bytesBySource {
                bytesBySource[source, default: 0] += bytes
            }
        }
        let sorted = entries.sorted { $0.date > $1.date }
        return DeletionSummary(
            totalBytes: entries.reduce(0) { $0 + $1.bytes },
            totalCount: entries.reduce(0) { $0 + $1.count },
            firstDate: entries.map(\.date).min(),
            monthly: monthStarts.map { MonthlyAmount(month: $0, bytes: bytesByMonth[$0, default: 0]) },
            bySource: DeletionSource.allCases
                .map { SourceAmount(source: $0, bytes: bytesBySource[$0, default: 0]) }
                .sorted { $0.bytes > $1.bytes },
            recent: Array(sorted.prefix(recentLimit))
        )
    }
}
