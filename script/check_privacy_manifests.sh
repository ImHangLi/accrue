#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-dist/Accrue.app}"
APP_MANIFEST="$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
TELEMETRYDECK_MANIFEST="$APP_BUNDLE/Contents/Resources/TelemetryDeck_TelemetryDeck.bundle/PrivacyInfo.xcprivacy"

if [[ ! -f "$APP_MANIFEST" ]]; then
  echo "missing app privacy manifest: $APP_MANIFEST" >&2
  exit 1
fi

if [[ ! -f "$TELEMETRYDECK_MANIFEST" ]]; then
  echo "missing TelemetryDeck privacy manifest: $TELEMETRYDECK_MANIFEST" >&2
  exit 1
fi

plutil -lint "$APP_MANIFEST"
plutil -lint "$TELEMETRYDECK_MANIFEST"
