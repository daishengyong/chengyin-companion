#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TOOL_BINARY="$("$PROJECT_DIR/scripts/build-creator-tool.sh" validator)"
exec "$TOOL_BINARY" "$@"
