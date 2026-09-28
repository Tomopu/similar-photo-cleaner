import SwiftData
import SwiftUI

@main
struct SimilarPhotoCleanerApp: App {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @Environment(\.scenePhase) private var scenePhase
    @State private var scan: ScanCoordinator
    @State private var tray = DeletionTray()
    @State private var navigation = AppNavigation()

    private let container: ModelContainer
    private let background: BackgroundScan

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: AnalyzedPhoto.self, DeletionRecord.self)
        } catch {
            fatalError("解析データの保存先を用意できませんでした: \(error)")
        }
        let scan = ScanCoordinator()
        let background = BackgroundScan(scan: scan, container: container)
        background.registerRefreshHandler()
        self.container = container
        self.background = background
        _scan = State(initialValue: scan)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scan)
                .environment(tray)
                .environment(navigation)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                background.scheduleRefreshIfEnabled()
            }
        }
    }
}
