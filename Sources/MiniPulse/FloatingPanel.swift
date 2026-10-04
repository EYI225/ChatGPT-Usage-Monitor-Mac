import AppKit
import SwiftUI

@MainActor
final class FloatingPanelPresenter {
    static let shared = FloatingPanelPresenter()

    private let panelSize = NSSize(width: 268, height: 38)
    private var panel: NSPanel?

    func show(store: UsageStore) {
        guard panel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: FloatingUsageView(store: store))

        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.maxX - panelSize.width - 18,
            y: frame.minY + 18
        )
        panel.setFrameOrigin(origin)
    }
}

struct FloatingUsageView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black.opacity(0.72))

            if let snapshot = store.snapshot {
                InlineBalance(
                    label: "5H",
                    value: snapshot.fiveHour.map { "\($0.remainingPercent)%" } ?? "—",
                    tint: limitTint(snapshot.fiveHour)
                )
                InlineBalance(
                    label: "W",
                    value: snapshot.weekly.map { "\($0.remainingPercent)%" } ?? "—",
                    tint: limitTint(snapshot.weekly)
                )
                InlineBalance(
                    label: "C",
                    value: CreditBalanceFormatter.wholeCredits(snapshot.creditBalance),
                    tint: .blue
                )
            } else if store.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
                Text("Reading Codex…")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("Codex unavailable")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 268, height: 38)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.08))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.62), lineWidth: 0.7)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.black.opacity(0.10), lineWidth: 0.5)
                        .padding(0.7)
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Codex usage")
    }

    private func limitTint(_ window: UsageWindow?) -> Color {
        guard let remaining = window?.remainingPercent else { return .gray }
        if remaining <= 20 { return .red }
        if remaining <= 40 { return .orange }
        return .green
    }
}

private struct InlineBalance: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.48))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.black.opacity(0.86))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) balance")
        .accessibilityValue(value)
    }
}
