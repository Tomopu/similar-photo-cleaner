import Foundation
import Testing
@testable import SimilarPhotoCleaner

struct DeletionSummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private let gb: Int64 = 1_000_000_000

    @Test func bucketsByMonthIncludingEmptyMonths() {
        let entries = [
            DeletionEntry(date: date(2026, 9, 28), count: 348, bytes: 14 * gb / 10, bytesBySource: [.similar: gb]),
            DeletionEntry(date: date(2026, 9, 3), count: 210, bytes: 12 * gb / 10, bytesBySource: [.screenshot: gb]),
            DeletionEntry(date: date(2026, 7, 10), count: 50, bytes: gb, bytesBySource: [.swipe: gb]),
        ]
        let summary = DeletionSummary.make(from: entries, months: 3, now: date(2026, 9, 28), calendar: calendar)

        #expect(summary.monthly.map(\.bytes) == [gb, 0, 26 * gb / 10])
        #expect(summary.monthly.first?.month == calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        #expect(summary.totalCount == 608)
        #expect(summary.totalBytes == 36 * gb / 10)
        #expect(summary.firstDate == date(2026, 7, 10))
    }

    @Test func entriesOlderThanTheWindowStillCountTowardTotals() {
        let entries = [DeletionEntry(date: date(2025, 1, 1), count: 10, bytes: gb, bytesBySource: [:])]
        let summary = DeletionSummary.make(from: entries, months: 6, now: date(2026, 9, 28), calendar: calendar)
        #expect(summary.monthly.allSatisfy { $0.bytes == 0 })
        #expect(summary.totalBytes == gb)
    }

    @Test func sourcesAreSortedByBytesAndRecentIsNewestFirst() {
        let entries = [
            DeletionEntry(date: date(2026, 8, 1), count: 1, bytes: 3, bytesBySource: [.swipe: 1, .similar: 2]),
            DeletionEntry(date: date(2026, 9, 1), count: 1, bytes: 5, bytesBySource: [.screenshot: 5]),
        ]
        let summary = DeletionSummary.make(from: entries, months: 2, now: date(2026, 9, 28), calendar: calendar)
        #expect(summary.bySource.map(\.source) == [.screenshot, .similar, .swipe])
        #expect(summary.recent.map(\.date) == [date(2026, 9, 1), date(2026, 8, 1)])
    }
}
