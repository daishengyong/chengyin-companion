#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OPEN_EDITOR=1
OUTPUT_PATH=""
PACK_PATH=""
CLI_ARGUMENTS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --no-open)
      OPEN_EDITOR=0
      shift
      ;;
    --output|--asset|--app-version)
      if [[ "$#" -lt 2 ]]; then
        print -u2 "$1 requires a value"
        exit 2
      fi
      if [[ "$1" == "--output" ]]; then
        OUTPUT_PATH="$2"
      else
        CLI_ARGUMENTS+=("$1" "$2")
      fi
      shift 2
      ;;
    --help|-h)
      print "Usage: ./scripts/edit-content-pack-projection.sh <pack-directory> [--asset id] [--output editor.html] [--no-open] [--app-version x.y.z]"
      exit 0
      ;;
    --*)
      print -u2 "Unknown option: $1"
      exit 2
      ;;
    *)
      if [[ -n "$PACK_PATH" ]]; then
        print -u2 "Only one pack directory may be edited at a time"
        exit 2
      fi
      PACK_PATH="$1"
      shift
      ;;
  esac
done

if [[ -z "$PACK_PATH" ]]; then
  print -u2 "A pack directory is required"
  exit 2
fi
if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$(mktemp "${TMPDIR:-/tmp}/Chengyin-Projection-Editor.XXXXXX.html")"
fi

TOOL_BINARY="$("$PROJECT_DIR/scripts/build-creator-tool.sh" projection-editor)"
"$TOOL_BINARY" "$PACK_PATH" --output "$OUTPUT_PATH" "${CLI_ARGUMENTS[@]}"

if [[ "$OPEN_EDITOR" -eq 1 ]]; then
  open "$OUTPUT_PATH"
fi
