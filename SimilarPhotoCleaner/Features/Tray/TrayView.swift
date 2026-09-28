import SwiftData
import SwiftUI

/// 削除予定トレイ。全モードで選んだ写真をまとめて削除する。
struct TrayView: View {
    @Environment(DeletionTray.self) private var tray
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context

    @State private var isDeleting = false
    @State private var result: DeletionResult?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if tray.count == 0 {
                    ContentUnavailableView(
                        "削除予定の写真はありません",
                        systemImage: "trash",
                        description: Text("似た写真・スワイプ・スクリーンショットで選んだ写真がここに集まります。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .background(Palette.background)
            .navigationTitle("削除予定")
            .sheet(item: $result) { result in
                DoneView(result: result)
            }
            .alert("削除できませんでした", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                (Text("\(tray.count.formatted())枚 · ") + Text(tray.totalBytes.formattedBytes).foregroundStyle(Palette.deleteText))
                    .font(.headline)
                    .monospacedDigit()

                ForEach(DeletionSource.allCases, id: \.self) { source in
                    let items = tray.items(from: source)
                    if !items.isEmpty {
                        section(source, items: items)
                    }
                }

                Text("写真をタップすると削除予定から外せます。削除した写真は「最近削除した項目」に30日間残り、iCloud写真ではほかのデバイスからも消えます。")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await deleteAll() }
            } label: {
                Label(isDeleting ? "削除しています…" : "\(tray.count.formatted())枚を削除", systemImage: "trash")
                    .font(.headline)
                    .foregroundStyle(Palette.deleteInk)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.delete)
            .disabled(isDeleting)
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 8)
        }
    }

    private func section(_ source: DeletionSource, items: [DeletionTray.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(source.label + "から").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count.formatted())枚 · \(items.reduce(0) { $0 + $1.bytes }.formattedBytes)")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                    .monospacedDigit()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(items) { item in
                    Button {
                        withAnimation { tray.remove([item.id]) }
                    } label: {
                        PhotoThumbnail(id: item.id, maxPixel: 160)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("削除予定から外す")
                }
            }
        }
    }

    /// iOS の確認ダイアログを経てまとめて削除する。キャンセルされたらトレイはそのまま。
    private func deleteAll() async {
        let items = tray.items
        let ids = items.map(\.id)
        isDeleting = true
        defer { isDeleting = false }
        do {
            switch try await PhotoLibrary.delete(ids: ids) {
            case .deleted:
                let bytesBySource = tray.bytesBySource
                context.insert(DeletionRecord(count: items.count, bytesBySource: bytesBySource))
                try? context.save()
                tray.clear()
                await scan.removeDeleted(Set(ids), context: context)
                result = DeletionResult(count: items.count, bytes: bytesBySource.values.reduce(0, +))
            case .cancelled:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DeletionResult: Identifiable {
    let id = UUID()
    let count: Int
    let bytes: Int64
}

/// 削除完了。容量を空ける手順を案内する。
struct DoneView: View {
    let result: DeletionResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Palette.keep, in: .circle)
                .padding(.top, 48)
            Text("\(result.count.formatted())枚を削除しました")
                .font(.title2.bold())
            Text(result.bytes.formattedBytes)
                .font(.system(size: 56, weight: .bold))
                .monospacedDigit()
            Text("を「最近削除した項目」に移しました")
                .font(.subheadline)
                .foregroundStyle(Palette.text2)

            VStack(alignment: .leading, spacing: 12) {
                Text("すぐに容量を空けるには").font(.headline)
                step(1, "写真アプリを開く")
                step(2, "「最近削除した項目」を開く")
                step(3, "「すべて削除」をタップ")
                Text("そのままにしても、30日後に自動で消えて容量が戻ります。")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.top, 22)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("完了")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Palette.text)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.bottom, 16)
        .background(Palette.background)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.footnote.bold())
                .frame(width: 26, height: 26)
                .background(Palette.surface2, in: .circle)
            Text(text)
        }
    }
}
