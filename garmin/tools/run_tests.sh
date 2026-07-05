#!/usr/bin/env bash
# Build the bgdude Connect IQ unit tests and run them in the simulator.
#
# Prereqs (see ../README.md): Connect IQ SDK on PATH (monkeyc, monkeydo, connectiq) and a
# developer key at garmin/developer_key.der.
#
# Usage (from garmin/):  tools/run_tests.sh [device]
set -euo pipefail

DEVICE="${1:-fenix7}"
KEY="${KEY:-developer_key.der}"
cd "$(dirname "$0")/.."

command -v monkeyc >/dev/null || { echo "monkeyc not on PATH — install the Connect IQ SDK."; exit 1; }
[ -f "$KEY" ] || { echo "Developer key '$KEY' not found (see README section 2)."; exit 1; }

mkdir -p bin
echo "Building unit tests for $DEVICE..."
monkeyc -f test.jungle -d "$DEVICE" --unit-test -o bin/test.prg -y "$KEY" -w

# The simulator must be running for monkeydo.
if ! pgrep -f "connectiq|simulator" >/dev/null 2>&1; then
    echo "Starting Connect IQ simulator..."
    connectiq &
    sleep 6
fi

echo "Running tests (-t) in the simulator..."
monkeydo bin/test.prg "$DEVICE" -t
