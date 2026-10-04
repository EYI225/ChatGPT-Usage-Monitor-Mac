import Foundation
import Testing
@testable import MiniPulse

@Suite("Usage models")
struct UsageModelsTests {
    @Test("Remaining percent is derived and clamped")
    func remainingPercent() {
        let normal = UsageWindow(
            id: "normal",
            name: nil,
            usedPercent: 22,
            durationMinutes: 300,
            resetsAt: nil
        )
        let over = UsageWindow(
            id: "over",
            name: nil,
            usedPercent: 104,
            durationMinutes: 10_080,
            resetsAt: nil
        )

        #expect(normal.remainingPercent == 78)
        #expect(over.remainingPercent == 0)
    }

    @Test("Windows are selected by duration rather than server slot")
    func durationSelection() {
        let weekly = UsageWindow(
            id: "codex.primary",
            name: nil,
            usedPercent: 4,
            durationMinutes: 10_080,
            resetsAt: Date(timeIntervalSince1970: 2_000)
        )
        let fiveHour = UsageWindow(
            id: "codex.secondary",
            name: nil,
            usedPercent: 22,
            durationMinutes: 300,
            resetsAt: Date(timeIntervalSince1970: 1_000)
        )
        let snapshot = UsageSnapshot(
            plan: "Plus",
            windows: [weekly, fiveHour],
            creditBalance: nil,
            observedAt: .now,
            ordinaryUsageAllowed: true
        )

        #expect(snapshot.fiveHour?.id == "codex.secondary")
        #expect(snapshot.weekly?.id == "codex.primary")
    }

    @Test("Credit balance omits fractional credits without overstating")
    func wholeCreditBalance() {
        #expect(CreditBalanceFormatter.wholeCredits(Decimal(string: "2480.99")) == "2480")
        #expect(CreditBalanceFormatter.wholeCredits(nil) == "—")
    }
}
