import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
            guard notificationsEnabled else { return }
            Task { await notifier.requestAuthorization() }
        }
    }

    @Published var notificationThreshold: Int {
        didSet {
            defaults.set(notificationThreshold, forKey: "notificationThreshold")
        }
    }

    private let client: CodexAppServerClient
    private let notifier: LowUsageNotifier
    private let defaults: UserDefaults
    private var refreshLoop: Task<Void, Never>?

    init(
        client: CodexAppServerClient = CodexAppServerClient(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        self.notifier = LowUsageNotifier(defaults: defaults)
        self.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        let savedThreshold = defaults.integer(forKey: "notificationThreshold")
        self.notificationThreshold = savedThreshold == 0 ? 20 : savedThreshold.clamped(to: 5...50)

        Task { [weak self] in
            self?.start()
        }
    }

    var menuTitle: String {
        guard let snapshot else { return isRefreshing ? "Codex …" : "Codex —" }
        let fiveHour = snapshot.fiveHour.map { "5H \($0.remainingPercent)%" } ?? "5H —"
        let weekly = snapshot.weekly.map { "W \($0.remainingPercent)%" } ?? "W —"
        let credits = "C \(CreditBalanceFormatter.wholeCredits(snapshot.creditBalance))"
        return "\(fiveHour) · \(weekly) · \(credits)"
    }

    func start() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(300))
                } catch {
                    return
                }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newSnapshot = try await client.fetchUsage()
            snapshot = newSnapshot
            errorMessage = nil

            if notificationsEnabled {
                await notifier.notifyIfNeeded(
                    snapshot: newSnapshot,
                    threshold: notificationThreshold
                )
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
