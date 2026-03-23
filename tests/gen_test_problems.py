#!/usr/bin/env python3
"""
Generate SDPA sparse-format (.dat-s) test problems for SDPLR.

Problems are max-cut SDP relaxations on complete graphs K_n.  For K_n, the
SDP relaxation of max-cut has an exact analytical optimal value of -n^2/4
(negative because SDPLR minimises, while max-cut is a maximisation problem).

The SDP formulation (SDPA minimisation form):
  min  -(1/4) * <L, X>
  s.t. X_{ii} = 1  for i = 1..n          (diagonal constraints)
       X >= 0

where L is the graph Laplacian.  For K_n: L_{ii} = n-1, L_{ij} = -1.

Sign convention: SDPLR negates entry-0 (the C matrix) when reading SDPA
files (readdata.c line ~326: CAent = -sam_ent for num==0).  So the file
must contain C_file = +(1/4)*L in order for SDPLR's internal C_internal
= -C_file = -(1/4)*L.  Thus:
  C_file_{ii} = (n-1)/4    (diagonal entries)
  C_file_{ij} = -1/4       (off-diagonal entries)

Optimal value:  b'y* = -(n^2/4)   (exact, provable by symmetry for K_n)

Reference: Goemans & Williamson (1995), also Lovász theta formulation.

Generated files:
  maxcut_k4.dat-s        K_4  (n=4,  optimal = -4.0)
  maxcut_k6.dat-s        K_6  (n=6,  optimal = -9.0)
  maxcut_k8.dat-s        K_8  (n=8,  optimal = -16.0)
  multiblock_k3k3.dat-s  Two independent K_3 blocks (optimal = -4.5)
"""

import os


def write_maxcut_kn(n, path):
    """Write SDPA .dat-s file for max-cut SDP on complete graph K_n."""
    with open(path, 'w') as f:
        # Header: m, nblocks, block sizes, b
        f.write(f"{n}\n")
        f.write("1\n")
        f.write(f"{n}\n")
        f.write("  ".join(["1.0"] * n) + "\n")

        # C matrix (constraint index 0): SDPLR negates entry-0 on read,
        # so C_internal = -C_file.  We want C_internal = -(1/4)*L so that
        # SDPLR minimises -(1/4)*<L,X>, whose optimum is -n^2/4 for K_n.
        # Therefore C_file = +(1/4)*L: diagonal (n-1)/4, off-diagonal -1/4.
        diag_val = (n - 1) / 4.0
        for i in range(1, n + 1):
            f.write(f"0 1 {i} {i} {diag_val:.10f}\n")
        for i in range(1, n + 1):
            for j in range(i + 1, n + 1):
                f.write(f"0 1 {i} {j} -0.2500000000\n")

        # Constraint matrices A_i = e_i * e_i'  (one per diagonal entry)
        for i in range(1, n + 1):
            f.write(f"{i} 1 {i} {i} 1.0\n")


def write_multiblock_k3k3(path):
    """
    Write SDPA .dat-s for two independent K_3 max-cut blocks.
    m=6, nblocks=2, block sizes=[3,3], optimal = -4.5 = 2*(-9/4).

    Constraints 1-3 act on block 1; constraints 4-6 on block 2.
    The two blocks are fully independent: each solves its own K_3.
    """
    n = 3
    diag_val = (n - 1) / 4.0    # = +0.5  (C_file = +(1/4)*L; SDPLR negates on read)
    with open(path, 'w') as f:
        f.write("6\n")            # m = 3+3
        f.write("2\n")            # nblocks
        f.write("3  3\n")         # block sizes
        f.write("  ".join(["1.0"] * 6) + "\n")

        # C matrix: same K_3 structure in each of the two blocks
        # (C_file = +(1/4)*L so C_internal = -(1/4)*L; SDPLR negates entry-0)
        for blk in (1, 2):
            for i in range(1, n + 1):
                f.write(f"0 {blk} {i} {i} {diag_val:.10f}\n")
            for i in range(1, n + 1):
                for j in range(i + 1, n + 1):
                    f.write(f"0 {blk} {i} {j} -0.2500000000\n")

        # Constraint matrices: first 3 constraints → block 1; next 3 → block 2
        for i in range(1, n + 1):
            f.write(f"{i}   1 {i} {i} 1.0\n")   # block 1
        for i in range(1, n + 1):
            f.write(f"{i+3} 2 {i} {i} 1.0\n")   # block 2


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "data")
    os.makedirs(out_dir, exist_ok=True)

    specs = [
        ("maxcut_k4.dat-s",      lambda p: write_maxcut_kn(4, p),  "K_4  optimal=-4.0"),
        ("maxcut_k6.dat-s",      lambda p: write_maxcut_kn(6, p),  "K_6  optimal=-9.0"),
        ("maxcut_k8.dat-s",      lambda p: write_maxcut_kn(8, p),  "K_8  optimal=-16.0"),
        ("multiblock_k3k3.dat-s", write_multiblock_k3k3,           "K_3+K_3 (2 blocks) optimal=-4.5"),
    ]

    for fname, generator, desc in specs:
        fpath = os.path.join(out_dir, fname)
        generator(fpath)
        print(f"  wrote {fname}  ({desc})")


if __name__ == "__main__":
    main()
