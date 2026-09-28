import SwiftUI

/// 整理タブのルート。許可 → スキャン → ホームの順に切り替える。
struct OrganizeView: View {
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: OrganizeRoute.self) { route in
                    switch route {
                    case .similarGroups: SimilarGroupsView()
                    case .swipe: SwipeMonthsView()
                    case .screenshots: ScreenshotsView()
                    }
                }
                .navigationDestination(for: SimilarGroup.self) { group in
                    CompareView(group: group)
                }
                .navigationDestination(for: SwipeMonth.self) { month in
                    SwipeDeckView(month: month)
                }
        }
        .task {
            scan.refreshAuthorization()
            guard scan.isAuthorized else { return }
            await scan.reloadIndex(context: context)
            scan.startScan(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            // 設定アプリで許可して戻ってきたときにスキャンを始める
            guard phase == .active, !scan.isAuthorized else { return }
            scan.refreshAuthorization()
            if scan.isAuthorized { scan.startScan(context: context) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !scan.isAuthorized {
            OnboardingView()
        } else if scan.phase == .scanning && !scan.hasAnalyzedPhotos {
            ScanProgressView()
        } else {
            HomeView()
        }
    }
}
