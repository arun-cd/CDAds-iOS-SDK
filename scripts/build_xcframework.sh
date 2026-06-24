#!/usr/bin/env bash
# Builds CDAds.xcframework for binary distribution.
# Usage:  ./scripts/build_xcframework.sh
# Output: build/CDAds.xcframework

set -euo pipefail

SCHEME="CDAds"
FRAMEWORK_NAME="CDAds"
BUILD_DIR="$(pwd)/build"
ARCHIVE_IOS="$BUILD_DIR/ios.xcarchive"
ARCHIVE_SIM="$BUILD_DIR/ios-sim.xcarchive"
OUTPUT="$BUILD_DIR/$FRAMEWORK_NAME.xcframework"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "▶ Archiving for iOS device…"
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_IOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  | xcpretty --quiet || true

echo "▶ Archiving for iOS Simulator…"
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$ARCHIVE_SIM" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  | xcpretty --quiet || true

echo "▶ Creating XCFramework…"
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_IOS/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
  -framework "$ARCHIVE_SIM/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
  -output "$OUTPUT"

echo "✅ Built: $OUTPUT"
