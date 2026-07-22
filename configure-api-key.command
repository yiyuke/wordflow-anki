#!/bin/zsh
set -euo pipefail

IS_ZH=0
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
  zh*) IS_ZH=1 ;;
esac
say() {
  if (( IS_ZH )); then print -r -- "$1"; else print -r -- "$2"; fi
}

say "请粘贴 OpenAI API Key。输入不会显示在屏幕上。" \
    "Paste your OpenAI API key. It will not be shown on screen."
KEY_PROMPT="$(say "API Key：" "API key: ")"
read -r -s "OPENAI_KEY?$KEY_PROMPT"
echo

if [[ -z "$OPENAI_KEY" ]]; then
  say "没有输入任何内容，未做修改。" "Nothing was entered, so no changes were made."
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
say "API Key 已安全保存到 macOS 钥匙串，本地服务已重启。" \
    "Your API key is safely stored in macOS Keychain, and the local service has restarted."
say "可以关闭这个窗口。" "You can close this window."
