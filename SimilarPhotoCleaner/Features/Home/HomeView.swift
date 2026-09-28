import SwiftUI

/// 整理タブの行き先。
enum OrganizeRoute: Hashable {
    case similarGroups
    case swipe
    case screenshots
}

/// ホーム: 削減できる容量と、3つの整理モードへの入口。
struct HomeView: View {
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summaryCard

                Text("整理のしかた")
                    .font(.title3.bold())
                    .padding(.top, 28)

                VStack(spacing: 10) {
                    modeRow(
                        route: .similarGroups,
                        title: "似た写真を比べる",
                        detail: "\(scan.index.groups.count)グループ · \(scan.index.reclaimableBytes.formattedBytes)",
                        thumbnails: scan.index.groups.first.map { Array($0.photoIDs.prefix(2)) } ?? [],
                        icon: "square.stack"
                    )
                    modeRow(route: .swipe, title: "スワイプで仕分ける", detail: "月ごとに1枚ずつ、残すか決める", icon: "rectangle.portrait.on.rectangle.portrait")
                    modeRow(
                        route: .screenshots,
                        title: "スクリーンショット",
                        detail: "\(scan.index.screenshots.count.formatted())枚 · \(scan.index.screenshotBytes.formattedBytes)",
                        icon: "iphone"
                    )
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationTitle("整理")
        .refreshable {
            scan.startScan(context: context)
        }
    }

    private var summaryCard: some View {
        let similar = scan.index.reclaimableBytes
        let screenshots = scan.index.screenshotBytes
        let total = similar + screenshots
        return VStack(alignment: .leading, spacing: 14) {
            Text("削減できる容量")
                .font(.footnote)
                .foregroundStyle(Palette.text2)
            Text(total.formattedBytes)
                .font(.system(size: 56, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if total > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        Palette.keep.frame(width: proxy.size.width * CGFloat(similar) / CGFloat(total))
                        Palette.chart2
                    }
                }
                .frame(height: 8)
                .clipShape(.capsule)
                .accessibilityHidden(true)
            }
            HStack(spacing: 16) {
                legend(Palette.keep, "似た写真 \(similar.formattedBytes)")
                legend(Palette.chart2, "スクショ \(screenshots.formattedBytes)")
            }
            if let date = scan.lastScanDate {
                Text("最終スキャン \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 20)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.footnote).foregroundStyle(Palette.text2)
        }
    }

    /// カード（角丸22）の内側14pt → サムネイルの角丸は8。
    private func modeRow(route: OrganizeRoute, title: String, detail: String, thumbnails: [String] = [], icon: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Group {
                    if let first = thumbnails.first {
                        PhotoThumbnail(id: first, maxPixel: 120)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(Palette.keepText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Palette.surface2)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: Metrics.innerRadius(outer: Metrics.cardRadius, inset: 14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Palette.text)
                    Text(detail).font(.footnote).foregroundStyle(Palette.text2).monospacedDigit()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.text2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Palette.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        }
        .buttonStyle(.plain)
    }
}
