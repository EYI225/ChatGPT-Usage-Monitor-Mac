import Foundation

struct UsageWindow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String?
    let usedPercent: Double
    let durationMinutes: Int
    let resetsAt: Date?

    var remainingPercent: Int {
        Int((100 - usedPercent).rounded()).clamped(to: 0...100)
    }

    var displayName: String {
        switch durationMinutes {
        case 300: "5-Hour Limit"
        case 10_080: "Weekly Limit"
        default: name ?? "Usage Limit"
        }
    }

    var shortName: String {
        switch durationMinutes {
        case 300: "5H"
        case 10_080: "Week"
        default: name ?? "Limit"
        }
    }
}

struct UsageSnapshot: Equatable, Sendable {
    let plan: String?
    let windows: [UsageWindow]
    let creditBalance: Decimal?
    let observedAt: Date
    let ordinaryUsageAllowed: Bool?

    func window(durationMinutes: Int) -> UsageWindow? {
        windows.first { $0.durationMinutes == durationMinutes && $0.name == nil }
            ?? windows.first { $0.durationMinutes == durationMinutes }
    }

    var fiveHour: UsageWindow? { window(durationMinutes: 300) }
    var weekly: UsageWindow? { window(durationMinutes: 10_080) }
}

enum CreditBalanceFormatter {
    static func wholeCredits(_ balance: Decimal?) -> String {
        guard var balance else { return "—" }
        var whole = Decimal()
        NSDecimalRound(&whole, &balance, 0, balance < 0 ? .up : .down)
        return NSDecimalNumber(decimal: whole).stringValue
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
