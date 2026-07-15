#!/bin/zsh
set -euo pipefail

DEST="$HOME/Library/Application Support/Wordflow"
AGENT="$HOME/Library/LaunchAgents/com.wordflow.to-anki.plist"

echo "这会移除 Wordflow 本地服务和安装文件。"
echo "不会删除 Anki 卡片，也不会自动移除浏览器扩展或钥匙串中的 API Key。"
read -r "REPLY?继续卸载？输入 y 确认："
if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
  echo "已取消。"
  exit 0
fi

/bin/launchctl bootout "gui/$(id -u)/com.wordflow.to-anki" 2>/dev/null || true
/bin/rm -f "$AGENT"
/bin/rm -rf "$DEST"

echo "Wordflow 本地服务已卸载。"
echo "如需删除 API Key，可运行：security delete-generic-password -s com.wordflow.openai"
echo "请在 Arc/Chrome 的扩展页面手动移除 Wordflow to Anki。"
read -r "?按回车关闭窗口。"

