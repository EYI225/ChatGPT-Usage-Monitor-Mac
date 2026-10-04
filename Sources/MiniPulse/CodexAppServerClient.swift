import Foundation

enum CodexUsageError: LocalizedError, Equatable {
    case codexNotFound
    case launchFailed
    case timedOut
    case connectionClosed
    case server(String)
    case invalidResponse
    case noLimitsReported

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            "Codex was not found. Install or open Codex on this Mac."
        case .launchFailed:
            "Codex could not be started."
        case .timedOut:
            "Codex did not return usage data in time."
        case .connectionClosed:
            "Codex closed the usage connection."
        case .server(let message):
            "Codex reported an error: \(message)"
        case .invalidResponse:
            "Codex returned usage data in an unsupported format."
        case .noLimitsReported:
            "Codex did not report any usage limits for this account."
        }
    }
}

struct CodexAppServerClient: Sendable {
    private let locator: CodexLocator
    private let timeout: TimeInterval

    init(locator: CodexLocator = CodexLocator(), timeout: TimeInterval = 20) {
        self.locator = locator
        self.timeout = timeout
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let executable = locator.locate() else {
            throw CodexUsageError.codexNotFound
        }

        return try await Task.detached(priority: .utility) {
            try Self.fetchUsageSynchronously(executable: executable, timeout: timeout)
        }.value
    }

    private static func fetchUsageSynchronously(
        executable: URL,
        timeout: TimeInterval
    ) throws -> UsageSnapshot {
        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        let executableDirectory = executable.deletingLastPathComponent().path
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(executableDirectory):\(inheritedPath)"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw CodexUsageError.launchFailed
        }

        let processBox = ProcessBox(process)
        let timeoutItem = DispatchWorkItem {
            processBox.terminateIfRunning(markTimedOut: true)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutItem
        )

        let writer = input.fileHandleForWriting
        let reader = output.fileHandleForReading
        var lineReader = JSONLineReader(handle: reader)

        defer {
            timeoutItem.cancel()
            try? writer.close()
            try? reader.close()
            processBox.terminateIfRunning(markTimedOut: false)
            process.waitUntilExit()
        }

        try write(
            [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "mini_pulse",
                        "title": "Mini Pulse",
                        "version": "0.1.0",
                    ],
                ],
            ],
            to: writer
        )
        _ = try response(id: 1, from: &lineReader, process: processBox)

        try write(
            ["jsonrpc": "2.0", "method": "initialized", "params": [:]],
            to: writer
        )
        try write(
            [
                "jsonrpc": "2.0",
                "id": 2,
                "method": "account/rateLimits/read",
                "params": [:],
            ],
            to: writer
        )

        let result = try response(id: 2, from: &lineReader, process: processBox)
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(withJSONObject: result),
              let payload = try? JSONDecoder().decode(RateLimitsPayload.self, from: data)
        else {
            throw CodexUsageError.invalidResponse
        }

        return try payload.snapshot(observedAt: Date())
    }

    private static func write(_ object: [String: Any], to handle: FileHandle) throws {
        guard var data = try? JSONSerialization.data(withJSONObject: object) else {
            throw CodexUsageError.invalidResponse
        }
        data.append(UInt8(ascii: "\n"))

        do {
            try handle.write(contentsOf: data)
        } catch {
            throw CodexUsageError.connectionClosed
        }
    }

    private static func response(
        id: Int,
        from reader: inout JSONLineReader,
        process: ProcessBox
    ) throws -> [String: Any] {
        while let message = try reader.nextObject() {
            guard (message["id"] as? NSNumber)?.intValue == id else { continue }

            if let error = message["error"] as? [String: Any] {
                throw CodexUsageError.server(error["message"] as? String ?? "Unknown error")
            }
            guard let result = message["result"] as? [String: Any] else {
                throw CodexUsageError.invalidResponse
            }
            return result
        }

        throw process.timedOut() ? CodexUsageError.timedOut : CodexUsageError.connectionClosed
    }
}

private final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private var didTimeOut = false

    init(_ process: Process) {
        self.process = process
    }

    func terminateIfRunning(markTimedOut: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard process.isRunning else { return }
        if markTimedOut {
            didTimeOut = true
        }
        process.terminate()
    }

    func timedOut() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return didTimeOut
    }
}

private struct JSONLineReader {
    let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    mutating func nextObject() throws -> [String: Any]? {
        while true {
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                guard !line.isEmpty else { continue }
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
                else { throw CodexUsageError.invalidResponse }
                return object
            }

            let chunk = handle.availableData
            guard !chunk.isEmpty else { return nil }
            buffer.append(chunk)
        }
    }
}

private struct RateLimitsPayload: Decodable {
    let ordinaryUsageAllowed: Bool?
    let rateLimits: RateLimitGroup?
    let rateLimitsByLimitId: [String: RateLimitGroup]?

    func snapshot(observedAt: Date) throws -> UsageSnapshot {
        let groups: [(String, RateLimitGroup)]
        if let rateLimitsByLimitId, !rateLimitsByLimitId.isEmpty {
            groups = rateLimitsByLimitId.sorted { $0.key < $1.key }
        } else if let rateLimits {
            groups = [(rateLimits.limitId ?? "codex", rateLimits)]
        } else {
            throw CodexUsageError.noLimitsReported
        }

        let windows = groups.flatMap { key, group in
            [
                group.primary.map { $0.usageWindow(id: "\(key).primary", name: group.limitName) },
                group.secondary.map { $0.usageWindow(id: "\(key).secondary", name: group.limitName) },
            ].compactMap { $0 }
        }

        guard !windows.isEmpty else { throw CodexUsageError.noLimitsReported }

        return UsageSnapshot(
            plan: groups.compactMap(\.1.planType).first.map(Self.displayPlan),
            windows: windows,
            creditBalance: groups.compactMap(\.1.credits?.balance).first,
            observedAt: observedAt,
            ordinaryUsageAllowed: ordinaryUsageAllowed
        )
    }

    private static func displayPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "free": "Free"
        case "go": "Go"
        case "plus": "Plus"
        case "pro": "Pro"
        case "prolite": "Pro 5x"
        case "team": "Team"
        case "business": "Business"
        case "enterprise": "Enterprise"
        case "edu": "Edu"
        default: raw
        }
    }
}

private struct RateLimitGroup: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindowPayload?
    let secondary: RateLimitWindowPayload?
    let credits: RateLimitCreditsPayload?
    let planType: String?
}

private struct RateLimitCreditsPayload: Decodable {
    let balance: Decimal?

    private enum CodingKeys: String, CodingKey {
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .balance) {
            balance = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        } else {
            balance = try? container.decode(Decimal.self, forKey: .balance)
        }
    }
}

private struct RateLimitWindowPayload: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    func usageWindow(id: String, name: String?) -> UsageWindow {
        UsageWindow(
            id: id,
            name: name,
            usedPercent: usedPercent,
            durationMinutes: windowDurationMins ?? 0,
            resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}
