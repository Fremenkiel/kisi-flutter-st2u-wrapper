#!/usr/bin/env bash
# Downloads the native Kisi ST2U SDK binaries required to build the plugin.
#
# Usage:
#   sh scripts/setup.sh                 # install latest known versions
#   sh scripts/setup.sh --ios-tag 0.8.0 --android-version 0.16
#
# You can also invoke this via the Dart run helper (once registered):
#   dart run kisi_st2u:setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

IOS_TAG="0.8.0"
ANDROID_VERSION="0.16"

# Parse optional overrides
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ios-tag)        IOS_TAG="$2";         shift 2 ;;
    --android-version) ANDROID_VERSION="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── iOS: download SecureAccess.xcframework ──────────────────────────────────
IOS_FRAMEWORKS_DIR="$ROOT_DIR/ios/Frameworks"
IOS_XCFRAMEWORK="$IOS_FRAMEWORKS_DIR/SecureAccess.xcframework"

if [ -d "$IOS_XCFRAMEWORK" ]; then
  echo "[iOS] SecureAccess.xcframework already present – skipping download."
else
  echo "[iOS] Downloading SecureAccess.xcframework @ tag $IOS_TAG ..."
  mkdir -p "$IOS_FRAMEWORKS_DIR"
  TMP_ZIP="$IOS_FRAMEWORKS_DIR/SecureAccess.xcframework.zip"

  # The XCFramework is stored directly in the repo; we clone it sparsely.
  REPO_URL="https://github.com/kisi-inc/kisi-ios-st2u-framework.git"
  TMP_CLONE="$IOS_FRAMEWORKS_DIR/_clone_tmp"

  git clone --depth 1 --branch "$IOS_TAG" --filter=blob:none --sparse \
    "$REPO_URL" "$TMP_CLONE"
  (cd "$TMP_CLONE" && git sparse-checkout set SecureAccess.xcframework)
  cp -R "$TMP_CLONE/SecureAccess.xcframework" "$IOS_XCFRAMEWORK"
  rm -rf "$TMP_CLONE"

  echo "[iOS] SecureAccess.xcframework downloaded successfully."
fi

# ── Android: download st2u AAR into android/libs/ ───────────────────────────
# The AAR is referenced directly by file path in the plugin's build.gradle,
# so no local Maven repo setup is required.
ANDROID_LIBS_DIR="$ROOT_DIR/android/libs"
ANDROID_AAR="$ANDROID_LIBS_DIR/st2u-$ANDROID_VERSION.aar"

if [ -f "$ANDROID_AAR" ]; then
  echo "[Android] st2u-$ANDROID_VERSION.aar already present – skipping download."
else
  echo "[Android] Downloading st2u-$ANDROID_VERSION.aar ..."
  mkdir -p "$ANDROID_LIBS_DIR"
  AAR_URL="https://github.com/kisi-inc/kisi-android-st2u-sdk-public/releases/download/$ANDROID_VERSION/st2u-$ANDROID_VERSION.aar"
  curl -fL --progress-bar -o "$ANDROID_AAR" "$AAR_URL"
  echo "[Android] st2u-$ANDROID_VERSION.aar downloaded successfully."
fi

echo ""
echo "✓ Setup complete. You can now build your Flutter project."
