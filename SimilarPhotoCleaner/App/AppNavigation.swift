import Observation

/// タブの切り替えを画面の奥からも行えるようにする（スワイプ完了 →「削除予定を見る」など）。
@Observable
final class AppNavigation {
    enum Tab: Hashable {
        case organize
        case tray
        case history
        case settings
    }

    var selectedTab: Tab = .organize
}
