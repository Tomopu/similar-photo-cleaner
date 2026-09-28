import BackgroundTasks
import OSLog
import UserNotifications

/// バックグラウンドでの解析。
/// - ユーザーが始めたスキャンは `BGContinuedProcessingTask` でアプリを閉じても続け、進み具合をシステムの UI に出す
/// - 「充電中に自動でスキャン」がオンなら `BGProcessingTask` で定期的にスキャンし、新しい候補があれば通知する
final class BackgroundScan {
    static let continuedPrefix = "com.tomopu.SimilarPhotoCleaner.scan"
    static let refreshIdentifier = "com.tomopu.SimilarPhotoCleaner.refresh"
    /// これ以上の枚数を解析するときだけ、アプリを閉じても続ける（少なければすぐ終わるため）。
    static let continuedThreshold = 200

    private let scan: ScanCoordinator
    private let logger = Logger(subsystem: "com.tomopu.SimilarPhotoCleaner", category: "background")

    init(scan: ScanCoordinator) {
        self.scan = scan
        scan.onScanPlanned = { [weak self] pending in
            guard let self, pending >= Self.continuedThreshold else { return }
            self.beginContinuedScan(total: pending)
        }
    }

    // MARK: - アプリを閉じても続けるスキャン

    private func beginContinuedScan(total: Int) {
        let identifier = "\(Self.continuedPrefix).\(UUID().uuidString.prefix(8))"
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [weak self] task in
            Task { @MainActor in self?.attach(task) }
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "写真を解析中", subtitle: "\(total.formatted())枚")
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.info("バックグラウンドでの継続を開始できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func attach(_ task: BGTask) {
        guard let task = task as? BGContinuedProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        guard scan.phase == .scanning else {
            task.setTaskCompleted(success: true)
            return
        }
        task.expirationHandler = { [weak self] in
            Task { @MainActor in self?.scan.pause() }
        }
        scan.onProgress = { processed, total in
            task.progress.totalUnitCount = Int64(total)
            task.progress.completedUnitCount = Int64(processed)
            task.updateTitle("写真を解析中", subtitle: "\(processed.formatted()) / \(total.formatted())枚")
        }
        scan.onFinished = { [weak self] completed in
            task.setTaskCompleted(success: completed)
            self?.scan.onProgress = nil
            self?.scan.onFinished = nil
        }
    }

    // MARK: - 充電中の定期スキャン

    /// アプリの起動が終わる前に呼ぶ必要がある。
    func registerRefreshHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { [weak self] task in
            Task { @MainActor in self?.handleRefresh(task) }
        }
    }

    func scheduleRefreshIfEnabled(_ defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: SettingsKey.autoScanWhileCharging) as? Bool ?? true else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
            return
        }
        let request = BGProcessingTaskRequest(identifier: Self.refreshIdentifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.info("定期スキャンを予約できなかった: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleRefresh(_ task: BGTask) {
        scheduleRefreshIfEnabled()
        guard scan.isAuthorized, scan.phase != .scanning else {
            task.setTaskCompleted(success: true)
            return
        }
        let groupsBefore = Set(scan.index.groups.map(\.id))
        task.expirationHandler = { [weak self] in
            Task { @MainActor in self?.scan.pause() }
        }
        scan.onFinished = { [weak self] completed in
            guard let self else { return }
            let newGroups = self.scan.index.groups.filter { !groupsBefore.contains($0.id) }
            if completed, !newGroups.isEmpty {
                Self.notifyNewCandidates(groups: newGroups.count, bytes: newGroups.reduce(0) { $0 + $1.reclaimableBytes })
            }
            task.setTaskCompleted(success: completed)
            self.scan.onFinished = nil
        }
        Task {
            await scan.loadFromCache()
            scan.startScan()
        }
    }

    // MARK: - 通知

    static func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])) ?? false
    }

    private static func notifyNewCandidates(groups: Int, bytes: Int64, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: SettingsKey.notifyNewCandidates) else { return }
        let content = UNMutableNotificationContent()
        content.title = "似た写真が見つかりました"
        content.body = "新しく \(groups)グループ・\(bytes.formattedBytes) を減らせます。"
        let request = UNNotificationRequest(identifier: "newCandidates", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
