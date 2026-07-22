#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_ROOT="${1:-$ROOT/build}"
APP="$OUTPUT_ROOT/Wordflow Quick Add.app"
CONTENTS="$APP/Contents"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "未找到 swiftc，跳过原生快速窗口。 / swiftc was not found; skipping the native quick window."
  exit 2
fi

/bin/rm -rf "$APP"
/bin/mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
/usr/bin/xcrun swiftc \
  -O \
  -parse-as-library \
  -framework AppKit \
  -framework Foundation \
  "$ROOT/WordflowQuickAdd.swift" \
  -o "$CONTENTS/MacOS/WordflowQuickAdd"
/bin/cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
/bin/cp "$ROOT/Wordflow.icns" "$CONTENTS/Resources/Wordflow.icns"
/usr/bin/touch "$APP"
echo "$APP"
