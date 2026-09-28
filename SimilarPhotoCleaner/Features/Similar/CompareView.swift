import SwiftUI

/// 比較モード: グループ内の写真を2枚ずつ上下に並べ、勝ち抜き形式で残す1枚を選ぶ。
/// 上の写真（勝者）を残しつつ、下の写真を次々と入れ替えて比べる。
struct CompareView: View {
    enum Decision {
        case keep
        case delete
    }

    let group: SimilarGroup

    @Environment(ScanCoordinator.self) private var scan
    @Environment(DeletionTray.self) private var tray
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DismissedGroups.storageKey) private var dismissedGroupsData = Data()

    @State private var champion: String
    /// 比べ終わった写真（勝者以外）。
    @State private var compared: Set<String> = []
    @State private var decisions: [String: Decision]
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero

    init(group: SimilarGroup) {
        self.group = group
        _champion = State(initialValue: group.bestID)
        _decisions = State(initialValue: Dictionary(uniqueKeysWithValues: group.photoIDs.map {
            ($0, group.candidateIDs.contains($0) ? .delete : .keep)
        }))
    }

    private var remaining: [String] {
        group.photoIDs.filter { $0 != champion && !compared.contains($0) }
    }

    private var challenger: String? {
        remaining.first
    }

    private var isLastComparison: Bool {
        remaining.count <= 1
    }

    private var deleteIDs: [String] {
        group.photoIDs.filter { decisions[$0] == .delete }
    }

    var body: some View {
        VStack(spacing: 10) {
            photoPanel(champion)
            if let challenger {
                photoPanel(challenger)
            }

            Text("ピンチで2枚を同時に拡大できます")
                .font(.footnote)
                .foregroundStyle(Palette.text2)

            filmstrip

            Button(action: advance) {
                Text(primaryTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(isLastComparison ? Palette.delete : Palette.keep)
            .foregroundStyle(isLastComparison ? Palette.deleteInk : .white)
            .disabled(isLastComparison && deleteIDs.isEmpty)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.bottom, 20)
        .background(Palette.background)
        .navigationTitle("\(group.photoIDs.count)枚を比較 · \(min(compared.count + 1, group.photoIDs.count - 1)) / \(group.photoIDs.count - 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("似ていない") {
                    dismissedGroupsData = DismissedGroups.adding(group.id, to: dismissedGroupsData)
                    dismiss()
                }
            }
        }
    }

    private var primaryTitle: String {
        if isLastComparison {
            return deleteIDs.isEmpty ? "削除する写真はありません" : "\(deleteIDs.count)枚を削除予定に入れる"
        }
        return decisions[champion] == .keep ? "上を残して次と比べる" : "次の写真と比べる"
    }

    /// 次の写真へ。下の写真を残して上を削除にしていたら、下が新しい勝者になる。
    private func advance() {
        guard !isLastComparison else {
            let records = deleteIDs.compactMap { scan.records[$0] }
            tray.add(records, from: .similar)
            dismiss()
            return
        }
        guard let challenger else { return }
        if decisions[champion] == .delete, decisions[challenger] == .keep {
            // 下の写真が勝ったら、それを上に上げて残りと比べる
            compared.insert(champion)
            champion = challenger
        } else {
            compared.insert(challenger)
        }
        resetZoom()
    }

    private func resetZoom() {
        zoom = 1
        committedZoom = 1
        pan = .zero
        committedPan = .zero
    }

    /// 写真（角丸18）の内側10pt → 残す／削除の切り替え角丸8、その内側3pt → ボタン角丸5。
    private func photoPanel(_ id: String) -> some View {
        let isKeep = decisions[id] == .keep
        return VStack(alignment: .leading, spacing: 8) {
            PhotoThumbnail(id: id, maxPixel: 1200)
                .scaleEffect(zoom)
                .offset(pan)
                .frame(maxWidth: .infinity)
                .frame(height: 215)
                .clipShape(.rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(id == group.bestID ? Palette.keep : .clear, lineWidth: 3)
                }
                .overlay(alignment: .topLeading) {
                    if id == group.bestID {
                        Text("ベスト")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Palette.keep, in: .rect(cornerRadius: Metrics.innerRadius(outer: 18, inset: 12)))
                            .padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    decisionToggle(for: id, isKeep: isKeep)
                        .padding(10)
                }
                .gesture(zoomGesture.simultaneously(with: panGesture))

            HStack(spacing: 6) {
                ForEach(chips(for: id), id: \.self) { chip in
                    Text(chip)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Palette.surface2, in: .capsule)
                }
            }
        }
    }

    private func decisionToggle(for id: String, isKeep: Bool) -> some View {
        HStack(spacing: 4) {
            toggleButton("残す", selected: isKeep, color: Palette.keep, textColor: .white) { decisions[id] = .keep }
            toggleButton("削除", selected: !isKeep, color: Palette.delete, textColor: Palette.deleteInk) { decisions[id] = .delete }
        }
        .padding(3)
        .background(.black.opacity(0.62), in: .rect(cornerRadius: 8))
    }

    private func toggleButton(_ title: String, selected: Bool, color: Color, textColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? textColor : Color(hex: 0xD5D8DD))
                .frame(width: 60, height: 34)
                .background(selected ? color : .clear, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var filmstrip: some View {
        HStack(spacing: 5) {
            ForEach(group.photoIDs, id: \.self) { id in
                PhotoThumbnail(id: id, maxPixel: 120)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(id == champion ? Palette.keep : (id == challenger ? Palette.text : .clear), lineWidth: 2)
                    }
                    .opacity(id == champion || id == challenger ? 1 : 0.5)
                    .overlay(alignment: .bottomTrailing) {
                        if decisions[id] == .delete {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Palette.delete)
                                .padding(2)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func chips(for id: String) -> [String] {
        guard let record = scan.records[id] else { return [] }
        let members = group.photoIDs.compactMap { scan.records[$0] }
        let maxSharpness = members.map(\.sharpness).max() ?? 0
        var chips: [String] = []
        if maxSharpness > 0 {
            chips.append("シャープ \(Int((record.sharpness / maxSharpness * 100).rounded()))")
        }
        if let face = record.faceQuality {
            chips.append(face >= 0.5 ? "顔の写り 良" : "顔の写り 弱")
        }
        chips.append("\(Int((Double(record.pixelWidth * record.pixelHeight) / 1_000_000).rounded())) MP")
        if record.isFavorite { chips.append("お気に入り") }
        return chips
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in zoom = min(max(committedZoom * value.magnification, 1), 5) }
            .onEnded { _ in
                committedZoom = zoom
                if zoom == 1 { pan = .zero; committedPan = .zero }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > 1 else { return }
                pan = CGSize(width: committedPan.width + value.translation.width, height: committedPan.height + value.translation.height)
            }
            .onEnded { _ in committedPan = pan }
    }
}
