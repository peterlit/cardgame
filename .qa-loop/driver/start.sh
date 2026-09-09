#!/usr/bin/env bash
# start.sh <udid> — build the driver once (cached in .qa-loop/driver/dd) and start serving on the
# named simulator in the background. Idempotent: exits 0 at once if that device is already served.
# Logs: /private/tmp/causeway-qa/<udid>/driver.log
set -euo pipefail
UDID="${1:?usage: start.sh <udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="/private/tmp/causeway-qa/$UDID"
mkdir -p "$ROOT/cmd" "$ROOT/out"
if pgrep -f "test-without-building.*id=$UDID" >/dev/null && python3 "$HERE/qa.py" "$UDID" --alive >/dev/null 2>&1; then echo "already serving $UDID"; exit 0; fi
rm -f "$ROOT/alive"
cd "$HERE"
if [ ! -d QADriver.xcodeproj ]; then xcodegen generate >/dev/null; fi
if [ ! -f dd/built.ok ]; then
  xcodebuild build-for-testing -project QADriver.xcodeproj -scheme QADriver \
    -destination "id=$UDID" -derivedDataPath dd -quiet 2>&1 | grep -v "^$" | tail -5 || true
  ls dd/Build/Products/*/QADriverRunner.app >/dev/null 2>&1 && touch dd/built.ok
fi
rm -f "$ROOT"/cmd/* "$ROOT"/out/* "$ROOT/alive"
nohup xcodebuild test-without-building -project QADriver.xcodeproj -scheme QADriver \
  -destination "id=$UDID" -derivedDataPath dd -only-testing:QADriver/QADriverTests/testServe \
  > "$ROOT/driver.log" 2>&1 &
echo "starting driver on $UDID (pid $!) — waiting for it to serve..."
for i in $(seq 1 120); do
  if python3 "$HERE/qa.py" "$UDID" --alive >/dev/null 2>&1; then echo "serving $UDID"; exit 0; fi
  sleep 1
done
echo "driver did not come up in 120 s; see $ROOT/driver.log"; tail -20 "$ROOT/driver.log"; exit 1
