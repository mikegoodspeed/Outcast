#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_RESOLVER="$ROOT_DIR/scripts/resolve_device.sh"
TARGET_DEVICE_ID="$("$DEVICE_RESOLVER")"

"$ROOT_DIR/scripts/build_device.sh"
"$ROOT_DIR/scripts/install_device.sh"

xcrun devicectl device process launch \
  --device "$TARGET_DEVICE_ID" \
  --terminate-existing \
  com.mike.Outcast
