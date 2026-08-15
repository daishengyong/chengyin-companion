#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_DIR/Info.plist")"
RELEASE_DIR="$PROJECT_DIR/release"
PORTABLE_TEMPLATE="$PROJECT_DIR/packaging/portable"
SOURCE_APP="$PROJECT_DIR/dist/Chengyin Companion.app"
SOURCE_BUILDER="$PROJECT_DIR/scripts/build-portable-source.sh"
SOURCE_AUDITOR="$PROJECT_DIR/scripts/audit-portable-source.py"
mkdir -p "$RELEASE_DIR"

"$PROJECT_DIR/scripts/build-app.sh"
codesign --verify --deep --strict "$SOURCE_APP"
test -x "$SOURCE_APP/Contents/SharedSupport/CompanionEventEmitter"

SOURCE_FINGERPRINT="$(/usr/libexec/PlistBuddy -c 'Print :ChengyinSourceFingerprint' "$SOURCE_APP/Contents/Info.plist")"
SOURCE_SHORT="${SOURCE_FINGERPRINT[1,12]}"
SLUG="Chengyin-Companion-$VERSION-$BUILD-$SOURCE_SHORT-macos-arm64-preview"
SHOW_SLUG="Chengyin-Companion-Episode-01-Production-Kit-$VERSION-$BUILD-$SOURCE_SHORT"
ZIP_PATH="$RELEASE_DIR/$SLUG.zip"
DMG_PATH="$RELEASE_DIR/$SLUG.dmg"
SOURCE_ZIP_PATH="$RELEASE_DIR/$SLUG-source.zip"
SHOW_ZIP_PATH="$RELEASE_DIR/$SHOW_SLUG.zip"
CHECKSUM_PATH="$RELEASE_DIR/$SLUG-SHA256SUMS.txt"

for output in \
  "$ZIP_PATH" \
  "$DMG_PATH" \
  "$SOURCE_ZIP_PATH" \
  "$SHOW_ZIP_PATH" \
  "$CHECKSUM_PATH"; do
  if [[ -e "$output" ]]; then
    echo "Release output already exists; move it before rebuilding: $output" >&2
    exit 1
  fi
done

STAGING_ROOT="$(mktemp -d "$RELEASE_DIR/.portable-release.XXXXXX")"
PACKAGE_ROOT="$STAGING_ROOT/$SLUG"
SHOW_ROOT="$STAGING_ROOT/$SHOW_SLUG"
STAGED_ZIP="$STAGING_ROOT/$SLUG.zip"
STAGED_DMG="$STAGING_ROOT/$SLUG.dmg"
STAGED_SOURCE_ZIP="$STAGING_ROOT/$SLUG-source.zip"
STAGED_SHOW_ZIP="$STAGING_ROOT/$SHOW_SLUG.zip"
STAGED_CHECKSUMS="$STAGING_ROOT/$SLUG-SHA256SUMS.txt"

cleanup() {
  if [[ "$STAGING_ROOT" == "$RELEASE_DIR"/.portable-release.* \
    && -d "$STAGING_ROOT" ]]; then
    /bin/rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

mkdir -p "$PACKAGE_ROOT" "$SHOW_ROOT"

ditto "$SOURCE_APP" "$PACKAGE_ROOT/Chengyin Companion.app"
for name in \
  "Install Chengyin Companion.command" \
  "Uninstall Chengyin Companion.command" \
  "Diagnose Chengyin Companion.command" \
  "START-HERE.md" \
  "CUSTOMIZE.md" \
  "RIGHTS-AND-RELEASE-NOTICE.md"; do
  cp "$PORTABLE_TEMPLATE/$name" "$PACKAGE_ROOT/$name"
done
chmod 755 "$PACKAGE_ROOT"/*.command

(
  cd "$PACKAGE_ROOT"
  find . -type f ! -name SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 shasum -a 256 > SHA256SUMS.txt
)

"$SOURCE_BUILDER" \
  --output "$STAGED_SOURCE_ZIP" \
  --root "$SLUG-source" \
  >/dev/null
"$SOURCE_AUDITOR" "$STAGED_SOURCE_ZIP" --json >/dev/null

ditto "$PROJECT_DIR/docs/show" "$SHOW_ROOT/materials"
cp "$PROJECT_DIR/packaging/portable/START-HERE.md" \
  "$SHOW_ROOT/INSTALL-PACKAGE-START-HERE.md"
cp "$PROJECT_DIR/packaging/portable/CUSTOMIZE.md" \
  "$SHOW_ROOT/CUSTOMIZE-AFTER-INSTALL.md"
cp "$PROJECT_DIR/packaging/portable/RIGHTS-AND-RELEASE-NOTICE.md" \
  "$SHOW_ROOT/RIGHTS-AND-RELEASE-NOTICE.md"

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_ROOT" "$STAGED_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$SHOW_ROOT" "$STAGED_SHOW_ZIP"
hdiutil create \
  -quiet \
  -fs HFS+ \
  -volname "Chengyin Companion Preview" \
  -srcfolder "$PACKAGE_ROOT" \
  "$STAGED_DMG"

(
  cd "$STAGING_ROOT"
  shasum -a 256 \
    "$SLUG.zip" \
    "$SLUG.dmg" \
    "$SLUG-source.zip" \
    "$SHOW_SLUG.zip" \
    > "$SLUG-SHA256SUMS.txt"
)

mv "$STAGED_ZIP" "$ZIP_PATH"
mv "$STAGED_DMG" "$DMG_PATH"
mv "$STAGED_SOURCE_ZIP" "$SOURCE_ZIP_PATH"
mv "$STAGED_SHOW_ZIP" "$SHOW_ZIP_PATH"
mv "$STAGED_CHECKSUMS" "$CHECKSUM_PATH"

printf '%s\n' "$ZIP_PATH" "$DMG_PATH" "$SOURCE_ZIP_PATH" "$SHOW_ZIP_PATH"
