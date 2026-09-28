import Photos
import SwiftUI

/// 写真へのアクセスを許可してもらう画面。
struct OnboardingView: View {
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.openURL) private var openURL

    private var isDenied: Bool {
        scan.authorization == .denied || scan.authorization == .restricted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text(isDenied ? "写真へのアクセスが\n必要です" : "似た写真を、\nまとめて片づける")
                    .font(.system(size: 30, weight: .bold))
                Text(isDenied
                     ? "設定アプリで、このアプリに写真へのアクセスを許可してください。"
                     : "連写や撮り直しで増えた写真をグループにまとめ、残す1枚を提案します。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 18) {
                feature("lock", "解析はすべてiPhoneの中で", "写真を外部に送信することはありません")
                feature("checkmark.shield", "勝手に消すことはありません", "削除は必ず確認してから。消した写真も30日間は元に戻せます")
                feature("iphone", "スクリーンショットもまとめて", "古いスクショを期間でまとめて選べます")
            }
            .padding(.top, 28)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button {
                    if isDenied {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } else {
                        Task {
                            await scan.requestAccess()
                            await scan.loadFromCache()
                            scan.startScan()
                        }
                    }
                } label: {
                    Text(isDenied ? "設定を開く" : "写真へのアクセスを許可")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.keep)

                Text("「フルアクセス」を選ぶとライブラリ全体を整理できます")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background)
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0xB9CFB0), Color(hex: 0x2F4A33)], startPoint: .top, endPoint: .bottom))
                .frame(width: 150, height: 188)
                .rotationEffect(.degrees(-9))
                .offset(x: -40, y: 14)
                .opacity(0.55)
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0xF2B38A), Color(hex: 0x2A1F2E)], startPoint: .top, endPoint: .bottom))
                .frame(width: 150, height: 188)
                .rotationEffect(.degrees(8))
                .offset(x: 50, y: 10)
                .opacity(0.7)
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x9FC3D9), Color(hex: 0x1F4E5C)], startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 204)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 18)
        }
        .frame(height: 230)
        .accessibilityHidden(true)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Palette.keepText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
