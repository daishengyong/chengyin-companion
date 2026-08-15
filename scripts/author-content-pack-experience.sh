#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
PYTHON_CHECKER="$PROJECT_DIR/scripts/check-python-runtime.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  print "Usage: ./scripts/author-content-pack-experience.sh <pack-directory> --id <id> --kind <kind> --trigger <trigger>... --step <assetID:role[:minimumPlaybackMs[:transition]]>... [options]"
  print
  print "Options: --locale <tag>... --cooldown <seconds> --weight <number>"
  print "         --return-policy <policy> --replace --check --json"
  exit 0
fi

"$PYTHON_CHECKER" >/dev/null
PYTHONDONTWRITEBYTECODE=1 exec python3 \
  "$PROJECT_DIR/scripts/apply-content-pack-experience.py" "$@"
