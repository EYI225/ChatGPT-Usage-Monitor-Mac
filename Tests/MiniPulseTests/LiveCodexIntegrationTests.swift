import Foundation
import Testing
@testable import MiniPulse

@Suite("Live Codex integration")
struct LiveCodexIntegrationTests {
    @Test(
        "Reads the signed-in account through codex app-server",
        .enabled(if: ProcessInfo.processInfo.environment["MINI_PULSE_LIVE_TEST"] == "1")
    )
    func readsCurrentAccount() async throws {
        let snapshot = try await CodexAppServerClient().fetchUsage()

        #expect(!snapshot.windows.isEmpty)
        #expect(snapshot.windows.allSatisfy { (0...100).contains($0.remainingPercent) })
        #expect(snapshot.windows.allSatisfy { $0.durationMinutes > 0 })
    }
}
