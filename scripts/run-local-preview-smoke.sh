#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/local-preview-smoke.py"
