import SwiftUI

/// スワイプで仕分ける月。
struct SwipeMonth: Hashable {
    let kind: MediaKind
    let month: Date
    /// 撮影日時の順。
    let photoIDs: [String]
}

/// スワイプする月を選ぶ。
struct SwipeMonthsView: View {
    let kind: MediaKind

    @Environment(ScanCoordinator.self) private var scan

    private var months: [SwipeMonth] {
        let calendar = Calendar.current
        let photos = scan.records.values.filter { $0.isScreenshot == (kind == .screenshots) }
        let byMonth = Dictionary(grouping: photos) { calendar.dateInterval(of: .month, for: $0.creationDate)?.start ?? $0.creationDate }
        return byMonth
            .map { SwipeMonth(kind: kind, month: $0.key, photoIDs: $0.value.sorted { $0.creationDate < $1.creationDate }.map(\.id)) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        List(months, id: \.month) { month in
            NavigationLink(value: month) {
                HStack {
                    Text(month.month.formatted(.dateTime.year().month()))
                    Spacer()
                    Text("\(month.photoIDs.count.formatted())枚")
                        .foregroundStyle(Palette.text2)
                        .monospacedDigit()
                }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .overlay {
            if months.isEmpty {
                ContentUnavailableView(kind == .photos ? "写真がありません" : "スクリーンショットがありません", systemImage: "photo")
            }
        }
        .navigationTitle(kind == .photos ? "写真をスワイプで仕分け" : "スクショをスワイプで仕分け")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// カードを右で「残す」、左で「削除予定」、上で「保留」。
struct SwipeDeckView: View {
    enum Decision {
        case keep
        case delete
        case hold
    }

    private struct Step {
        let id: String
        let decision: Decision
    }

    let month: SwipeMonth

    @Environment(ScanCoordinator.self) private var scan
    @Environment(DeletionTray.self) private var tray
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.excludeFavorites) private var protectFavorites = true

    @State private var index = 0
    @State private var steps: [Step] = []
    @State private var drag: CGSize = .zero
    @State private var pendingFavorite: String?

    private let threshold: CGFloat = 110

    private var traySource: DeletionSource {
        month.kind == .screenshots ? .screenshot : .swipe
    }

    private var currentID: String? {
        index < month.photoIDs.count ? month.photoIDs[index] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(index), total: Double(max(month.photoIDs.count, 1)))
                .tint(Palette.keepText)
                .padding(.top, 8)

            if currentID == nil {
                finished
            } else {
                deck
                    .padding(.top, 20)
                controls
                    .padding(.top, 16)
                Text("削除予定 \(tray.items(from: traySource).count)枚 · \(tray.items(from: traySource).reduce(0) { $0 + $1.bytes }.formattedBytes)")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .monospacedDigit()
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .background(Palette.background)
        .navigationTitle(month.month.formatted(.dateTime.year().month()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(min(index + 1, month.photoIDs.count)) / \(month.photoIDs.count)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Palette.text2)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: index)
        .confirmationDialog("お気に入りの写真です。削除予定に入れますか？", isPresented: .init(
            get: { pendingFavorite != nil },
            set: { if !$0 { pendingFavorite = nil; withAnimation(.snappy) { drag = .zero } } }
        ), titleVisibility: .visible) {
            Button("削除予定に入れる", role: .destructive) {
                if let id = pendingFavorite { commit(.delete, for: id) }
                pendingFavorite = nil
            }
        }
    }

    private var deck: some View {
        ZStack {
            ForEach(Array(month.photoIDs.enumerated().dropFirst(index).prefix(3).reversed()), id: \.element) { offset, id in
                let depth = offset - index
                card(for: id, isTop: depth == 0)
                    .scaleEffect(1 - CGFloat(depth) * 0.04)
                    .offset(y: CGFloat(depth) * 10)
                    .opacity(depth == 2 ? 0.5 : 1)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func card(for id: String, isTop: Bool) -> some View {
        let record = scan.records[id]
        return PhotoThumbnail(id: id, maxPixel: 1200)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    if let record {
                        Text(record.creationDate.formatted(.dateTime.month().day().hour().minute()))
                            .font(.headline)
                        HStack(spacing: 6) {
                            infoChip(record.estimatedBytes.formattedBytes)
                            if let size = groupSize(of: id) { infoChip("似た写真 \(size)枚のうち1枚") }
                            if record.isFavorite { infoChip("お気に入り") }
                        }
                    }
                }
                .foregroundStyle(Color(hex: 0xF3F3F0))
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(alignment: .top) {
                if isTop { stamp }
            }
            .clipShape(.rect(cornerRadius: 26))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 16)
            .offset(isTop ? drag : .zero)
            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : 0), anchor: .bottom)
            .gesture(isTop ? dragGesture(for: id) : nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("写真 \(index + 1)枚目")
            .accessibilityActions {
                if isTop {
                    Button("残す") { decide(.keep, for: id) }
                    Button("削除予定に入れる") { decide(.delete, for: id) }
                    Button("保留") { decide(.hold, for: id) }
                }
            }
    }

    @ViewBuilder
    private var stamp: some View {
        if drag.width < -30 {
            stampLabel("削除", color: Palette.delete).frame(maxWidth: .infinity, alignment: .trailing)
        } else if drag.width > 30 {
            stampLabel("残す", color: Palette.keepText).frame(maxWidth: .infinity, alignment: .leading)
        } else if drag.height < -30 {
            stampLabel("保留", color: Color(hex: 0xECEEF2))
        }
    }

    private func stampLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title2.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(drag.width < 0 ? 12 : -12))
            .padding(26)
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(.white.opacity(0.16), in: .capsule)
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 22) {
            controlButton("取り消し", systemImage: "arrow.uturn.backward", size: 48, fill: Palette.surface2, ink: Palette.text) { undo() }
                .disabled(steps.isEmpty)
            controlButton("削除", systemImage: "trash", size: 68, fill: Palette.delete, ink: Palette.deleteInk) {
                if let id = currentID { decide(.delete, for: id) }
            }
            controlButton("保留", systemImage: "arrow.up", size: 52, fill: Palette.surface2, ink: Palette.text) {
                if let id = currentID { decide(.hold, for: id) }
            }
            controlButton("残す", systemImage: "checkmark", size: 68, fill: Palette.keep, ink: .white) {
                if let id = currentID { decide(.keep, for: id) }
            }
        }
    }

    private func controlButton(_ title: String, systemImage: String, size: CGFloat, fill: Color, ink: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(ink)
                    .frame(width: size, height: size)
                    .background(fill, in: .circle)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Palette.text2)
            }
        }
        .buttonStyle(.plain)
    }

    private var finished: some View {
        let deleted = steps.filter { $0.decision == .delete }.count
        let kept = steps.filter { $0.decision == .keep }.count
        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.keep)
            Text("この月の仕分けが終わりました")
                .font(.title3.bold())
            Text("残す \(kept)枚 / 削除予定 \(deleted)枚")
                .foregroundStyle(Palette.text2)
                .monospacedDigit()
            Spacer()
            Button {
                navigation.selectedTab = .tray
                dismiss()
            } label: {
                Text("削除予定を見る")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.keep)
            Button("ほかの月を選ぶ") { dismiss() }
                .padding(.bottom, 16)
        }
    }

    private func dragGesture(for id: String) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width > threshold {
                    decide(.keep, for: id)
                } else if value.translation.width < -threshold {
                    decide(.delete, for: id)
                } else if value.translation.height < -threshold {
                    decide(.hold, for: id)
                } else {
                    withAnimation(.snappy) { drag = .zero }
                }
            }
    }

    private func decide(_ decision: Decision, for id: String) {
        if decision == .delete, protectFavorites, scan.records[id]?.isFavorite == true {
            pendingFavorite = id
            return
        }
        commit(decision, for: id)
    }

    /// カードを画面の外へ飛ばしてから次のカードへ進む。
    private func commit(_ decision: Decision, for id: String) {
        let exit: CGSize = switch decision {
        case .keep: CGSize(width: 600, height: drag.height)
        case .delete: CGSize(width: -600, height: drag.height)
        case .hold: CGSize(width: drag.width, height: -900)
        }
        if decision == .delete, let record = scan.records[id] {
            tray.add([record], from: month.kind == .screenshots ? .screenshot : .swipe)
        }
        steps.append(Step(id: id, decision: decision))
        withAnimation(.easeOut(duration: 0.2)) {
            drag = exit
        } completion: {
            index += 1
            drag = .zero
        }
    }

    private func undo() {
        guard let last = steps.popLast() else { return }
        if last.decision == .delete {
            tray.remove([last.id])
        }
        index = max(index - 1, 0)
        drag = .zero
    }

    private func groupSize(of id: String) -> Int? {
        scan.index.groups(of: month.kind).first { $0.photoIDs.contains(id) }?.photoIDs.count
    }
}
