import Foundation

struct CodexLocator: Sendable {
    func locate() -> URL? {
        candidates().first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func candidates(
        home: String = NSHomeDirectory(),
        path: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> [URL] {
        var paths = (path ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appending(path: "codex") }

        paths += [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex",
        ].map(URL.init(fileURLWithPath:))

        var seen = Set<String>()
        return paths.filter { seen.insert($0.path).inserted }
    }
}
