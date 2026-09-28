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
        // 文字が大きい設定や小さい iPhone でも見出しが切れないよう、本文はスクロールさせてボタンは下に固定する
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text(isDenied ? "写真へのアクセスが\n必要です" : "似た写真を、\nまとめて片づける")
                        .font(.system(size: 30, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isDenied
                         ? "設定アプリで、このアプリに写真へのアクセスを許可してください。"
                         : "連写や撮り直しで増えた写真をグループにまとめ、残す1枚を提案します。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 18) {
                    feature("lock", "解析はすべてiPhoneの中で", "写真を外部に送信することはありません")
                    feature("checkmark.shield", "完全には削除しません", "削除は必ず確認してから。消した写真も30日間は元に戻せます")
                    feature("iphone", "スクリーンショットもまとめて", "古いスクショを期間でまとめて選べます")
                }
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, Metrics.screenMargin)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
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
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Palette.background)
        }
        .background(Palette.background)
    }

    /// 重なった3枚の写真。奥の2枚は少し傾けて暗くする。
    private var hero: some View {
        ZStack {
            photo(.onboardingLake, width: 150, height: 188)
                .brightness(-0.12)
                .rotationEffect(.degrees(-9))
                .offset(x: -40, y: 14)
            photo(.onboardingBeach, width: 150, height: 188)
                .brightness(-0.08)
                .rotationEffect(.degrees(8))
                .offset(x: 50, y: 10)
            photo(.onboardingDog, width: 160, height: 204)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 18)
        }
        .frame(height: 230)
        .accessibilityHidden(true)
    }

    private func photo(_ resource: ImageResource, width: CGFloat, height: CGFloat) -> some View {
        Image(resource)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 18))
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
