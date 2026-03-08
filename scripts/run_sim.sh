#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
SIMULATOR_NAME="${1:-iPhone 17 Pro}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Outcast.app"

if ! xcrun simctl list devices booted | grep -Fq "$SIMULATOR_NAME"; then
  xcrun simctl boot "$SIMULATOR_NAME"
fi

xcrun simctl bootstatus "$SIMULATOR_NAME" -b || xcrun simctl bootstatus booted -b

xcodebuild \
  -project "$ROOT_DIR/Outcast.xcodeproj" \
  -scheme Outcast \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.mikegoodspeed.Outcast
