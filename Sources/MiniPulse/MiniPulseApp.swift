import AppKit
import SwiftUI

@main
struct MiniPulseApp: App {
    @StateObject private var store: UsageStore

    init() {
        signal(SIGPIPE, SIG_IGN)
        let store = UsageStore()
        _store = StateObject(wrappedValue: store)

        Task { @MainActor in
            FloatingPanelPresenter.shared.show(store: store)

            if ProcessInfo.processInfo.arguments.contains("--preview-window") {
                PreviewWindowPresenter.shared.show(store: store)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            Label(store.menuTitle, systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 14) {
            header

            if let snapshot = store.snapshot {
                VStack(spacing: 10) {
                    LimitCard(window: snapshot.fiveHour, fallbackTitle: "5-Hour Limit")
                    LimitCard(window: snapshot.weekly, fallbackTitle: "Weekly Limit")
                }

                HStack {
                    Text(snapshot.plan.map { "Codex · \($0)" } ?? "Codex")
                    Spacer()
                    Text("Updated \(snapshot.observedAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if store.isRefreshing {
                ProgressView("Reading Codex usage…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ContentUnavailableView(
                    "Usage unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(store.errorMessage ?? "Open Codex and try again.")
                )
                .frame(minHeight: 150)
            }

            if let errorMessage = store.errorMessage, store.snapshot != nil {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            controls
        }
        .padding(16)
        .frame(width: 330)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mini Pulse")
                    .font(.headline)
                Text("Codex Usage Monitor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
            .disabled(store.isRefreshing)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Toggle("Notify when remaining usage is low", isOn: $store.notificationsEnabled)
                .toggleStyle(.switch)

            if store.notificationsEnabled {
                Stepper(
                    "Alert at \(store.notificationThreshold)% remaining",
                    value: $store.notificationThreshold,
                    in: 5...50,
                    step: 5
                )
                .font(.caption)
            }

            HStack {
                Text("Auto-refreshes every 5 minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

@MainActor
private final class PreviewWindowPresenter {
    static let shared = PreviewWindowPresenter()

    private var window: NSWindow?

    func show(store: UsageStore) {
        guard window == nil else { return }

        NSApplication.shared.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mini Pulse Preview"
        window.contentView = NSHostingView(rootView: MenuContentView(store: store))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct LimitCard: View {
    let window: UsageWindow?
    let fallbackTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(window?.displayName ?? fallbackTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(window.map { "\($0.remainingPercent)%" } ?? "—")
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            }

            RemainingBar(
                remainingPercent: window?.remainingPercent ?? 0,
                tint: tint
            )

            HStack {
                Text("Remaining")
                Spacer()
                Text(resetText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var tint: Color {
        guard let remaining = window?.remainingPercent else { return .secondary }
        if remaining <= 20 { return .red }
        if remaining <= 40 { return .orange }
        return .green
    }

    private var resetText: String {
        guard let resetsAt = window?.resetsAt else { return "Reset unavailable" }
        let relative = resetsAt.formatted(.relative(presentation: .numeric))
        let absolute = resetsAt.formatted(date: .abbreviated, time: .shortened)
        return "Reset \(relative) · \(absolute)"
    }
}

private struct RemainingBar: View {
    let remainingPercent: Int
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(
                        width: geometry.size.width
                            * Double(remainingPercent.clamped(to: 0...100)) / 100
                    )
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Remaining usage")
        .accessibilityValue("\(remainingPercent) percent")
    }
}
