import SwiftUI

struct SettingsView: View {
    @Environment(ScanCoordinator.self) private var scan
    @State private var cacheBytes: Int64 = 0
    @State private var isConfirmingClear = false
    @State private var isConfirmingRescan = false
    @State private var errorMessage: String?

    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.sensitivity) private var sensitivity: Sensitivity = .standard
    @AppStorage(SettingsKey.excludeFavorites) private var excludeFavorites = true
    @AppStorage(SettingsKey.excludeEdited) private var excludeEdited = true
    @AppStorage(SettingsKey.autoScanWhileCharging) private var autoScanWhileCharging = true
    @AppStorage(SettingsKey.notifyNewCandidates) private var notifyNewCandidates = false

    var body: some View {
        NavigationStack {
            Form {
                Section("表示") {
                    Picker("外観", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Palette.surface)
                }

                Section("似た写真の判定") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("まとめる範囲")
                            Spacer()
                            Text(sensitivity.label).foregroundStyle(Palette.text2)
                        }
                        Slider(value: sensitivityValue, in: 0...2, step: 1) {
                            Text("まとめる範囲")
                        } minimumValueLabel: {
                            Text("ほぼ同じだけ").font(.caption)
                        } maximumValueLabel: {
                            Text("広めに").font(.caption)
                        }
                        .accessibilityValue(sensitivity.label)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Palette.surface)
                }

                Section {
                    Toggle("お気に入り", isOn: $excludeFavorites)
                    Toggle("編集した写真", isOn: $excludeEdited)
                } header: {
                    Text("削除候補にしない写真")
                } footer: {
                    Text("共有アルバムの写真は、はじめから整理の対象になりません。")
                }
                .listRowBackground(Palette.surface)

                Section {
                    Toggle("充電中に自動でスキャン", isOn: $autoScanWhileCharging)
                    Toggle("新しい候補を通知", isOn: $notifyNewCandidates)
                        .disabled(!autoScanWhileCharging)
                } header: {
                    Text("スキャン")
                } footer: {
                    Text("充電中でしばらく使っていないときに、新しい写真を解析します。")
                }
                .listRowBackground(Palette.surface)

                Section {
                    LabeledContent("解析キャッシュ", value: scan.records.isEmpty ? "まだありません" : "\(scan.records.count.formatted())枚 · \(cacheBytes.formattedBytes)")
                        .monospacedDigit()
                    Button("キャッシュを削除", role: .destructive) { isConfirmingClear = true }
                        .disabled(scan.records.isEmpty)
                        .confirmationDialog("解析キャッシュを削除しますか？", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                            Button("キャッシュを削除", role: .destructive) { clearCache(rescan: false) }
                        } message: {
                            Text("写真は削除されません。次のスキャンで解析し直します。")
                        }
                    Button("最初からスキャンし直す") { isConfirmingRescan = true }
                        .disabled(!scan.isAuthorized)
                        .confirmationDialog("キャッシュを消して、最初からスキャンし直しますか？", isPresented: $isConfirmingRescan, titleVisibility: .visible) {
                            Button("スキャンし直す", role: .destructive) { clearCache(rescan: true) }
                        } message: {
                            Text("写真は削除されません。")
                        }
                } header: {
                    Text("データ")
                } footer: {
                    Text("解析キャッシュは、ファイルアプリの「このiPhone内 › SimilarPhotoCleaner › \(AnalysisCache.folderName)」にあり、そこから削除することもできます。写真と解析データはこのiPhoneの外に送信されません。バージョン \(Self.version)")
                }
                .listRowBackground(Palette.surface)
            }
            .tint(Palette.keep)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, Metrics.titleGap, for: .scrollContent)
            .contentMargins(.horizontal, Metrics.screenMargin, for: .scrollContent)
            .background(Palette.background)
            .navigationTitle("設定")
            .task(id: scan.records.count) { cacheBytes = scan.cache.sizeInBytes }
            .alert("キャッシュを削除できませんでした", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: sensitivity) { reloadGroups() }
            .onChange(of: excludeFavorites) { reloadGroups() }
            .onChange(of: excludeEdited) { reloadGroups() }
            .onChange(of: notifyNewCandidates) { _, isOn in
                guard isOn else { return }
                Task {
                    // 通知が許可されなかったらスイッチを戻す
                    if await !BackgroundScan.requestNotificationPermission() { notifyNewCandidates = false }
                }
            }
        }
    }

    /// 判定の設定が変わったら、メモリ上の解析結果からグループを作り直す（再解析もキャッシュの読み直しもしない）。
    private func reloadGroups() {
        Task { await scan.rebuildIndex() }
    }

    private func clearCache(rescan: Bool) {
        Task {
            do {
                try await scan.clearCache()
                cacheBytes = scan.cache.sizeInBytes
                if rescan { scan.startScan() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var sensitivityValue: Binding<Double> {
        Binding(
            get: { Double(sensitivity.rawValue) },
            set: { sensitivity = Sensitivity(rawValue: Int($0.rounded())) ?? .standard }
        )
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

#Preview {
    SettingsView()
        .environment(ScanCoordinator(cache: try! AnalysisCache(baseURL: .temporaryDirectory)))
}
