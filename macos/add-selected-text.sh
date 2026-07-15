#!/bin/zsh
# Intended for an Automator/Shortcuts “Run Shell Script” action with input passed to stdin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/env python3 "$ROOT/local_service/clipboard_capture.py" --source-title "macOS selected text"
