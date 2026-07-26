#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/Wordflow"
LOG_DIR="$HOME/Library/Logs/Wordflow"
AGENT="$HOME/Library/LaunchAgents/com.wordflow.to-anki.plist"
TEMPLATE="$ROOT/macos/com.wordflow.to-anki.plist"

IS_ZH=0
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
  zh*) IS_ZH=1 ;;
esac
say() {
  if (( IS_ZH )); then print -r -- "$1"; else print -r -- "$2"; fi
}

if ! command -v python3 >/dev/null 2>&1; then
  say "没有找到 Python 3。请先从 https://www.python.org/downloads/macos/ 安装，然后重新运行。" \
      "Python 3 was not found. Install it from https://www.python.org/downloads/macos/ and run this installer again."
  CLOSE_PROMPT="$(say "按回车关闭窗口。" "Press Return to close this window.")"
  read -r "?$CLOSE_PROMPT"
  exit 1
fi

PYTHON="$(command -v python3)"
mkdir -p "$DEST" "$LOG_DIR" "$(dirname "$AGENT")"

/usr/bin/ditto "$ROOT/local_service" "$DEST/local_service"
/usr/bin/ditto "$ROOT/extension" "$DEST/extension"
/usr/bin/ditto "$ROOT/macos" "$DEST/macos"
/usr/bin/ditto "$ROOT/native" "$DEST/native"
/bin/cp "$ROOT/configure-api-key.command" "$DEST/configure-api-key.command"

if command -v swiftc >/dev/null 2>&1; then
  /usr/bin/killall WordflowQuickAdd 2>/dev/null || true
  "$ROOT/native/build-app.sh" "$DEST" >/dev/null
else
  say "提示：未找到 Swift 编译器，将使用浏览器备用窗口。" \
      "Note: Swift was not found, so Wordflow will use the browser fallback window."
fi

if [[ ! -f "$DEST/.env" ]]; then
  /bin/cp "$ROOT/.env.example" "$DEST/.env"
fi

escape_sed() {
  print -r -- "$1" | /usr/bin/sed 's/[&|]/\\&/g'
}

PYTHON_ESCAPED="$(escape_sed "$PYTHON")"
SERVICE_ESCAPED="$(escape_sed "$DEST/local_service/server.py")"
WORKDIR_ESCAPED="$(escape_sed "$DEST/local_service")"
LOG_OUT_ESCAPED="$(escape_sed "$LOG_DIR/service.log")"
LOG_ERR_ESCAPED="$(escape_sed "$LOG_DIR/service-error.log")"

/usr/bin/sed \
  -e "s|__PYTHON__|$PYTHON_ESCAPED|g" \
  -e "s|__SERVICE__|$SERVICE_ESCAPED|g" \
  -e "s|__WORKDIR__|$WORKDIR_ESCAPED|g" \
  -e "s|__LOG_OUT__|$LOG_OUT_ESCAPED|g" \
  -e "s|__LOG_ERR__|$LOG_ERR_ESCAPED|g" \
  "$TEMPLATE" > "$AGENT"

/bin/launchctl bootout "gui/$(id -u)/com.wordflow.to-anki" 2>/dev/null || true
/bin/launchctl bootstrap "gui/$(id -u)" "$AGENT"
/bin/launchctl kickstart -k "gui/$(id -u)/com.wordflow.to-anki"

echo
say "Wordflow 本地服务安装完成。" "Wordflow's local service is installed."
say "扩展目录：$DEST/extension" "Extension folder: $DEST/extension"
echo
say "接下来：" "Next steps:"
say "1. 双击 $DEST/configure-api-key.command，保存 OpenAI API Key。" \
    "1. Double-click $DEST/configure-api-key.command to save your OpenAI API key."
say "2. 在 Arc/Chrome 的扩展页面选择 Load unpacked / 加载已解压的扩展程序。" \
    "2. Open the Arc/Chrome extensions page and choose Load unpacked."
say "3. 选择上面的 extension 目录。" "3. Select the extension folder shown above."
echo
/usr/bin/open "$DEST"
CLOSE_PROMPT="$(say "按回车关闭窗口。" "Press Return to close this window.")"
read -r "?$CLOSE_PROMPT"
