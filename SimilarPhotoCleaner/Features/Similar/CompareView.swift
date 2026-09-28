import SwiftUI

/// 比較モード: グループ内の写真を2枚ずつ並べ、勝ち抜き形式で残す1枚を選ぶ。
/// 縦長の写真を含むときは左右に、横長どうしは上下に並べ、どちらも写真全体を表示する。
struct CompareView: View {
    enum Decision {
        case keep
        case delete
    }

    private struct ScrollEdges: Equatable {
        var canScrollLeft = false
        var canScrollRight = false
    }

    let group: SimilarGroup

    @Environment(ScanCoordinator.self) private var scan
    @Environment(DeletionTray.self) private var tray
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DismissedGroups.storageKey) private var dismissedGroupsData = Data()

    /// 今のところ残す写真（左または上）。
    @State private var champion: String
    /// 比べ終わった写真（勝者以外）。
    @State private var compared: Set<String> = []
    /// 下の一覧でタップして選んだ、次に比べる写真。
    @State private var picked: String?
    @State private var decisions: [String: Decision]
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero
    @State private var edges = ScrollEdges()

    private let panelRadius: CGFloat = 18

    init(group: SimilarGroup) {
        self.group = group
        _champion = State(initialValue: group.bestID)
        _decisions = State(initialValue: Dictionary(uniqueKeysWithValues: group.photoIDs.map {
            ($0, group.candidateIDs.contains($0) ? .delete : .keep)
        }))
    }

    private var challenger: String? {
        if let picked, picked != champion { return picked }
        return group.photoIDs.first { $0 != champion && !compared.contains($0) }
    }

    /// 今の2枚のほかに、まだ比べていない写真がないか。
    private var isLastComparison: Bool {
        !group.photoIDs.contains { $0 != champion && $0 != challenger && !compared.contains($0) }
    }

    private var deleteIDs: [String] {
        group.photoIDs.filter { decisions[$0] == .delete }
    }

    private var traySource: DeletionSource {
        group.kind == .screenshots ? .screenshot : .similar
    }

    var body: some View {
        VStack(spacing: 0) {
            comparison
                .frame(maxHeight: .infinity)
                .padding(.top, 20)

            Text("ピンチで2枚を同時に拡大できます")
                .font(.footnote)
                .foregroundStyle(Palette.text2)
                .padding(.top, 12)

            filmstrip
                .padding(.top, 12)

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
            .padding(.top, 14)
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

    // MARK: - 2枚の比較

    @ViewBuilder
    private var comparison: some View {
        let ids = [champion, challenger].compactMap { $0 }
        if ids.contains(where: isPortrait) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(ids, id: \.self) { panel($0) }
            }
        } else {
            VStack(spacing: 14) {
                ForEach(ids, id: \.self) { panel($0) }
            }
        }
    }

    private func aspectRatio(of id: String) -> CGFloat {
        guard let record = scan.records[id], record.pixelHeight > 0 else { return 3 / 4 }
        return CGFloat(record.pixelWidth) / CGFloat(record.pixelHeight)
    }

    private func isPortrait(_ id: String) -> Bool {
        guard let record = scan.records[id] else { return false }
        return record.pixelHeight > record.pixelWidth
    }

    /// 写真（角丸18）の内側10pt → ベストラベルの角丸8。切り替え（角丸12）の内側3pt → ボタン角丸9。
    private func panel(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotoThumbnail(id: id, maxPixel: 1400)
                .scaleEffect(zoom)
                .offset(pan)
                // 枠を写真の縦横比に合わせ、写真全体を余白なしで見せる
                .aspectRatio(aspectRatio(of: id), contentMode: .fit)
                .clipShape(.rect(cornerRadius: panelRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: panelRadius)
                        .strokeBorder(id == group.bestID ? Palette.keep : .clear, lineWidth: 3)
                }
                .overlay(alignment: .topLeading) {
                    if id == group.bestID {
                        Text("ベスト")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Palette.keep, in: .rect(cornerRadius: Metrics.innerRadius(outer: panelRadius, inset: 10)))
                            .padding(10)
                    }
                }
                .contentShape(.rect)
                .gesture(zoomGesture.simultaneously(with: panGesture))
                .accessibilityLabel(id == champion ? "残す候補の写真" : "比べている写真")
                .frame(maxWidth: .infinity)

            decisionToggle(for: id)

            HStack(spacing: 6) {
                ForEach(chips(for: id), id: \.self) { chip in
                    Text(chip)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Palette.surface2, in: .capsule)
                }
            }
        }
    }

    private func decisionToggle(for id: String) -> some View {
        let isKeep = decisions[id] == .keep
        return HStack(spacing: 4) {
            toggleButton("残す", selected: isKeep, color: Palette.keep, textColor: .white) { decisions[id] = .keep }
            toggleButton("削除", selected: !isKeep, color: Palette.delete, textColor: Palette.deleteInk) { decisions[id] = .delete }
        }
        .padding(3)
        .background(Palette.surface2, in: .rect(cornerRadius: 12))
    }

    private func toggleButton(_ title: String, selected: Bool, color: Color, textColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? textColor : Palette.text2)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(selected ? color : .clear, in: .rect(cornerRadius: Metrics.innerRadius(outer: 12, inset: 3)))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 下の一覧

    /// 正方形のサムネイルを横にスクロールする。続きがある側の端はグラデーションでぼかす。
    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.photoIDs, id: \.self) { id in
                        filmstripItem(id)
                            .id(id)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 3)
            }
            .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                ScrollEdges(
                    canScrollLeft: geometry.contentOffset.x > 1,
                    canScrollRight: geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 1
                )
            } action: { _, newValue in
                withAnimation(.easeOut(duration: 0.15)) { edges = newValue }
            }
            .overlay(alignment: .leading) {
                if edges.canScrollLeft { edgeFade(from: .leading) }
            }
            .overlay(alignment: .trailing) {
                if edges.canScrollRight { edgeFade(from: .trailing) }
            }
            .onChange(of: challenger) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 70)
    }

    private func filmstripItem(_ id: String) -> some View {
        let isChampion = id == champion
        let isChallenger = id == challenger
        return Button {
            guard !isChampion else { return }
            picked = id
            resetZoom()
        } label: {
            PhotoThumbnail(id: id, maxPixel: 180)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isChampion ? Palette.keep : (isChallenger ? Palette.text : .clear), lineWidth: 3)
                }
                .overlay(alignment: .bottomTrailing) {
                    decisionBadge(decisions[id] ?? .keep)
                        .padding(4)
                }
                .opacity(isChampion || isChallenger || !compared.contains(id) ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isChampion ? "残す候補" : "この写真と比べる")
        .accessibilityValue(decisions[id] == .delete ? "削除" : "残す")
    }

    /// サムネイルの右下に出す「残す／削除」の印。写真の上でも見えるよう白い縁を付ける。
    private func decisionBadge(_ decision: Decision) -> some View {
        let isDelete = decision == .delete
        return Image(systemName: isDelete ? "trash.fill" : "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(isDelete ? Palette.delete : Palette.keep, in: .circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private func edgeFade(from edge: Edge) -> some View {
        LinearGradient(
            colors: [Palette.background, Palette.background.opacity(0)],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: 40)
        .allowsHitTesting(false)
    }

    // MARK: - 進め方

    private var primaryTitle: String {
        if isLastComparison {
            return deleteIDs.isEmpty ? "削除する写真はありません" : "\(deleteIDs.count)枚を削除予定に入れる"
        }
        return "次の写真と比べる"
    }

    /// 次の写真へ。比べていた写真を残して今の候補を削除にしていたら、そちらが新しい残す候補になる。
    private func advance() {
        guard !isLastComparison else {
            let records = deleteIDs.compactMap { scan.records[$0] }
            tray.add(records, from: traySource)
            dismiss()
            return
        }
        guard let challenger else { return }
        if decisions[champion] == .delete, decisions[challenger] == .keep {
            compared.insert(champion)
            champion = challenger
        } else {
            compared.insert(challenger)
        }
        picked = nil
        resetZoom()
    }

    private func resetZoom() {
        zoom = 1
        committedZoom = 1
        pan = .zero
        committedPan = .zero
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
            chips.append(face >= 0.5 ? "顔 良" : "顔 弱")
        }
        chips.append("\(Int((Double(record.pixelWidth * record.pixelHeight) / 1_000_000).rounded())) MP")
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
