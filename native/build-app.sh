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
  -framework Carbon \
  -framework Foundation \
  "$ROOT/WordflowQuickAdd.swift" \
  -o "$CONTENTS/MacOS/WordflowQuickAdd"
/bin/cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
# Do not propagate Finder/provenance metadata into the installed app bundle;
# macOS can reject that extended attribute inside Application Support.
/bin/cp -X "$ROOT/Wordflow.icns" "$CONTENTS/Resources/Wordflow.icns"
if [[ -d "$ROOT/Assets.xcassets" ]] && /usr/bin/xcrun --find actool >/dev/null 2>&1; then
  /usr/bin/xcrun actool "$ROOT/Assets.xcassets" \
    --compile "$CONTENTS/Resources" \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --output-format human-readable-text \
    --warnings \
    --notices >/dev/null
elif [[ -d "$ROOT/Assets.xcassets" ]]; then
  echo "未找到 actool，跳过可选的资源目录编译。 / actool was not found; skipping optional asset catalog compilation."
fi
/usr/bin/touch "$APP"
echo "$APP"
