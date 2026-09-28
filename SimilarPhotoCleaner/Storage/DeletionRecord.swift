import Foundation
import SwiftData

/// 1回の削除の記録。実績画面の集計に使う。写真そのものは保存しない。
@Model
final class DeletionRecord {
    var date: Date
    var count: Int
    var bytes: Int64
    var similarBytes: Int64
    var swipeBytes: Int64
    var screenshotBytes: Int64

    init(date: Date = .now, count: Int, bytesBySource: [DeletionSource: Int64]) {
        let similar = bytesBySource[.similar, default: 0]
        let swipe = bytesBySource[.swipe, default: 0]
        let screenshot = bytesBySource[.screenshot, default: 0]
        self.date = date
        self.count = count
        similarBytes = similar
        swipeBytes = swipe
        screenshotBytes = screenshot
        bytes = similar + swipe + screenshot
    }

    var entry: DeletionEntry {
        DeletionEntry(
            date: date,
            count: count,
            bytes: bytes,
            bytesBySource: [.similar: similarBytes, .swipe: swipeBytes, .screenshot: screenshotBytes]
        )
    }
}
