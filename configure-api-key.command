#!/bin/zsh
set -euo pipefail

echo "请粘贴 OpenAI API Key。输入不会显示在屏幕上。"
read -r -s "OPENAI_KEY?API Key: "
echo

if [[ -z "$OPENAI_KEY" ]]; then
  echo "没有输入任何内容，未做修改。"
  exit 1
fi

/usr/bin/security add-generic-password \
  -U \
  -a "$USER" \
  -s "com.wordflow.openai" \
  -l "Wordflow OpenAI API Key" \
  -w "$OPENAI_KEY" >/dev/null
unset OPENAI_KEY

/bin/launchctl kickstart -k "gui/$(id -u)/com.wordflow.to-anki" 2>/dev/null || true
echo "API Key 已安全保存到 macOS 钥匙串，本地服务已重启。"
echo "可以关闭这个窗口。"
