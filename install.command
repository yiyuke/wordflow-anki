#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/Wordflow"
LOG_DIR="$HOME/Library/Logs/Wordflow"
AGENT="$HOME/Library/LaunchAgents/com.wordflow.to-anki.plist"
TEMPLATE="$ROOT/macos/com.wordflow.to-anki.plist"

if ! command -v python3 >/dev/null 2>&1; then
  echo "没有找到 Python 3。请先从 https://www.python.org/downloads/macos/ 安装，然后重新运行。"
  read -r "?按回车关闭窗口。"
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
  echo "提示：未找到 Swift 编译器，将使用浏览器备用窗口。"
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
echo "Wordflow 本地服务安装完成。"
echo "扩展目录：$DEST/extension"
echo
echo "接下来："
echo "1. 双击 $DEST/configure-api-key.command，保存 OpenAI API Key。"
echo "2. 在 Arc/Chrome 的扩展页面选择 Load unpacked / 加载已解压的扩展程序。"
echo "3. 选择上面的 extension 目录。"
echo
/usr/bin/open "$DEST"
read -r "?按回车关闭窗口。"
