import SwiftData
import SwiftUI

@main
struct SimilarPhotoCleanerApp: App {
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @Environment(\.scenePhase) private var scenePhase
    @State private var scan: ScanCoordinator
    @State private var tray = DeletionTray()
    @State private var navigation = AppNavigation()

    /// 削除の実績。解析キャッシュとは別に保存し、キャッシュを消しても残す。
    private let history: ModelContainer
    private let background: BackgroundScan

    init() {
        Self.removeLegacyStore()
        let cache: AnalysisCache
        let history: ModelContainer
        do {
            cache = try AnalysisCache()
            let url = URL.applicationSupportDirectory.appending(path: "history.store")
            history = try ModelContainer(
                for: DeletionRecord.self,
                configurations: ModelConfiguration("History", schema: Schema([DeletionRecord.self]), url: url)
            )
        } catch {
            fatalError("データの保存先を用意できませんでした: \(error)")
        }
        let scan = ScanCoordinator(cache: cache)
        let background = BackgroundScan(scan: scan)
        background.registerRefreshHandler()
        self.history = history
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
        .modelContainer(history)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                background.scheduleRefreshIfEnabled()
            }
        }
    }

    /// 開発中の版で使っていた、解析結果と実績が同居した保存先を消す。
    private static func removeLegacyStore() {
        let base = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: base.appending(path: name))
        }
    }
}
