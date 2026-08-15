#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
exec python3 "$script_dir/create-content-pack.py" "$@"
