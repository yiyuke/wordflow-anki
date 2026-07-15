#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/env python3 "$ROOT/local_service/clipboard_capture.py"
