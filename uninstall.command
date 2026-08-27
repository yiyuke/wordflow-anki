#!/bin/zsh
set -euo pipefail

DEST="$HOME/Library/Application Support/Wordflow"
AGENT="$HOME/Library/LaunchAgents/com.wordflow.to-anki.plist"
QUICK_AGENT="$HOME/Library/LaunchAgents/com.wordflow.quick-add.plist"

IS_ZH=0
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
  zh*) IS_ZH=1 ;;
esac
say() {
  if (( IS_ZH )); then print -r -- "$1"; else print -r -- "$2"; fi
}

say "这会移除 Wordflow 本地服务和安装文件。" \
    "This removes Wordflow's local service and installed files."
say "不会删除 Anki 卡片，也不会自动移除浏览器扩展或钥匙串中的 API Key。" \
    "It will not delete Anki cards, remove the browser extension, or erase your Keychain API key."
CONFIRM_PROMPT="$(say "继续卸载？输入 y 确认：" "Continue? Type y to uninstall: ")"
read -r "REPLY?$CONFIRM_PROMPT"
if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
  say "已取消。" "Cancelled."
  exit 0
fi

/bin/launchctl bootout "gui/$(id -u)/com.wordflow.to-anki" 2>/dev/null || true
/bin/launchctl bootout "gui/$(id -u)/com.wordflow.quick-add" 2>/dev/null || true
/bin/rm -f "$AGENT" "$QUICK_AGENT"
/bin/rm -rf "$DEST"

say "Wordflow 本地服务已卸载。" "Wordflow's local service has been removed."
say "如需删除 API Key，可运行：security delete-generic-password -s com.wordflow.openai" \
    "To delete the API key too, run: security delete-generic-password -s com.wordflow.openai"
say "请在 Arc/Chrome 的扩展页面手动移除 Wordflow to Anki。" \
    "Remove Wordflow to Anki manually from the Arc/Chrome extensions page."
CLOSE_PROMPT="$(say "按回车关闭窗口。" "Press Return to close this window.")"
read -r "?$CLOSE_PROMPT"
