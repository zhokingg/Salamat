#!/usr/bin/env bash
#
# One-command App Store capture run.
#
#   ./scripts/capture_store.sh
#
# Boots the 6.9" simulator, starts the host screenshot server, runs the
# integration test that walks the app, and writes verified 1320x2868 frames
# into store2/. Any frame with the wrong size fails the run.
#
# Overridable: SALAMAT_UDID, SALAMAT_SHOT_PORT, SALAMAT_SHOT_DIR, FLUTTER_BIN,
#              SALAMAT_TEST

set -euo pipefail

cd "$(dirname "$0")/.."

export SALAMAT_UDID="${SALAMAT_UDID:-C5D3C6E3-DDC3-488D-80A3-8FD2BEE8B944}"
export SALAMAT_SHOT_PORT="${SALAMAT_SHOT_PORT:-8787}"
export SALAMAT_SHOT_DIR="${SALAMAT_SHOT_DIR:-store2}"

# The project needs Flutter 3.41.9: IconData became `final` in 3.44 (breaks
# phosphor_flutter / lucide_icons) and camera_avfoundation < 0.9.22 segfaults
# on the iOS 26 simulator, which needs >= 3.35.
DEFAULT_FLUTTER="$HOME/fvm/versions/3.41.9/bin/flutter"
FLUTTER_BIN="${FLUTTER_BIN:-$DEFAULT_FLUTTER}"
if [ ! -x "$FLUTTER_BIN" ]; then
  FLUTTER_BIN="$(command -v flutter || true)"
fi
if [ -z "$FLUTTER_BIN" ]; then
  echo "error: no flutter binary; set FLUTTER_BIN" >&2
  exit 1
fi
echo "flutter: $("$FLUTTER_BIN" --version 2>/dev/null | head -1)"

mkdir -p "$SALAMAT_SHOT_DIR"

# ---- simulator ----
if ! xcrun simctl list devices | grep -q "$SALAMAT_UDID.*Booted"; then
  echo "booting $SALAMAT_UDID"
  xcrun simctl boot "$SALAMAT_UDID"
fi
# The framebuffer only renders with the Simulator UI up; a headless boot
# returns stale SpringBoard frames.
open -a Simulator --args -CurrentDeviceUDID "$SALAMAT_UDID" >/dev/null 2>&1 || true

# ---- screenshot server ----
SHOT_LOG="$(mktemp -t salamat-shot)"
python3 tools/shot_server.py >"$SHOT_LOG" 2>&1 &
SHOT_PID=$!
cleanup() {
  kill "$SHOT_PID" 2>/dev/null || true
  wait "$SHOT_PID" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${SALAMAT_SHOT_PORT}/ping" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done
if ! curl -fsS "http://127.0.0.1:${SALAMAT_SHOT_PORT}/ping" >/dev/null 2>&1; then
  echo "error: shot server did not come up" >&2
  cat "$SHOT_LOG" >&2
  exit 1
fi

# ---- the run ----
set +e
# Which capture to run. store_frames_test.dart seeds a full day and shoots
# the five listing frames; store_screens_test.dart is the original
# onboarding walk-through.
SALAMAT_TEST="${SALAMAT_TEST:-integration_test/store_frames_test.dart}"
echo "capture: $SALAMAT_TEST"
"$FLUTTER_BIN" test "$SALAMAT_TEST" -d "$SALAMAT_UDID"
TEST_RC=$?
set -e

echo
echo "--- captured ---"
cat "$SHOT_LOG"

if [ "$TEST_RC" -ne 0 ]; then
  echo "capture run FAILED (flutter test exit $TEST_RC)" >&2
  exit "$TEST_RC"
fi

echo
echo "frames in $SALAMAT_SHOT_DIR:"
ls -1 "$SALAMAT_SHOT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' '
