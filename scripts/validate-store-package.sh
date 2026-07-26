#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$("$ROOT/scripts/package-extension.sh")"
TEMP_DIR="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$TEMP_DIR"' EXIT

/usr/bin/unzip -q "$ARCHIVE" -d "$TEMP_DIR"

test -f "$TEMP_DIR/manifest.json"
test ! -e "$TEMP_DIR/content.js"
test ! -e "$TEMP_DIR/.env"
test ! -e "$TEMP_DIR/.DS_Store"

/usr/bin/python3 -m json.tool "$TEMP_DIR/manifest.json" >/dev/null

if /usr/bin/grep -R -E 'sk-[A-Za-z0-9_-]{20,}' "$TEMP_DIR" >/dev/null 2>&1; then
  echo "Possible API key found in the extension package."
  exit 1
fi

VERSION="$(/usr/bin/python3 -c 'import json, pathlib, sys; print(json.loads(pathlib.Path(sys.argv[1]).read_text())["version"])' "$TEMP_DIR/manifest.json")"
FILE_COUNT="$(/usr/bin/find "$TEMP_DIR" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

echo "Validated Chrome Web Store package: $ARCHIVE"
echo "Version: $VERSION | Files: $FILE_COUNT"
