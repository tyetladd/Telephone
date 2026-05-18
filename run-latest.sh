#!/usr/bin/env bash
set -euo pipefail

# Simple helper to build and launch Telephone without code signing.
# Usage: CONFIG=Release ./run-latest.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-"$ROOT/.derived"}"
CONFIGURATION="${CONFIG:-Debug}"
ARCH="${ARCH:-arm64}"
DESTINATION="${DESTINATION:-platform=macOS,arch=$ARCH}"

echo "Building Telephone ($CONFIGURATION, $ARCH)…"
xcodebuild \
  -project "$ROOT/Telephone.xcodeproj" \
  -scheme Telephone \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Telephone.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at $APP_PATH" >&2
  exit 1
fi

echo "Launching ${APP_PATH}…"
open "$APP_PATH"
