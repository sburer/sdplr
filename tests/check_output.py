#!/usr/bin/env python3
"""
Check SDPLR output for correctness.

Usage:
    ./sdplr <problem> | python3 tests/check_output.py <expected_val> [<rel_tol>]

Arguments:
    expected_val   Known optimal objective value (float).
    rel_tol        Relative tolerance for objective check (default 1e-3).

Exit codes:
    0  All checks passed.
    1  One or more checks failed.

Checks performed:
    d1  Primal feasibility   < 1e-4   (always meaningful)
    d4  Dual feasibility     < 1e-3   (skipped when "(n/a)" in output)
    d5  Relative duality gap  |d5| < 1e-3
    d6  Complementarity       |d6| < 1e-3
    val Objective within rel_tol of expected_val (relative)

d2 and d3 are always 0.0 for SDPLR (no LP cone used) and are not checked.
"""

import sys
import re


def parse_output(text):
    """Extract final val and DIMACS measures from SDPLR stdout."""
    val = None
    d1 = d4 = d5 = d6 = None
    d4_na = False

    # Final val: last data row in the table (maj/min/val/infeas columns)
    # Matches lines like "   13     1590  -4.08190122e+01  9.6e-06       0"
    # or                 "    9       17  -3.99999518e+00  3.8e-06       0"
    table_row = re.compile(
        r'^\s+\d+\s+\d+\s+([+-]?\d+\.\d+e[+-]\d+)\s+\S+', re.MULTILINE)
    matches = table_row.findall(text)
    if matches:
        val = float(matches[-1])

    # DIMACS line: two possible formats depending on whether d4 is (n/a)
    #   "DIMACS error measures: d1 d2 d3 d4 d5 d6"
    #   "DIMACS error measures: d1 d2 d3 (n/a) d5 d6"
    dimacs_re = re.compile(
        r'DIMACS error measures:\s+'
        r'([+-]?\S+)\s+([+-]?\S+)\s+([+-]?\S+)\s+'
        r'(n/a|\(n/a\)|[+-]?\S+)\s+'
        r'([+-]?\S+)\s+([+-]?\S+)')
    m = dimacs_re.search(text)
    if m:
        d1 = float(m.group(1))
        # d2, d3 skipped
        d4_token = m.group(4)
        if 'n/a' in d4_token.lower():
            d4_na = True
            d4 = None
        else:
            d4 = float(d4_token)
        d5 = float(m.group(5))
        d6 = float(m.group(6))

    return val, d1, d4, d4_na, d5, d6


def main():
    if len(sys.argv) < 2:
        print("Usage: check_output.py <expected_val> [<rel_tol>]", file=sys.stderr)
        sys.exit(1)

    expected_val = float(sys.argv[1])
    rel_tol = float(sys.argv[2]) if len(sys.argv) > 2 else 1e-3

    text = sys.stdin.read()
    val, d1, d4, d4_na, d5, d6 = parse_output(text)

    failures = []

    if val is None:
        failures.append("Could not parse objective value from output")
    else:
        denom = max(1.0, abs(expected_val))
        rel_err = abs(val - expected_val) / denom
        if rel_err > rel_tol:
            failures.append(
                f"val {val:.6e} not within {rel_tol:.0e} of expected "
                f"{expected_val:.6e} (rel_err={rel_err:.2e})")

    if d1 is None:
        failures.append("Could not parse DIMACS measures from output")
    else:
        if d1 >= 1e-4:
            failures.append(f"d1 (primal feasibility) = {d1:.2e} >= 1e-4")
        if not d4_na and d4 is not None and d4 >= 1e-3:
            failures.append(f"d4 (dual feasibility) = {d4:.2e} >= 1e-3")
        if d5 is not None and abs(d5) >= 1e-3:
            failures.append(f"d5 (duality gap) = {d5:.2e}, |d5| >= 1e-3")
        if d6 is not None and abs(d6) >= 1e-3:
            failures.append(f"d6 (complementarity) = {d6:.2e}, |d6| >= 1e-3")

    if failures:
        print("FAIL")
        for f in failures:
            print(f"  {f}")
        sys.exit(1)
    else:
        print("PASS")
        if val is not None:
            print(f"  val={val:.8e}  expected={expected_val:.6e}  "
                  f"d1={d1:.2e}  d5={d5:.2e}  d6={d6:.2e}")
        sys.exit(0)


if __name__ == "__main__":
    main()
