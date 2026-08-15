#!/bin/bash

set -euo pipefail

APP_NAME="Chengyin Companion"
INSTALL_ROOT="${CHENGYIN_INSTALL_ROOT:-$HOME/Applications}"
TARGET_APP="$INSTALL_ROOT/$APP_NAME.app"
AGENTS_PATH="${CHENGYIN_AGENTS_PATH:-$HOME/.codex/AGENTS.md}"
BEGIN_MARKER="<!-- CHENGYIN-COMPANION-BEGIN -->"
END_MARKER="<!-- CHENGYIN-COMPANION-END -->"
STAMP="$(/bin/date +%Y%m%d-%H%M%S)"

if /usr/bin/pgrep -x ChengyinCompanion >/dev/null 2>&1; then
  /usr/bin/osascript -e 'tell application id "local.zidong.chengyin-companion" to quit' \
    >/dev/null 2>&1 || true
fi

if /bin/test -d "$TARGET_APP"; then
  TRASH_TARGET="$HOME/.Trash/$APP_NAME-$STAMP.app"
  /bin/mv "$TARGET_APP" "$TRASH_TARGET"
  printf '应用已移到废纸篓：%s\n' "$TRASH_TARGET"
else
  printf '没有找到用户目录中的应用：%s\n' "$TARGET_APP"
fi

if /bin/test -f "$AGENTS_PATH" \
  && /usr/bin/grep -Fq "$BEGIN_MARKER" "$AGENTS_PATH"; then
  AGENTS_DIR="$(dirname "$AGENTS_PATH")"
  TEMP_PATH="$AGENTS_DIR/.chengyin-agents-uninstall-$STAMP-$$"
  /usr/bin/awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$AGENTS_PATH" > "$TEMP_PATH"
  /bin/mv "$TEMP_PATH" "$AGENTS_PATH"
  /bin/chmod 600 "$AGENTS_PATH"
  printf '已移除 Codex 中由安装器加入的澄音规则。\n'
fi

printf '偏好、关系记忆和内容包仍保留在 ~/Library/Application Support/Chengyin。\n'
printf '如需清除这些个人数据，请在确认备份后手动处理。\n'
