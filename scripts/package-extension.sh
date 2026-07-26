#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(/usr/bin/python3 -c 'import json, pathlib; print(json.loads(pathlib.Path("extension/manifest.json").read_text())["version"])' 2>/dev/null)"
OUTPUT="$ROOT/dist/wordflow-extension-$VERSION.zip"

/bin/mkdir -p "$ROOT/dist"
cd "$ROOT/extension"
COPYFILE_DISABLE=1 /usr/bin/zip -qr "$OUTPUT" . -x '*.DS_Store'
echo "$OUTPUT"
