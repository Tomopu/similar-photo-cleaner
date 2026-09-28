import SwiftUI

/// 整理タブの行き先。
enum OrganizeRoute: Hashable {
    case similarGroups(MediaKind)
    case swipe(MediaKind)
    case screenshotsBulk
}

/// ホーム: 削減できる容量と、「写真」「スクリーンショット」それぞれの整理のしかた。
struct HomeView: View {
    @Environment(ScanCoordinator.self) private var scan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if scan.phase == .scanning {
                    scanStatus
                        .padding(.bottom, 12)
                }
                summaryCard

                category(
                    title: "写真",
                    icon: "photo.on.rectangle",
                    count: scan.records.values.count { !$0.isScreenshot },
                    rows: [
                        ModeRow(
                            route: .similarGroups(.photos),
                            title: "似た写真を比べる",
                            detail: groupsDetail(.photos),
                            thumbnail: scan.index.groups.first?.bestID,
                            icon: "square.stack"
                        ),
                        ModeRow(route: .swipe(.photos), title: "スワイプで仕分ける", detail: "月ごとに1枚ずつ、残すか決める", icon: "rectangle.portrait.on.rectangle.portrait"),
                    ]
                )
                .padding(.top, 28)

                category(
                    title: "スクリーンショット",
                    icon: "iphone",
                    count: scan.index.screenshots.count,
                    rows: [
                        ModeRow(
                            route: .similarGroups(.screenshots),
                            title: "似たスクショを比べる",
                            detail: groupsDetail(.screenshots),
                            thumbnail: scan.index.screenshotGroups.first?.bestID,
                            icon: "square.stack"
                        ),
                        ModeRow(route: .swipe(.screenshots), title: "スワイプで仕分ける", detail: "月ごとに1枚ずつ、残すか決める", icon: "rectangle.portrait.on.rectangle.portrait"),
                        ModeRow(
                            route: .screenshotsBulk,
                            title: "まとめて選ぶ",
                            detail: "\(scan.index.screenshots.count.formatted())枚 · \(scan.index.screenshotBytes.formattedBytes)",
                            icon: "checkmark.circle"
                        ),
                    ]
                )
                .padding(.top, 24)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .contentMargins(.top, Metrics.titleGap, for: .scrollContent)
        .background(Palette.background)
        .navigationTitle("整理")
        .refreshable {
            scan.startScan()
        }
    }

    private func groupsDetail(_ kind: MediaKind) -> String {
        let groups = scan.index.groups(of: kind)
        return "\(groups.count)グループ · \(groups.reduce(0) { $0 + $1.reclaimableBytes }.formattedBytes)"
    }

    /// 2回目以降のスキャン中に、ホームの一番上に出す進み具合。
    private var scanStatus: some View {
        HStack(spacing: 10) {
            ProgressView(value: scan.progress)
                .tint(Palette.keep)
            Text("解析中 \(scan.processed.formatted()) / \(scan.total.formatted())")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.text2)
        }
        .accessibilityElement(children: .combine)
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

    // MARK: - カテゴリー

    private struct ModeRow: Identifiable {
        let route: OrganizeRoute
        let title: String
        let detail: String
        var thumbnail: String?
        let icon: String

        var id: String { title }
    }

    /// 見出し（アイコン・名前・枚数）と、整理のしかたを1枚のカードにまとめる。
    private func category(title: String, icon: String, count: Int, rows: [ModeRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Palette.keepText)
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Text("\(count.formatted())枚")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                    modeRow(row)
                    if offset < rows.count - 1 {
                        Divider()
                            .overlay(Palette.line)
                            .padding(.leading, 16 + 52 + 14)
                    }
                }
            }
            .background(Palette.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        }
    }

    /// カード（角丸22）の内側14pt → サムネイルの角丸は8。
    private func modeRow(_ row: ModeRow) -> some View {
        NavigationLink(value: row.route) {
            HStack(spacing: 14) {
                Group {
                    if let thumbnail = row.thumbnail {
                        PhotoThumbnail(id: thumbnail, maxPixel: 120)
                    } else {
                        Image(systemName: row.icon)
                            .font(.title3)
                            .foregroundStyle(Palette.keepText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Palette.surface2)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: Metrics.innerRadius(outer: Metrics.cardRadius, inset: 14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.headline).foregroundStyle(Palette.text)
                    Text(row.detail).font(.footnote).foregroundStyle(Palette.text2).monospacedDigit()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.text2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
