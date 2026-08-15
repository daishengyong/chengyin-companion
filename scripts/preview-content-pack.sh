#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OPEN_PREVIEW=1
OUTPUT_PATH=""
PACK_PATH=""
CLI_ARGUMENTS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-open)
      OPEN_PREVIEW=0
      shift
      ;;
    --output)
      if [[ "$#" -lt 2 ]]; then
        echo "--output requires an HTML path" >&2
        exit 2
      fi
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --app-version)
      if [[ "$#" -lt 2 ]]; then
        echo "--app-version requires a semantic version" >&2
        exit 2
      fi
      CLI_ARGUMENTS+=("--app-version" "$2")
      shift 2
      ;;
    --help|-h)
      echo "Usage: ./scripts/preview-content-pack.sh <pack-directory> [--output preview.html] [--no-open] [--app-version x.y.z]"
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -n "$PACK_PATH" ]]; then
        echo "Only one pack directory may be previewed at a time" >&2
        exit 2
      fi
      PACK_PATH="$1"
      shift
      ;;
  esac
done

if [[ -z "$PACK_PATH" ]]; then
  echo "A pack directory is required" >&2
  exit 2
fi
if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$(mktemp "${TMPDIR:-/tmp}/Chengyin-Pack-Preview.XXXXXX.html")"
fi

TOOL_BINARY="$("$PROJECT_DIR/scripts/build-creator-tool.sh" preview)"

"$TOOL_BINARY" \
  "$PACK_PATH" \
  --output "$OUTPUT_PATH" \
  "${CLI_ARGUMENTS[@]}"

if [[ "$OPEN_PREVIEW" -eq 1 ]]; then
  open "$OUTPUT_PATH"
fi
