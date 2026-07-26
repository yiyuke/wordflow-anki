#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required to run Wordflow review mode."
  exit 1
fi

if /usr/bin/curl -fsS --max-time 1 http://127.0.0.1:8766/health >/dev/null 2>&1; then
  echo "Port 8766 is already being used by a Wordflow service."
  echo "Stop that service before starting the isolated Chrome Web Store review mode."
  exit 1
fi

export SERVER_HOST=127.0.0.1
export SERVER_PORT=8766
export MOCK_OPENAI=1
export MOCK_ANKI=1
export ENABLE_TTS=0
export WORDFLOW_CARD_LANGUAGE=en

echo "Wordflow Chrome Web Store review mode"
echo "No OpenAI account, API key, Anki installation, or network request is used."
echo "Keep this window open while testing the extension. Press Control-C to stop."
echo

cd "$ROOT/local_service"
exec python3 server.py
