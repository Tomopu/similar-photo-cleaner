import SwiftUI

/// 似た写真のグループ一覧。1グループ = 1カード。
struct SimilarGroupsView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case reclaimable = "減らせる容量順"
        case newest = "新しい順"
        var id: Self { self }
    }

    @Environment(ScanCoordinator.self) private var scan
    @Environment(DeletionTray.self) private var tray
    @AppStorage(DismissedGroups.storageKey) private var dismissedGroupsData = Data()
    @State private var order: SortOrder = .reclaimable

    private var dismissedGroups: Set<String> {
        DismissedGroups.decode(dismissedGroupsData)
    }

    private var groups: [SimilarGroup] {
        let visible = scan.index.groups.filter { !dismissedGroups.contains($0.id) }
        switch order {
        case .reclaimable: return visible
        case .newest: return visible.sorted { $0.date > $1.date }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("\(groups.count)グループ · \(groups.reduce(0) { $0 + $1.reclaimableBytes }.formattedBytes) を減らせます")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .monospacedDigit()

                Picker("並び順", selection: $order) {
                    ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                ForEach(groups) { group in
                    NavigationLink(value: group) {
                        GroupCard(group: group, isQueued: group.candidateIDs.allSatisfy(tray.contains))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("このグループは似ていない", systemImage: "eye.slash") { dismiss(group) }
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("似た写真は見つかりませんでした", systemImage: "checkmark.circle", description: Text("新しく写真を撮ったら、ホームを下に引いてスキャンし直せます。"))
            }
        }
        .background(Palette.background)
        .navigationTitle("似た写真")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dismiss(_ group: SimilarGroup) {
        dismissedGroupsData = DismissedGroups.adding(group.id, to: dismissedGroupsData)
    }
}

private struct GroupCard: View {
    let group: SimilarGroup
    let isQueued: Bool

    /// カード（角丸22）の内側14pt → サムネイル角丸8、サムネイルの内側5pt → ラベル角丸3。
    private let thumbnailRadius = Metrics.innerRadius(outer: Metrics.cardRadius, inset: 14)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(Array(group.photoIDs.prefix(4).enumerated()), id: \.element) { offset, id in
                    PhotoThumbnail(id: id, maxPixel: 200)
                        .frame(height: 76)
                        .clipShape(.rect(cornerRadius: thumbnailRadius))
                        .overlay(alignment: .bottomLeading) {
                            if id == group.bestID {
                                Text("ベスト")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .frame(height: 20)
                                    .background(Palette.keep, in: .rect(cornerRadius: Metrics.innerRadius(outer: thumbnailRadius, inset: 5)))
                                    .padding(5)
                            }
                        }
                        .overlay {
                            if offset == 3, group.photoIDs.count > 4 {
                                Text("+\(group.photoIDs.count - 3)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.45), in: .rect(cornerRadius: 3))
                            }
                        }
                }
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.date.formatted(.dateTime.month().day().hour().minute()))
                        .font(.callout.weight(.semibold))
                    Text(isQueued ? "削除予定に追加済み" : "\(group.photoIDs.count)枚 · \(group.candidateIDs.count)枚を削除候補")
                        .font(.footnote)
                        .foregroundStyle(Palette.text2)
                        .monospacedDigit()
                }
                Spacer()
                Text("−\(group.reclaimableBytes.formattedBytes)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Palette.deleteText)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Palette.text)
        .card(padding: 14)
        .opacity(isQueued ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}
