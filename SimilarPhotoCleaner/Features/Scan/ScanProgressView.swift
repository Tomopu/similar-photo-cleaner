import SwiftUI

/// 解析の進み具合。
struct ScanProgressView: View {
    @Environment(ScanCoordinator.self) private var scan

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("写真を解析中")
                .font(.largeTitle.bold())
            Text("似た写真とスクリーンショットを探しています")
                .font(.subheadline)
                .foregroundStyle(Palette.text2)
                .padding(.top, 6)

            ring
                .frame(width: 240, height: 240)
                .frame(maxWidth: .infinity)
                .padding(.top, 44)

            HStack(spacing: 12) {
                stat("似た写真のグループ", value: "\(scan.index.groups.count)")
                stat("スクリーンショット", value: "\(scan.screenshotCount.formatted())", unit: "枚")
            }
            .padding(.top, 36)

            Label("アプリを閉じても解析は続きます。進み具合はロック画面などに表示されます。", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(Palette.text2)
                .padding(.top, 20)

            Spacer()

            Button {
                if scan.phase == .scanning {
                    scan.pause()
                } else {
                    scan.startScan()
                }
            } label: {
                Label(scan.phase == .scanning ? "一時停止" : "再開", systemImage: scan.phase == .scanning ? "pause" : "play")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Palette.text)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Palette.surface2, lineWidth: 14)
            Circle()
                .trim(from: 0, to: scan.progress)
                .stroke(Palette.keep, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: scan.progress)
            VStack(spacing: 4) {
                Text(scan.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 52, weight: .bold))
                    .monospacedDigit()
                Text("\(scan.processed.formatted()) / \(scan.total.formatted())枚")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Palette.text2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("解析の進み具合")
    }

    private func stat(_ title: String, value: String, unit: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(Palette.text2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 28, weight: .bold)).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.subheadline.weight(.semibold)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
