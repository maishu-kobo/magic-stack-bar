#!/bin/bash
# SwiftPM の実行バイナリを MagicStackBar.app バンドルに組み立てて zip 化する。
# 使い方: ./scripts/build-app.sh <version>
set -euo pipefail

VERSION="${1:?usage: build-app.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/MagicStackBar.app"

cd "$ROOT"
swift build -c release

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$(swift build -c release --show-bin-path)/MagicStackBar" "$APP/Contents/MacOS/MagicStackBar"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MagicStackBar</string>
  <key>CFBundleIdentifier</key>
  <string>jp.maishu-kobo.magic-stack-bar</string>
  <key>CFBundleName</key>
  <string>MagicStackBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>カレンダーの予定から空き日を計算して、日程調整リポジトリに公開するために使用します。</string>
</dict>
</plist>
PLIST

# アドホック署名（Developer ID なし。初回起動は右クリック > 開く が必要）
codesign --force --deep --sign - "$APP"

cd "$DIST"
zip -qry "MagicStackBar-${VERSION}.zip" MagicStackBar.app
shasum -a 256 "MagicStackBar-${VERSION}.zip"
