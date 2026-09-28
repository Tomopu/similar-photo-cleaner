import SwiftUI

/// 設定の「外観」。
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "自動"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// UserDefaults（@AppStorage）のキー。
enum SettingsKey {
    static let appearance = "appearance"
    static let sensitivity = "sensitivity"
    static let excludeFavorites = "excludeFavorites"
    static let excludeEdited = "excludeEdited"
    static let autoScanWhileCharging = "autoScanWhileCharging"
    static let notifyNewCandidates = "notifyNewCandidates"
}
