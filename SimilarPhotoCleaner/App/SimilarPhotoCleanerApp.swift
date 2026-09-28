import SwiftData
import SwiftUI

@main
struct SimilarPhotoCleanerApp: App {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @State private var scan = ScanCoordinator()
    @State private var tray = DeletionTray()
    @State private var navigation = AppNavigation()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scan)
                .environment(tray)
                .environment(navigation)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [AnalyzedPhoto.self, DeletionRecord.self])
    }
}
