#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
SIMULATOR_NAME="${1:-iPhone 17 Pro}"

xcodebuild \
  -project "$ROOT_DIR/Outcast.xcodeproj" \
  -scheme Outcast \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test
