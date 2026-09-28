import SwiftData
import SwiftUI

/// 4つのタブ。iOS 26 の TabView は Liquid Glass のタブバーで描画される。
struct RootView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(DeletionTray.self) private var tray

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("整理", systemImage: "photo.stack", value: .organize) {
                OrganizeView()
            }
            Tab("削除予定", systemImage: "trash", value: .tray) {
                TrayView()
            }
            .badge(tray.count)
            Tab("実績", systemImage: "chart.bar", value: .history) {
                HistoryView()
            }
            Tab("設定", systemImage: "slider.horizontal.3", value: .settings) {
                SettingsView()
            }
        }
        .tint(Palette.keepText)
    }
}

#Preview {
    RootView()
        .environment(ScanCoordinator(cache: try! AnalysisCache(baseURL: .temporaryDirectory)))
        .environment(DeletionTray())
        .environment(AppNavigation())
        .modelContainer(for: [DeletionRecord.self], inMemory: true)
}
