#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/Outcast.app"
DEVICE_RESOLVER="$ROOT_DIR/scripts/resolve_device.sh"
TARGET_DEVICE_ID="$("$DEVICE_RESOLVER")"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Device app bundle not found at $APP_PATH. Run ./scripts/build_device.sh or make build-device first." >&2
  exit 1
fi

xcrun devicectl device install app --device "$TARGET_DEVICE_ID" "$APP_PATH"
