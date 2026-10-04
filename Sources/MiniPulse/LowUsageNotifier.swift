import Foundation
import UserNotifications

@MainActor
final class LowUsageNotifier {
    private let defaults: UserDefaults
    private var deliveredKeys: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.deliveredKeys = Set(defaults.stringArray(forKey: "notifiedUsageWindows") ?? [])
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func notifyIfNeeded(snapshot: UsageSnapshot, threshold: Int) async {
        for window in [snapshot.fiveHour, snapshot.weekly].compactMap({ $0 }) {
            guard window.remainingPercent <= threshold else { continue }

            let resetKey = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
            let key = "\(window.durationMinutes)-\(resetKey)-\(threshold)"
            guard deliveredKeys.insert(key).inserted else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Codex usage is low"
            content.body = "\(window.displayName): \(window.remainingPercent)% remaining."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "mini-pulse-\(key)",
                content: content,
                trigger: nil
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                deliveredKeys.remove(key)
            }
        }

        deliveredKeys = Set(deliveredKeys.suffix(24))
        defaults.set(Array(deliveredKeys), forKey: "notifiedUsageWindows")
    }
}
