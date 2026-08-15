#!/bin/bash

set -u

APP_NAME="Chengyin Companion"
INSTALL_ROOT="${CHENGYIN_INSTALL_ROOT:-$HOME/Applications}"
TARGET_APP="$INSTALL_ROOT/$APP_NAME.app"
AGENTS_PATH="${CHENGYIN_AGENTS_PATH:-$HOME/.codex/AGENTS.md}"
FAILURES=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '通过  %s\n' "$label"
  else
    printf '失败  %s\n' "$label"
    FAILURES=$((FAILURES + 1))
  fi
}

printf '澄音 Companion 诊断\n'
printf '系统：macOS %s / %s\n' "$(/usr/bin/sw_vers -productVersion)" "$(/usr/bin/uname -m)"
check "Apple Silicon" /bin/test "$(/usr/bin/uname -m)" = "arm64"
check "macOS 14+" /bin/test "$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')" -ge 14
check "应用已安装" /bin/test -d "$TARGET_APP"
check "应用主程序" /bin/test -x "$TARGET_APP/Contents/MacOS/ChengyinCompanion"
check "任务完成桥" /bin/test -x "$TARGET_APP/Contents/SharedSupport/CompanionEventEmitter"
check "应用签名封装" /usr/bin/codesign --verify --deep --strict "$TARGET_APP"
check "Codex 完成规则" /usr/bin/grep -Fq '<!-- CHENGYIN-COMPANION-BEGIN -->' "$AGENTS_PATH"

RUNNING_MATCH=0
while IFS= read -r pid; do
  RUNNING_COMMAND="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  if [[ "$RUNNING_COMMAND" == "$TARGET_APP/Contents/MacOS/ChengyinCompanion" ]]; then
    RUNNING_MATCH=1
    break
  fi
done < <(/usr/bin/pgrep -x ChengyinCompanion 2>/dev/null || true)

if [[ "$RUNNING_MATCH" -eq 1 ]]; then
  printf '通过  目标应用正在运行\n'
else
  printf '提示  应用当前未运行，可从“应用程序”中打开。\n'
fi

if /bin/test "$FAILURES" -eq 0; then
  printf '\n诊断结果：通过\n'
  exit 0
fi
printf '\n诊断结果：发现 %s 项问题，请重新运行安装器。\n' "$FAILURES"
exit 1
