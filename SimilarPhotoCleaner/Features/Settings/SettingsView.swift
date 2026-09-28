import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context
    @State private var analyzedCount = 0
    @State private var isConfirmingRescan = false

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

                Section("スキャン") {
                    Toggle("充電中に自動でスキャン", isOn: $autoScanWhileCharging)
                    Toggle("新しい候補を通知", isOn: $notifyNewCandidates)
                }
                .listRowBackground(Palette.surface)

                Section {
                    LabeledContent("解析済みの写真", value: analyzedCount == 0 ? "まだありません" : "\(analyzedCount.formatted())枚")
                    Button("最初からスキャンし直す") { isConfirmingRescan = true }
                        .disabled(scan.phase == .scanning || !scan.isAuthorized)
                        .confirmationDialog("解析データを消して、最初からスキャンし直しますか？", isPresented: $isConfirmingRescan, titleVisibility: .visible) {
                            Button("スキャンし直す", role: .destructive) { rescan() }
                        } message: {
                            Text("写真は削除されません。")
                        }
                } header: {
                    Text("データ")
                } footer: {
                    Text("写真と解析データはこのiPhoneの外に送信されません。バージョン \(Self.version)")
                }
                .listRowBackground(Palette.surface)
            }
            .tint(Palette.keep)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("設定")
            .task(id: scan.phase) { refreshCount() }
            .onChange(of: sensitivity) { reloadGroups() }
            .onChange(of: excludeFavorites) { reloadGroups() }
            .onChange(of: excludeEdited) { reloadGroups() }
        }
    }

    private func refreshCount() {
        analyzedCount = (try? context.fetchCount(FetchDescriptor<AnalyzedPhoto>())) ?? 0
    }

    /// 判定の設定が変わったら、保存済みの解析結果からグループを作り直す（再解析はしない）。
    private func reloadGroups() {
        Task { await scan.reloadIndex(context: context) }
    }

    private func rescan() {
        try? context.delete(model: AnalyzedPhoto.self)
        try? context.save()
        refreshCount()
        scan.startScan(context: context)
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
        .environment(ScanCoordinator())
        .modelContainer(for: [AnalyzedPhoto.self, DeletionRecord.self], inMemory: true)
}
