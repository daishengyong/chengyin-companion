#!/bin/bash

set -euo pipefail

APP_NAME="Chengyin Companion"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/$APP_NAME.app"
INSTALL_ROOT="${CHENGYIN_INSTALL_ROOT:-$HOME/Applications}"
TARGET_APP="$INSTALL_ROOT/$APP_NAME.app"
SUPPORT_ROOT="${CHENGYIN_SUPPORT_ROOT:-$HOME/Library/Application Support/Chengyin}"
BACKUP_ROOT="$SUPPORT_ROOT/install-backups"
AGENTS_PATH="${CHENGYIN_AGENTS_PATH:-$HOME/.codex/AGENTS.md}"
BEGIN_MARKER="<!-- CHENGYIN-COMPANION-BEGIN -->"
END_MARKER="<!-- CHENGYIN-COMPANION-END -->"

fail() {
  printf '\n安装未完成：%s\n' "$1" >&2
  printf '没有修改 Codex 的 config.toml。\n' >&2
  exit 1
}

major_version() {
  /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}'
}

validate_app() {
  local app_path="$1"
  /bin/test -d "$app_path" || return 1
  /bin/test -x "$app_path/Contents/MacOS/ChengyinCompanion" || return 1
  /bin/test -x "$app_path/Contents/SharedSupport/CompanionEventEmitter" || return 1
  /usr/bin/codesign --verify --deep --strict "$app_path" >/dev/null 2>&1
}

write_codex_rule() {
  local agents_dir
  local stripped
  local backup_path
  agents_dir="$(dirname "$AGENTS_PATH")"
  /bin/mkdir -p "$agents_dir"
  /usr/bin/touch "$AGENTS_PATH"

  backup_path="$AGENTS_PATH.chengyin-backup-$STAMP"
  /bin/cp -p "$AGENTS_PATH" "$backup_path"
  stripped="$agents_dir/.chengyin-agents-$STAMP-$$"
  /usr/bin/awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$AGENTS_PATH" > "$stripped"
  /bin/mv "$stripped" "$AGENTS_PATH"

  if /bin/test -s "$AGENTS_PATH"; then
    printf '\n' >> "$AGENTS_PATH"
  fi
  cat >> "$AGENTS_PATH" <<'RULE'
<!-- CHENGYIN-COMPANION-BEGIN -->
# Chengyin Companion completion event

When you are the primary Codex agent and the user's concrete implementation
objective is genuinely complete, emit exactly one local Chengyin completion
event immediately before the final response, after required checks pass and
any requested local installation is verified:

```bash
for helper in \
  "$HOME/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" \
  "/Applications/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter"; do
  if [ -x "$helper" ]; then
    "$helper" task.completed
    break
  fi
done
```

Do not emit `task.completed` from a subagent, smoke test, preview, dry-run,
planning step, progress update, ordinary question or review, partial result,
failed/blocked task, or merely because an agent turn ended. Validation must
set `CHENGYIN_EVENT_ROOT` to a temporary directory and must never write a
simulated completion into the live event directory.
<!-- CHENGYIN-COMPANION-END -->
RULE
  /bin/chmod 600 "$AGENTS_PATH"
}

printf '正在检查安装环境…\n'
/bin/test "$(/usr/bin/uname -m)" = "arm64" \
  || fail "当前安装包只支持 Apple Silicon（M1/M2/M3/M4）。"
/bin/test "$(major_version)" -ge 14 \
  || fail "需要 macOS 14 或更高版本。"
validate_app "$SOURCE_APP" \
  || fail "安装包中的应用缺失或签名校验失败。请重新下载完整安装包。"

STAMP="$(/bin/date +%Y%m%d-%H%M%S)"
/bin/mkdir -p "$INSTALL_ROOT" "$BACKUP_ROOT"
STAGING_ROOT="$(/usr/bin/mktemp -d "$INSTALL_ROOT/.chengyin-portable.XXXXXX")"
STAGED_APP="$STAGING_ROOT/$APP_NAME.app"

cleanup() {
  if [[ "$STAGING_ROOT" == "$INSTALL_ROOT"/.chengyin-portable.* \
    && -d "$STAGING_ROOT" ]]; then
    /bin/rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

/usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"
validate_app "$STAGED_APP" || fail "复制后的应用校验失败。"

if [[ "${CHENGYIN_INSTALL_SKIP_PROCESS_CONTROL:-0}" != "1" ]] \
  && /usr/bin/pgrep -x ChengyinCompanion >/dev/null 2>&1; then
  /usr/bin/osascript -e 'tell application id "local.zidong.chengyin-companion" to quit' \
    >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    /usr/bin/pgrep -x ChengyinCompanion >/dev/null 2>&1 || break
    /bin/sleep 0.2
  done
fi

PREVIOUS_APP=""
if /bin/test -d "$TARGET_APP"; then
  PREVIOUS_APP="$BACKUP_ROOT/$APP_NAME-$STAMP.app"
  /bin/mv "$TARGET_APP" "$PREVIOUS_APP"
fi
/bin/mv "$STAGED_APP" "$TARGET_APP"
if ! validate_app "$TARGET_APP"; then
  FAILED_APP="$BACKUP_ROOT/$APP_NAME-failed-$STAMP.app"
  /bin/mv "$TARGET_APP" "$FAILED_APP" || true
  if [[ -n "$PREVIOUS_APP" && -d "$PREVIOUS_APP" ]]; then
    /bin/mv "$PREVIOUS_APP" "$TARGET_APP" || true
  fi
  fail "安装后的应用校验失败，已尝试恢复旧版本。"
fi

write_codex_rule

if [[ "${CHENGYIN_INSTALL_SKIP_LAUNCH:-0}" != "1" ]]; then
  /usr/bin/open -n "$TARGET_APP"
fi

printf '\n安装成功。\n'
printf '应用：%s\n' "$TARGET_APP"
printf 'Codex 规则：%s\n' "$AGENTS_PATH"
printf '旧版本备份：%s\n' "$BACKUP_ROOT"
printf '现有 ~/.codex/config.toml 没有被修改。\n'
printf '\n若 macOS 阻止首次打开，请在“系统设置 → 隐私与安全性”中选择“仍要打开”。\n'
