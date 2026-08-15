#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="Chengyin Companion"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
COMMON_SCRIPT="$PROJECT_DIR/scripts/app-bundle-common.sh"
BUILD_CACHE_SCRIPT="$PROJECT_DIR/scripts/swift-build-cache.sh"
SWAP_SOURCE="$PROJECT_DIR/scripts/atomic-app-swap.swift"
STARTER_MANIFEST_TOOL="$PROJECT_DIR/scripts/refresh-starter-media-manifest.py"
STARTER_AUDITOR="$PROJECT_DIR/scripts/audit-starter-media.py"
STARTER_RESOURCES="$PROJECT_DIR/Sources/CompanionApp/Resources"
PUBLIC_CODE_ONLY_MARKER="$STARTER_RESOURCES/public-code-only.json"

source "$COMMON_SCRIPT"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
source "$BUILD_CACHE_SCRIPT"

SWIFT_BUILD_ROOT="$(
  chengyin_swift_build_root "$PROJECT_DIR" app-release
)"
BUILD_DIR="$SWIFT_BUILD_ROOT/release"

# The private production tree carries a reviewed Starter manifest. Public
# code-only checkouts intentionally omit all Starter media and carry a bounded
# marker instead. Both paths fail closed: an unexplained missing manifest is
# never treated as permission to package a partial media inventory.
CODE_ONLY_MODE=0
if [[ -f "$STARTER_RESOURCES/starter-media.json" ]]; then
  python3 "$STARTER_MANIFEST_TOOL" --check
  python3 "$STARTER_AUDITOR" --resources "$STARTER_RESOURCES" --json >/dev/null
elif [[ -f "$PUBLIC_CODE_ONLY_MARKER" ]]; then
  python3 -m json.tool "$PUBLIC_CODE_ONLY_MARKER" >/dev/null
  CODE_ONLY_MODE=1
else
  echo "Starter media manifest is missing without a public code-only marker." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.build-app.XXXXXX")"
STAGED_APP="$STAGING_DIR/$APP_NAME.app"
SWAP_HELPER="$STAGING_DIR/atomic-app-swap"

cleanup() {
  if [[ -n "${STAGING_DIR:-}" \
    && "$STAGING_DIR" == "$DIST_DIR"/.build-app.* \
    && -d "$STAGING_DIR" ]]; then
    /bin/rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

SOURCE_FINGERPRINT_BEFORE="$(chengyin_source_fingerprint "$PROJECT_DIR")"

cd "$PROJECT_DIR"
swift build \
  --build-path "$SWIFT_BUILD_ROOT" \
  -c release \
  --disable-sandbox

SOURCE_FINGERPRINT_AFTER="$(chengyin_source_fingerprint "$PROJECT_DIR")"
if [[ "$SOURCE_FINGERPRINT_BEFORE" != "$SOURCE_FINGERPRINT_AFTER" ]]; then
  echo "App sources changed during the build; stopped before packaging." >&2
  exit 1
fi

mkdir -p "$STAGED_APP/Contents/MacOS"
mkdir -p "$STAGED_APP/Contents/Resources"
mkdir -p "$STAGED_APP/Contents/SharedSupport"

cp "$BUILD_DIR/ChengyinCompanion" \
  "$STAGED_APP/Contents/MacOS/ChengyinCompanion"
if [[ ! -x "$BUILD_DIR/CompanionEventEmitter" ]]; then
  echo "CompanionEventEmitter is missing from the release build." >&2
  exit 1
fi
cp "$BUILD_DIR/CompanionEventEmitter" \
  "$STAGED_APP/Contents/SharedSupport/CompanionEventEmitter"
chmod 755 "$STAGED_APP/Contents/SharedSupport/CompanionEventEmitter"
cp "$PROJECT_DIR/Info.plist" "$STAGED_APP/Contents/Info.plist"

RESOURCE_BUNDLE="$(find -L "$BUILD_DIR" -maxdepth 1 -type d -name '*CompanionApp*.bundle' | head -1)"
if [[ -z "$RESOURCE_BUNDLE" ]]; then
  echo "SwiftPM resource bundle is missing; stopped before replacing dist." >&2
  exit 1
fi

find "$RESOURCE_BUNDLE" -type f \
  \( -name '*.icns' -o -name '*.png' -o -name '*.json' \
    -o -name '*.mp3' -o -name '*.wav' -o -name '*.mov' \) \
  -exec cp {} "$STAGED_APP/Contents/Resources/" \;

# Preserve localization directory structure. Flattening `.strings` files would
# make Bundle locale resolution impossible and previously caused packaged builds
# to fall back to source-language copy even though SwiftPM previews were localized.
while IFS= read -r locale_dir; do
  cp -R "$locale_dir" "$STAGED_APP/Contents/Resources/"
done < <(find "$RESOURCE_BUNDLE" -maxdepth 1 -type d -name '*.lproj' -print)

if [[ "$CODE_ONLY_MODE" -eq 0 ]]; then
  python3 "$STARTER_AUDITOR" \
    --resources "$STARTER_RESOURCES" \
    --bundle "$STAGED_APP/Contents/Resources" \
    --json \
    >/dev/null
else
  if find "$STAGED_APP/Contents/Resources" -type f \
    \( -name '*.mov' -o -name '*.mp4' -o -name '*.mp3' -o -name '*.wav' \
      -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \
      -o -name '*.icns' \) \
    | grep -q .; then
    echo "Public code-only build unexpectedly contains a bundled media asset." >&2
    exit 1
  fi
fi

VERSION="$(chengyin_plist_value "$STAGED_APP" CFBundleShortVersionString)"
BUILD="$(chengyin_plist_value "$STAGED_APP" CFBundleVersion)"
SOURCE_SHORT="$(chengyin_short_fingerprint "$SOURCE_FINGERPRINT_AFTER")"
BUILD_IDENTITY="$VERSION+$BUILD.$SOURCE_SHORT"
BUILD_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

/usr/libexec/PlistBuddy \
  -c "Add :ChengyinSourceFingerprint string $SOURCE_FINGERPRINT_AFTER" \
  "$STAGED_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Add :ChengyinBuildIdentity string $BUILD_IDENTITY" \
  "$STAGED_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Add :ChengyinBuildTimestamp string $BUILD_TIMESTAMP" \
  "$STAGED_APP/Contents/Info.plist"

# This is ad-hoc local sealing only. It does not use a Developer ID identity,
# notarize the app or create a public release.
codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

xcrun swiftc "$SWAP_SOURCE" -o "$SWAP_HELPER"
if [[ -d "$APP_DIR" ]]; then
  "$SWAP_HELPER" "$STAGED_APP" "$APP_DIR"
else
  mv "$STAGED_APP" "$APP_DIR"
fi

echo "$APP_DIR"
echo "Built $APP_NAME $(chengyin_bundle_label "$APP_DIR")"
if [[ "$CODE_ONLY_MODE" -eq 1 ]]; then
  echo "Public code-only mode: system-symbol fallback active; no Starter media bundled."
fi
