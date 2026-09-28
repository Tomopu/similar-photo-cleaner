import SwiftData
import SwiftUI

@main
struct SimilarPhotoCleanerApp: App {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @State private var scan = ScanCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scan)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [AnalyzedPhoto.self])
    }
}
