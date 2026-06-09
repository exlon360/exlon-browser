import Foundation

struct AppCrashLogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var reason: String
    var detail: String
    var occurredAt: Date
    var appVersion: String
    var buildNumber: String
    var isUnread: Bool

    init(
        id: UUID = UUID(),
        title: String,
        reason: String,
        detail: String,
        occurredAt: Date = Date(),
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
        buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown",
        isUnread: Bool = true
    ) {
        self.id = id
        self.title = title
        self.reason = reason
        self.detail = detail
        self.occurredAt = occurredAt
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.isUnread = isUnread
    }
}

final class AppCrashReporter {
    static let shared = AppCrashReporter()

    private let defaults = UserDefaults.standard
    private let logsKey = "ZenFireBrowser.crashReporter.logs"
    private let activeKey = "ZenFireBrowser.crashReporter.activeSession"
    private let sessionStartedAtKey = "ZenFireBrowser.crashReporter.sessionStartedAt"
    private let sessionIDKey = "ZenFireBrowser.crashReporter.sessionID"
    private var hasStarted = false

    private init() {}

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true

        if defaults.bool(forKey: activeKey) {
            let startedAt = defaults.object(forKey: sessionStartedAtKey) as? Date
            append(
                AppCrashLogEntry(
                    title: "Previous session ended unexpectedly",
                    reason: "Crash or forced termination detected",
                    detail: detailForUncleanExit(startedAt: startedAt)
                )
            )
        }

        NSSetUncaughtExceptionHandler(glideHandleUncaughtException)
        markSessionActive()
    }

    func markSessionActive() {
        defaults.set(true, forKey: activeKey)
        if defaults.string(forKey: sessionIDKey) == nil {
            defaults.set(UUID().uuidString, forKey: sessionIDKey)
        }
        if defaults.object(forKey: sessionStartedAtKey) == nil {
            defaults.set(Date(), forKey: sessionStartedAtKey)
        }
    }

    func markCleanExit() {
        defaults.set(false, forKey: activeKey)
        defaults.removeObject(forKey: sessionStartedAtKey)
        defaults.removeObject(forKey: sessionIDKey)
    }

    func logs() -> [AppCrashLogEntry] {
        guard let data = defaults.data(forKey: logsKey),
              let logs = try? JSONDecoder().decode([AppCrashLogEntry].self, from: data) else {
            return []
        }
        return logs
    }

    func markAllSeen() {
        var currentLogs = logs()
        for index in currentLogs.indices {
            currentLogs[index].isUnread = false
        }
        save(currentLogs)
    }

    func clearLogs() {
        defaults.removeObject(forKey: logsKey)
    }

    func record(exception: NSException) {
        append(
            AppCrashLogEntry(
                title: "Uncaught exception",
                reason: exception.name.rawValue,
                detail: exception.reason ?? "No exception reason was provided."
            )
        )
    }

    private func append(_ entry: AppCrashLogEntry) {
        var currentLogs = logs()
        currentLogs.insert(entry, at: 0)
        if currentLogs.count > 30 {
            currentLogs = Array(currentLogs.prefix(30))
        }
        save(currentLogs)
    }

    private func save(_ logs: [AppCrashLogEntry]) {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        defaults.set(data, forKey: logsKey)
    }

    private func detailForUncleanExit(startedAt: Date?) -> String {
        guard let startedAt = startedAt else {
            return "Glide relaunched while the previous foreground session was still marked active."
        }

        return "Glide relaunched after a foreground session that began \(startedAt.formatted(date: .abbreviated, time: .standard)) without writing a clean shutdown marker."
    }
}

private func glideHandleUncaughtException(_ exception: NSException) {
    AppCrashReporter.shared.record(exception: exception)
}
