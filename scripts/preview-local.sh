#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
exec python3 "$SCRIPT_DIR/local-preview.py" "$@"
