import Foundation
import Testing
@testable import SimilarPhotoCleaner

@MainActor
struct DeletionTrayTests {
    private func makeDefaults() -> UserDefaults {
        let name = "DeletionTrayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func record(_ id: String, pixels: Int = 1000) -> PhotoRecord {
        PhotoRecord(
            id: id, creationDate: .now, location: nil, burstIdentifier: nil, vector: FeatureVector([1]),
            dHash: 0, aesthetics: nil, isUtility: false, faceQuality: nil, sharpness: 1,
            pixelWidth: pixels, pixelHeight: 1, isScreenshot: false, isFavorite: false, hasAdjustments: false
        )
    }

    @Test func addingTheSamePhotoTwiceKeepsTheFirstSource() {
        let tray = DeletionTray(defaults: makeDefaults())
        tray.add([record("a")], from: .similar)
        tray.add([record("a"), record("b")], from: .swipe)
        #expect(tray.items.map(\.id) == ["a", "b"])
        #expect(tray.items.first?.source == .similar)
    }

    @Test func totalsBySource() {
        let tray = DeletionTray(defaults: makeDefaults())
        tray.add([record("a", pixels: 4000)], from: .similar)
        tray.add([record("b", pixels: 8000)], from: .swipe)
        #expect(tray.bytesBySource[.similar] == 1000)
        #expect(tray.bytesBySource[.swipe] == 2000)
        #expect(tray.totalBytes == 3000)
    }

    @Test func removeAndClear() {
        let tray = DeletionTray(defaults: makeDefaults())
        tray.add([record("a"), record("b"), record("c")], from: .screenshot)
        tray.remove(["b"])
        #expect(tray.items.map(\.id) == ["a", "c"])
        #expect(!tray.contains("b"))
        tray.clear()
        #expect(tray.count == 0)
    }

    @Test func survivesRelaunch() {
        let defaults = makeDefaults()
        DeletionTray(defaults: defaults).add([record("a")], from: .swipe)
        let reloaded = DeletionTray(defaults: defaults)
        #expect(reloaded.items.map(\.id) == ["a"])
        #expect(reloaded.contains("a"))
    }
}
