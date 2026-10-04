# ChatGPT Usage Monitor Mac

Mini Pulse is a lightweight, native macOS utility that keeps your current Codex usage visible at a glance.

It shows three balances in a small, click-through, frosted-glass island in the lower-right corner of the screen:

- `5H` — remaining percentage in the rolling five-hour window
- `W` — remaining percentage in the weekly window
- `C` — purchased credit balance, displayed without decimals

The menu bar popover provides additional details, manual refresh, and optional low-usage notifications.

> [!IMPORTANT]
> This is an independent, unofficial project. It is not affiliated with, endorsed by, or supported by OpenAI.

## Requirements

- macOS 14 or newer
- Apple Silicon recommended
- A locally installed and signed-in Codex client
- Swift 6 when building from source

## Privacy and data source

Mini Pulse runs entirely on your Mac. It has no backend, database, analytics, or separate login.

The app launches the locally installed `codex app-server` and makes the read-only JSON-RPC request `account/rateLimits/read`. It reuses the existing Codex sign-in and does not read, copy, transmit, or store OAuth tokens.

The response provides the five-hour and weekly usage windows and, when available, the purchased credit balance. Mini Pulse identifies windows by their reported durations rather than assuming that the server's primary and secondary slots have fixed meanings.

`codex app-server` is an implementation detail that may change. If Codex stops returning compatible data, Mini Pulse shows an unavailable state instead of inventing values.

## Build and run

Clone the repository and run:

```bash
swift test
swift run MiniPulse
```

Create a local `.app` bundle:

```bash
./Scripts/bundle.sh
open "outputs/Mini Pulse.app"
```

The script creates an ad-hoc-signed build for local development at `outputs/Mini Pulse.app`. Public binary distribution should use an Apple Developer ID signature and Apple notarization.

## Current behavior

- Automatically refreshes every five minutes
- Supports manual refresh from the menu bar
- Displays a persistent, click-through floating island
- Joins all Spaces and appears alongside full-screen apps
- Uses red, orange, and green status indicators for included limits
- Shows purchased Credits as a separate blue balance
- Optionally sends a notification when remaining included usage is low

## Scope

Mini Pulse intentionally supports Codex only. It does not include multiple providers, cloud sync, accounts, analytics, or a settings database.

## License

Licensed under the [Apache License 2.0](LICENSE).

The data-source investigation referenced the Apache-2.0-licensed [Pulse](https://github.com/qunqin24/Pulse) project. No Pulse source files or assets are included; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
