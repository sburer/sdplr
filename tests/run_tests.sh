#!/usr/bin/env bash
# run_tests.sh — run SDPLR on each test problem and check output
#
# Usage:
#   ./tests/run_tests.sh              # run all tests
#   ./tests/run_tests.sh --fast       # run vibra1 only (quick smoke test)
#
# Must be invoked from the repository root (where ./sdplr lives).

set -euo pipefail

SDPLR=./sdplr
CHECKER=(python3 tests/check_output.py)
DATA=tests/data

PASS=0
FAIL=0
SKIP=0

run_test() {
    local name="$1"
    local file="$2"
    local expected="$3"
    local rel_tol="${4:-1e-3}"

    if [ ! -f "$file" ]; then
        echo "SKIP  $name  (file not found: $file)"
        SKIP=$((SKIP + 1))
        return
    fi

    printf "%-36s" "$name"
    result=$("$SDPLR" "$file" 2>&1 | "${CHECKER[@]}" "$expected" "$rel_tol")
    status=$(echo "$result" | head -1)
    details=$(echo "$result" | tail -n +2)

    if [ "$status" = "PASS" ]; then
        echo "PASS"
        if [ -n "$details" ]; then echo "  $details"; fi
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        echo "$result" | while IFS= read -r line; do echo "  $line"; done
        FAIL=$((FAIL + 1))
    fi
}

FAST=0
for arg in "$@"; do
    if [ "$arg" = "--fast" ]; then FAST=1; fi
done

echo "=== SDPLR test suite ==="
echo ""

# Anchor test (always run)
run_test "vibra1 (anchor)"             "$DATA/vibra1.dat-s"          -40.8190  1e-3

if [ "$FAST" -eq 0 ]; then
    # Synthetic max-cut SDP problems (analytically known optima)
    run_test "max-cut K_4  (opt=-4.0)"     "$DATA/maxcut_k4.dat-s"    -4.0      1e-3
    run_test "max-cut K_6  (opt=-9.0)"     "$DATA/maxcut_k6.dat-s"    -9.0      1e-3
    run_test "max-cut K_8  (opt=-16.0)"    "$DATA/maxcut_k8.dat-s"    -16.0     1e-3
    run_test "2-block K_3+K_3 (opt=-4.5)" "$DATA/multiblock_k3k3.dat-s" -4.5   1e-3
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped."

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
