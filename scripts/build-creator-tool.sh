#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CACHE_PROTOCOL="chengyin.creator-tool-cache/v2"
MANIFEST_SCHEMA="chengyin.creator-tool-cache-manifest/v1"

fail() {
  local code="$1"
  local message="$2"
  local action="$3"
  print -u2 "FAIL  [$code] $message"
  print -u2 "ACTION  $action"
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  fail \
    "CREATOR_TOOL_BUILD_ARGUMENTS" \
    "Exactly one creator tool identifier is required." \
    "Use validator, audit, archive-audit, preview, projection-editor, migration or locale-matrix, then retry the original creator command."
fi

TOOL_ID="$1"
TOOL_SOURCES=()
CONTENT_PACK_CORE_SOURCES=(
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackManifest.swift"
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFailureReceipt.swift"
  "$PROJECT_DIR/Sources/CompanionApp/SemanticVersion.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackTriggerContract.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackManifestFieldValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackContributionValidationSupport.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackRightsValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAccessibilityValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackFallbackValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackContributionValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackPackageContentsValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetFileValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetValidator.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPack.swift"
)
CONTENT_PACK_MEDIA_SOURCES=(
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackVideoMediaProbe.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackMediaProbe.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift"
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackMediaQualityProbe.swift"
  "$PROJECT_DIR/scripts/content-pack-creator-media-fallback.swift"
)
case "$TOOL_ID" in
  validator)
    TOOL_BINARY_NAME="chengyin-pack-validate"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "${CONTENT_PACK_MEDIA_SOURCES[@]}"
      "$PROJECT_DIR/scripts/content-pack-validator-cli.swift"
    )
    ;;
  audit)
    TOOL_BINARY_NAME="chengyin-pack-audit"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "${CONTENT_PACK_MEDIA_SOURCES[@]}"
      "$PROJECT_DIR/scripts/content-pack-audit-cli.swift"
    )
    ;;
  archive-audit)
    TOOL_BINARY_NAME="chengyin-pack-archive-audit"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "$PROJECT_DIR/Sources/CompanionApp/ContentPackArchivePolicy.swift"
      "$PROJECT_DIR/Sources/CompanionApp/ContentPackArchiveImporter.swift"
      "${CONTENT_PACK_MEDIA_SOURCES[@]}"
      "$PROJECT_DIR/scripts/content-pack-archive-audit-cli.swift"
    )
    ;;
  preview)
    TOOL_BINARY_NAME="chengyin-pack-preview"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "${CONTENT_PACK_MEDIA_SOURCES[@]}"
      "$PROJECT_DIR/Sources/CompanionApp/ContentPackProjectionPreview.swift"
      "$PROJECT_DIR/scripts/content-pack-preview-cli.swift"
    )
    ;;
  projection-editor)
    TOOL_BINARY_NAME="chengyin-pack-projection-editor"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionProjectionAuthoring.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "${CONTENT_PACK_MEDIA_SOURCES[@]}"
      "$PROJECT_DIR/Sources/CompanionApp/ContentPackProjectionPreview.swift"
      "$PROJECT_DIR/Sources/CompanionApp/ContentPackProjectionEditor.swift"
      "$PROJECT_DIR/scripts/content-pack-projection-editor-cli.swift"
    )
    ;;
  migration)
    TOOL_BINARY_NAME="chengyin-pack-migration"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "$PROJECT_DIR/scripts/content-pack-migration-cli.swift"
    )
    ;;
  locale-matrix)
    TOOL_BINARY_NAME="chengyin-pack-locale-matrix"
    TOOL_SOURCES=(
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift"
      "$PROJECT_DIR/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift"
      "${CONTENT_PACK_CORE_SOURCES[@]}"
      "$PROJECT_DIR/scripts/content-pack-locale-matrix-cli.swift"
    )
    ;;
  *)
    fail \
      "CREATOR_TOOL_BUILD_UNKNOWN_TOOL" \
      "The requested creator tool identifier is not supported." \
      "Use validator, audit, archive-audit, preview, projection-editor, migration or locale-matrix, then retry the original creator command."
    ;;
esac

SOURCE_FILES=(
  "$PROJECT_DIR/scripts/build-creator-tool.sh"
  "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
  "${TOOL_SOURCES[@]}"
)
for source_file in "${SOURCE_FILES[@]}"; do
  if [[ ! -f "$source_file" || -L "$source_file" ]]; then
    fail \
      "CREATOR_TOOL_BUILD_COMPILATION_FAILED" \
      "A required creator-tool source is unavailable or unsafe." \
      "Restore a complete repository checkout, run scripts/doctor.sh, then retry."
  fi
done

source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

CACHE_ROOT="${CHENGYIN_CREATOR_CACHE_ROOT:-$PROJECT_DIR/.build/creator-tools}"
if [[ -L "$CACHE_ROOT" ]]; then
  fail \
    "CREATOR_TOOL_BUILD_CACHE_INVALID" \
    "The creator-tool cache root is a symbolic link and was not trusted." \
    "Move the cache aside, recreate it as a regular local directory, then retry."
fi
mkdir -p "$CACHE_ROOT"
if [[ ! -d "$CACHE_ROOT" || -L "$CACHE_ROOT" ]]; then
  fail \
    "CREATOR_TOOL_BUILD_CACHE_INVALID" \
    "The creator-tool cache root is not a regular local directory." \
    "Move the cache aside, recreate it as a regular local directory, then retry."
fi

sha256_text() {
  print -rn -- "$1" | shasum -a 256 | awk '{ print $1 }'
}

COMPILER_IDENTITY="$(xcrun swiftc --version 2>&1)"
SWIFTC_LOCATION="$(xcrun -f swiftc 2>/dev/null || print -r -- unavailable-swiftc)"
COMPILER_IDENTITY_SHA256="$(sha256_text "$COMPILER_IDENTITY
$SWIFTC_LOCATION")"

SDK_LOCATION="${SDKROOT:-unknown-sdk}"
if [[ -d "$SDK_LOCATION" ]]; then
  SDK_LOCATION="$(cd "$SDK_LOCATION" && pwd -P)"
fi
SDK_SETTINGS_SHA256="missing-sdk-settings"
if [[ -f "${SDKROOT:-}/SDKSettings.json" && ! -L "${SDKROOT:-}/SDKSettings.json" ]]; then
  SDK_SETTINGS_SHA256="$(shasum -a 256 "${SDKROOT}/SDKSettings.json" | awk '{ print $1 }')"
fi
SDK_IDENTITY_SHA256="$(sha256_text "$SDK_LOCATION
$SDK_SETTINGS_SHA256")"
NAMESPACE_IDENTITY_SHA256="$(sha256_text "${CHENGYIN_CREATOR_CACHE_NAMESPACE:-default}")"

SOURCE_RELATIVE_PATHS=()
SOURCE_DIGESTS=()
for source_file in "${SOURCE_FILES[@]}"; do
  SOURCE_RELATIVE_PATHS+=("${source_file#$PROJECT_DIR/}")
  SOURCE_DIGESTS+=("$(shasum -a 256 "$source_file" | awk '{ print $1 }')")
done

SOURCE_DIGEST_SET_SHA256="$({
  for (( index = 1; index <= ${#SOURCE_RELATIVE_PATHS[@]}; index++ )); do
    print -r -- "${SOURCE_RELATIVE_PATHS[$index]}"
    print -r -- "${SOURCE_DIGESTS[$index]}"
  done
} | shasum -a 256 | awk '{ print $1 }')"

FINGERPRINT="$({
  print -r -- "$CACHE_PROTOCOL"
  print -r -- "$TOOL_ID"
  print -r -- "$TOOL_BINARY_NAME"
  print -r -- "$NAMESPACE_IDENTITY_SHA256"
  print -r -- "$COMPILER_IDENTITY_SHA256"
  print -r -- "$SDK_IDENTITY_SHA256"
  print -r -- "$SOURCE_DIGEST_SET_SHA256"
} | shasum -a 256 | awk '{ print $1 }')"

TOOL_PARENT_DIR="$CACHE_ROOT/$TOOL_ID"
if [[ -L "$TOOL_PARENT_DIR" ]]; then
  fail \
    "CREATOR_TOOL_BUILD_CACHE_INVALID" \
    "The creator-tool cache namespace is a symbolic link and was not trusted." \
    "Move the cache aside, recreate it as a regular local directory, then retry."
fi
mkdir -p "$TOOL_PARENT_DIR"
if [[ ! -d "$TOOL_PARENT_DIR" || -L "$TOOL_PARENT_DIR" ]]; then
  fail \
    "CREATOR_TOOL_BUILD_CACHE_INVALID" \
    "The creator-tool cache namespace is not a regular local directory." \
    "Move the cache aside, recreate it as a regular local directory, then retry."
fi

TOOL_CACHE_DIR="$TOOL_PARENT_DIR/$FINGERPRINT"
CACHED_BINARY="$TOOL_CACHE_DIR/$TOOL_BINARY_NAME"
CACHED_MANIFEST="$TOOL_CACHE_DIR/manifest.json"
WORK_DIR="$(mktemp -d "$CACHE_ROOT/.work.$TOOL_ID.XXXXXX")"
STAGED_BINARY="$WORK_DIR/$TOOL_BINARY_NAME"
STAGED_MANIFEST="$WORK_DIR/manifest.json"
EXPECTED_MANIFEST="$WORK_DIR/expected-manifest.json"
COMPILE_LOG="$WORK_DIR/compile.log"

cleanup() {
  if [[ -n "${WORK_DIR:-}" \
    && "$WORK_DIR" == "$CACHE_ROOT"/.work.* \
    && -d "$WORK_DIR" ]]; then
    /bin/rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT INT TERM

trace_cache() {
  if [[ "${CHENGYIN_CREATOR_BUILD_TRACE:-0}" == "1" ]]; then
    print -u2 "CREATOR_TOOL_CACHE $1 $TOOL_ID $FINGERPRINT"
  fi
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  print -rn -- "$value"
}

write_manifest() {
  local destination="$1"
  local binary_sha256="$2"
  local index
  local comma
  {
    print -r -- "{"
    print -r -- "  \"schemaVersion\": \"$MANIFEST_SCHEMA\","
    print -r -- "  \"toolID\": \"$TOOL_ID\","
    print -r -- "  \"fingerprint\": \"$FINGERPRINT\","
    print -r -- "  \"binaryName\": \"$TOOL_BINARY_NAME\","
    print -r -- "  \"binarySHA256\": \"$binary_sha256\","
    print -r -- "  \"compilerIdentitySHA256\": \"$COMPILER_IDENTITY_SHA256\","
    print -r -- "  \"sdkIdentitySHA256\": \"$SDK_IDENTITY_SHA256\","
    print -r -- "  \"cacheNamespaceSHA256\": \"$NAMESPACE_IDENTITY_SHA256\","
    print -r -- "  \"sourceDigestSetSHA256\": \"$SOURCE_DIGEST_SET_SHA256\","
    print -r -- "  \"sourceDigests\": ["
    for (( index = 1; index <= ${#SOURCE_RELATIVE_PATHS[@]}; index++ )); do
      comma=","
      if (( index == ${#SOURCE_RELATIVE_PATHS[@]} )); then
        comma=""
      fi
      printf '    {"path": "%s", "sha256": "%s"}%s\n' \
        "$(json_escape "${SOURCE_RELATIVE_PATHS[$index]}")" \
        "${SOURCE_DIGESTS[$index]}" \
        "$comma"
    done
    print -r -- "  ]"
    print -r -- "}"
  } > "$destination"
}

validate_cached_unit() {
  local cached_sha256
  [[ -d "$TOOL_CACHE_DIR" && ! -L "$TOOL_CACHE_DIR" ]] || return 1
  [[ -f "$CACHED_BINARY" && ! -L "$CACHED_BINARY" && -x "$CACHED_BINARY" ]] || return 1
  [[ -f "$CACHED_MANIFEST" && ! -L "$CACHED_MANIFEST" ]] || return 1
  cached_sha256="$(shasum -a 256 "$CACHED_BINARY" 2>/dev/null | awk '{ print $1 }')" || return 1
  [[ -n "$cached_sha256" ]] || return 1
  write_manifest "$EXPECTED_MANIFEST" "$cached_sha256" || return 1
  cmp -s "$EXPECTED_MANIFEST" "$CACHED_MANIFEST"
}

await_published_unit() {
  local attempt
  for (( attempt = 1; attempt <= 40; attempt++ )); do
    if [[ -L "$TOOL_CACHE_DIR" \
      || -L "$CACHED_BINARY" \
      || -L "$CACHED_MANIFEST" ]]; then
      return 1
    fi
    if [[ -f "$CACHED_BINARY" && -f "$CACHED_MANIFEST" ]]; then
      validate_cached_unit
      return $?
    fi
    sleep 0.05
  done
  return 1
}

cache_invalid() {
  fail \
    "CREATOR_TOOL_BUILD_CACHE_INVALID" \
    "The cached creator tool or its integrity manifest is incomplete or does not match." \
    "Move the affected creator-tool cache aside, rerun the command to rebuild it locally, then retry."
}

if [[ -e "$TOOL_CACHE_DIR" || -L "$TOOL_CACHE_DIR" ]]; then
  if await_published_unit; then
    trace_cache "HIT"
    print -r -- "$CACHED_BINARY"
    exit 0
  fi
  cache_invalid
fi

trace_cache "MISS"
if ! xcrun swiftc "${TOOL_SOURCES[@]}" -o "$STAGED_BINARY" \
  >"$COMPILE_LOG" 2>&1; then
  fail \
    "CREATOR_TOOL_BUILD_COMPILATION_FAILED" \
    "The local creator tool could not be compiled." \
    "Run scripts/doctor.sh to repair the Swift toolchain, then retry; no pack files were changed."
fi
chmod 755 "$STAGED_BINARY"
STAGED_BINARY_SHA256="$(shasum -a 256 "$STAGED_BINARY" | awk '{ print $1 }')"
write_manifest "$STAGED_MANIFEST" "$STAGED_BINARY_SHA256"
chmod 444 "$STAGED_MANIFEST"

# The manifest is the commit marker: the fully compiled binary is linked first,
# then the complete manifest is linked last. A concurrent process either wins
# the directory creation or waits for and verifies the winner's complete unit.
if mkdir "$TOOL_CACHE_DIR" 2>/dev/null; then
  if ! /bin/ln "$STAGED_BINARY" "$CACHED_BINARY" 2>/dev/null \
    || ! /bin/ln "$STAGED_MANIFEST" "$CACHED_MANIFEST" 2>/dev/null; then
    cache_invalid
  fi
else
  if ! await_published_unit; then
    cache_invalid
  fi
  print -r -- "$CACHED_BINARY"
  exit 0
fi

if ! validate_cached_unit; then
  cache_invalid
fi

print -r -- "$CACHED_BINARY"
