#!/usr/bin/env bash
# Build, then run every self-test. Exits non-zero if any of them fails.
#
#     tools/test.sh                  build and test against assets/
#     tools/test.sh <data dir>       test against a different copy of the data
#     AKUJI_EXE=bin/other.exe tools/test.sh
#
# AKUJI_EXE builds and tests a binary other than bin/akuji.exe - see
# tools/build.sh. The log stays beside whichever binary wrote it.
#
# The tests live in tests/ and are linked into the binary itself, so they run
# the same code the game runs rather than a copy of it. Each mode is a separate
# process: the game is a GUI-subsystem binary that writes bin/selftest.log and
# prints nothing to stdout, so the log and the exit code are both read.
#
# Never pipe the run itself - $? would belong to the pipe, and a failing test
# would look green.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${1:-$REPO/assets}"
case "${AKUJI_EXE:-}" in
    "")  EXE="$REPO/bin/akuji.exe" ;;
    /*)  EXE="$AKUJI_EXE" ;;
    ?:*) EXE="$AKUJI_EXE" ;;
    *)   EXE="$REPO/$AKUJI_EXE" ;;
esac
LOG="$(dirname "$EXE")/selftest.log"

if [ ! -d "$DATA/data" ]; then
    echo "FAIL: no game data at: $DATA" >&2
    exit 2
fi

"$REPO/tools/build.sh" || exit 1

SCRATCH="$(mktemp -d 2>/dev/null || echo "${TEMP:-/tmp}/akuji_test_$$")"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

fail=0
skips=0

run() {
    local name="$1"; shift
    rm -f "$LOG"
    "$EXE" "$name" "$@" > /dev/null 2>&1
    local rc=$?
    local last=""
    [ -f "$LOG" ] && last="$(tail -1 "$LOG")"
    if [ $rc -eq 0 ]; then
        printf '  %-22s ok    %s\n' "$name" "${last:0:56}"
    else
        printf '  %-22s FAIL  rc=%d\n' "$name" "$rc"
        [ -f "$LOG" ] && grep -iE '^\s*FAIL' "$LOG" | head -5 | sed 's/^/        /'
        fail=1
    fi
    if [ -f "$LOG" ] && grep -qiE '^\s*SKIP' "$LOG"; then
        skips=$((skips + $(grep -ciE '^\s*SKIP' "$LOG")))
    fi
}

echo "=== self-tests ==="
run --selftest          "$DATA/bmp.qda" "$SCRATCH"
run --selftest-audio    "$DATA"
run --selftest-midi     "$DATA"
run --selftest-dir      "$DATA"
run --selftest-events   "$DATA"
run --selftest-script   "$DATA"
run --selftest-stages   "$DATA"
run --selftest-player   "$DATA"
run --selftest-trace    "$DATA"
run --selftest-layouts  "$DATA"
run --selftest-entities "$DATA"
run --selftest-runner   "$DATA"
run --selftest-session  "$DATA"
run --selftest-settings "$DATA" "$SCRATCH"
run --selftest-mapprobe "$DATA"
run --selftest-render   "$DATA"

echo
[ "$skips" -gt 0 ] && echo "$skips check(s) skipped - see bin/selftest.log for why"

if [ "$fail" -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "all tests passed"
