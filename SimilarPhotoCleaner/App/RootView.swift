import SwiftData
import SwiftUI

/// 4つのタブ。iOS 26 の TabView は Liquid Glass のタブバーで描画される。
struct RootView: View {
    enum TabID: Hashable {
        case organize
        case tray
        case history
        case settings
    }

    @State private var selection: TabID = .organize

    var body: some View {
        TabView(selection: $selection) {
            Tab("整理", systemImage: "photo.stack", value: .organize) {
                OrganizeView()
            }
            Tab("削除予定", systemImage: "trash", value: .tray) {
                PlaceholderScreen(title: "削除予定")
            }
            Tab("実績", systemImage: "chart.bar", value: .history) {
                PlaceholderScreen(title: "実績")
            }
            Tab("設定", systemImage: "slider.horizontal.3", value: .settings) {
                SettingsView()
            }
        }
        .tint(Palette.keepText)
    }
}

/// まだ実装していないタブの仮の画面。
private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text("準備中です"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootView()
        .environment(ScanCoordinator())
        .modelContainer(for: [AnalyzedPhoto.self], inMemory: true)
}
