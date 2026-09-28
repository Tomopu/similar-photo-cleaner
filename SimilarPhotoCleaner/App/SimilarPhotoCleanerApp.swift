import SwiftUI

@main
struct SimilarPhotoCleanerApp: App {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
