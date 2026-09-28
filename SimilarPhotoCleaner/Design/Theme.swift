import SwiftUI
import UIKit

/// docs/UI_DESIGN.md のデザイントークン。ライト／ダークで値を切り替える。
enum Palette {
    static let background = Color(light: 0xF4F4F1, dark: 0x282C34)
    static let surface = Color(light: 0xFFFFFF, dark: 0x30353F)
    static let surface2 = Color(light: 0xE8E8E4, dark: 0x3A404B)
    static let line = Color(light: 0xDEDED9, dark: 0x3E4451)
    static let text = Color(light: 0x131416, dark: 0xECEEF2)
    static let text2 = Color(light: 0x5C616A, dark: 0xA9B0BC)
    /// 残す・ベスト・主要ボタン（白文字）
    static let keep = Color(light: 0x2463E0, dark: 0x2F6FEB)
    /// 背景の上の青い文字・アイコン
    static let keepText = Color(light: 0x1F5AD0, dark: 0x8DB3FF)
    /// 削除・削除予定の塗り（文字は deleteInk）
    static let delete = Color(light: 0xD93636, dark: 0xE5484D)
    static let deleteInk = Color.white
    /// 背景の上の赤い文字
    static let deleteText = Color(light: 0xC22B2B, dark: 0xFF7B7B)
    /// グラフの棒（ダークはカードの上で 3:1 を確保するため明るめ）
    static let chart = Color(light: 0x2463E0, dark: 0x4F8AF7)
    static let chart2 = Color(light: 0x9DBBF5, dark: 0x9DBBF5)
}

enum Metrics {
    static let screenMargin: CGFloat = 24
    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 16
    static let buttonHeight: CGFloat = 52
    /// 大きなタイトルと、その下の最初の要素との間隔。
    static let titleGap: CGFloat = 16
    /// 入れ子の角丸は「外側の角丸 − 余白」で揃える。
    static func innerRadius(outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(outer - inset, 0)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 角丸 22 のカード。
struct CardBackground: ViewModifier {
    var padding: CGFloat = Metrics.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.surface, in: .rect(cornerRadius: Metrics.cardRadius))
    }
}

extension View {
    func card(padding: CGFloat = Metrics.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

enum NavigationBarStyle {
    /// 大きなタイトルの左端を、画面の余白（24pt）に揃える。
    /// ナビゲーションバーの標準の余白は 16pt なので、その差だけ字下げする。
    static func apply() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = Metrics.screenMargin - 16
        UINavigationBar.appearance().largeTitleTextAttributes = [.paragraphStyle: paragraph]
    }
}
