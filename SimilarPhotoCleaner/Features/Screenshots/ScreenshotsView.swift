import SwiftUI

/// スクリーンショットと書類・レシートの一括整理。最初は全部選択し、残すものだけ外す。
struct ScreenshotsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case older = "30日以上前"
        case all = "すべて"
        case documents = "書類・レシート"
        var id: Self { self }
    }

    @Environment(ScanCoordinator.self) private var scan
    @Environment(DeletionTray.self) private var tray
    @State private var filter: Filter = .older
    @State private var selection: Set<String> = []

    private var items: [PhotoRecord] {
        let source: [PhotoRecord]
        switch filter {
        case .older:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            source = scan.index.screenshots.filter { $0.creationDate < cutoff }
        case .all:
            source = scan.index.screenshots
        case .documents:
            source = scan.index.utilityPhotos
        }
        return source.filter { !tray.contains($0.id) }
    }

    private var selectedItems: [PhotoRecord] {
        items.filter { selection.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("期間", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                (Text("\(selectedItems.count.formatted())枚を選択中").foregroundStyle(Palette.text).fontWeight(.semibold)
                 + Text(" · \(items.count.formatted())枚のうち · \(selectedItems.reduce(0) { $0 + $1.estimatedBytes }.formattedBytes)"))
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .monospacedDigit()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(items) { item in
                        tile(item)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 100)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(filter == .documents ? "書類・レシートの写真はありません" : "スクリーンショットはありません", systemImage: "iphone")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                Button {
                    tray.add(selectedItems, from: .screenshot)
                    selection = []
                } label: {
                    Text("\(selectedItems.count.formatted())枚を削除予定に入れる")
                        .font(.headline)
                        .foregroundStyle(Palette.deleteInk)
                        .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.delete)
                .disabled(selectedItems.isEmpty)
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 8)
            }
        }
        .background(Palette.background)
        .navigationTitle("スクリーンショット")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectedItems.isEmpty ? "全選択" : "全解除") {
                    selection = selectedItems.isEmpty ? Set(items.map(\.id)) : []
                }
                .disabled(items.isEmpty)
            }
        }
        .onAppear { selectAll() }
        .onChange(of: filter) { selectAll() }
    }

    private func selectAll() {
        selection = Set(items.map(\.id))
    }

    private func tile(_ item: PhotoRecord) -> some View {
        let isSelected = selection.contains(item.id)
        return Button {
            if isSelected { selection.remove(item.id) } else { selection.insert(item.id) }
        } label: {
            PhotoThumbnail(id: item.id, maxPixel: 300)
                .aspectRatio(item.isScreenshot ? 9 / 19.5 : 3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(isSelected ? Palette.delete : .black.opacity(0.25))
                        .strokeBorder(isSelected ? Palette.delete : .white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Palette.deleteInk)
                            }
                        }
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.creationDate.formatted(date: .abbreviated, time: .shortened))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
