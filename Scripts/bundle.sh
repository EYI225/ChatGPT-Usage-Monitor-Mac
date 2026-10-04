#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$project_root/outputs/Mini Pulse.app"
contents_path="$app_path/Contents"

cd "$project_root"
swift build -c release --product MiniPulse

mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
cp ".build/release/MiniPulse" "$contents_path/MacOS/MiniPulse"
cp "App/Info.plist" "$contents_path/Info.plist"
chmod 755 "$contents_path/MacOS/MiniPulse"

codesign --force --sign - "$app_path"
echo "$app_path"
