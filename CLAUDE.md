# CLAUDE.md — SDPLR Developer Reference

## What SDPLR Is

SDPLR (version 1.03-beta) is a C implementation of a **low-rank algorithm for semidefinite programming (SDP)**. Instead of solving the full SDP directly, it parameterizes the positive semidefinite variable as `X = R * R'` where `R` is a tall-thin matrix, reducing the problem to an unconstrained nonlinear optimization over `R`. This approach scales well to large, sparse SDPs where the optimal solution has low rank.

The algorithm uses an **augmented Lagrangian / penalty method** outer loop with **L-BFGS** as the inner solver. It supports both standalone command-line use and a MATLAB interface via a MEX file.

Reference: Burer & Monteiro, "A nonlinear programming algorithm for solving semidefinite programs via low-rank factorization," Mathematical Programming, 2003.

---

## Building

### Dependencies

- **GCC** (C compiler)
- **LAPACK** and **BLAS** (linear algebra routines)
- **gfortran** (Fortran runtime, needed to link LAPACK/BLAS)
- A minimal subset of **GSL 1.5** is bundled in `gsl-1.5/` (polynomial solvers only; no separate GSL install needed)

On Ubuntu/Debian: `sudo apt-get install gcc liblapack-dev libblas-dev gfortran`

### Configuration

Run `./configure.sh` to auto-detect LAPACK/BLAS and generate `Makefile.inc` (Linux and macOS). For Windows/MinGW, copy `Makefile.inc.mingw` and edit manually.

`Makefile.inc` has three sections:

```makefile
LAPACK_LIB_DIR=   # directory containing liblapack; blank = system default (-L omitted)
LAPACK_LIB= -llapack
BLAS_LIB_DIR=
BLAS_LIB= -lblas
CC       = gcc
CFLAGS   = -O3
LIB_DIRS = -L$(LAPACK_LIB_DIR) -L$(BLAS_LIB_DIR)   # extra -L flags
LIBS     = -lgsl $(LAPACK_LIB) $(BLAS_LIB) -lgfortran -lm
```

Key points:
- `LIB_DIRS` adds `-L` search paths; the repo's own `lib/` directory is appended automatically by `source/Makefile`.
- `LIBS` specifies libraries in link order — order matters for static linkers. `-lgsl` must precede LAPACK/BLAS; `-lgfortran` (Fortran runtime required by LAPACK) and `-lm` go last.
- A typical Ubuntu line: `LIBS = -lgsl -llapack -lblas -lgfortran -lm`
- On macOS with Accelerate: `LIBS = -lgsl -framework Accelerate`

### Windows (MinGW) prerequisites

- MinGW base system including `mingw32-make`; add MinGW's `bin/` to the Windows PATH
- MinGW gcc + gfortran toolchain (latest release recommended)
- LAPACK and BLAS compiled for MinGW (`.a` static libraries)
- Edit `Makefile.inc.mingw` to set `LAPACK_LIB_DIR` and `BLAS_LIB_DIR` to where those libraries live, then run `mingw32-make mingw`

### Make Commands

```bash
make            # build everything (GSL subset + sdplr binary)
make gsl        # build only the bundled GSL polynomial library -> lib/libgsl.a
make sdplr      # build only the sdplr binary (requires lib/libgsl.a)
make clean      # remove .o files
make cleanall   # remove .o files, binaries, and lib/libgsl.a

# Windows (MinGW)
make mingw
make mingw_clean
make mingw_cleanall
```

The build produces a single executable: `sdplr` (or `sdplr.exe` on Windows).

### MATLAB MEX Interface

Build the MEX file from within MATLAB:

```matlab
run mexinstall.m   % sets up paths and compiles mexsdplr
help sdplr         % full calling convention
```

This produces `mexsdplr.mex*` which is called by `sdplr.m`.

**Windows note:** the top two lines of `mexinstall.m` set paths to MATLAB's own LAPACK/BLAS `.lib` files; adjust them for the actual location on your system.

---

## Running SDPLR

### Command-Line Usage

```bash
# Basic: solve problem using default parameters
./sdplr <input_file>

# With explicit params file
./sdplr <input_file> <params_file>

# Warm start: load solution from file
./sdplr <input_file> <params_file> <soln_in>

# Warm start and save solution
./sdplr <input_file> <params_file> <soln_in> <soln_out>

# Generate a default params file (interactive wizard)
# Type 'i' at any parameter prompt for a detailed explanation
./sdplr gen_params
```

### Input Formats

Controlled by the `Input type` parameter in `sdplr.params`:
- `1` — **SDPA sparse format** (`.dat-s`), the default and most common
- `2` — SDPLR native format
- `1000` — raw binary format

Example input files are in `data/` and `tests/data/`:
- `data/vibra1.dat-s` — SDPA format problem (also used by `make test-fast`)

### MATLAB Usage

```matlab
% Solve:  min c'x  s.t.  A*x = b,  x in K
[x, y, info, r] = sdplr(A, b, c, K)
[x, y, info, r] = sdplr(A, b, c, K, pars, lrA, x0, y0, info0, r0)
```

`K` follows SeDuMi cone format: `K.l` (number of nonnegative variables), `K.s` (vector of SDP block sizes). See `sdplr.m` for full documentation.

### Parameters (`sdplr.params`)

Key parameters (generate defaults with `./sdplr gen_params`):

| Parameter | Default | Description |
|-----------|---------|-------------|
| Input type | 1 | 1=SDPA, 2=SDPLR |
| Feasibility tolerance | 1e-5 | Primal/dual feasibility |
| Centrality tolerance | 0.1 | Augmented Lagrangian penalty |
| Penalty factor increase | 2.0 | `sigmafac` — how fast penalty grows |
| Rank reduction | 0 | 1=yes: try to reduce rank during solve |
| Time limit | 3600 | Seconds |
| Print level | 1 | 0=silent, 1=verbose |
| Dthresh dim | 10 | Block size below which dense storage is used |
| Dthresh density | 0.75 | Density above which dense storage is used |
| Number of LBFGS vectors | 4 | L-BFGS memory parameter |
| Duality gap tolerance | 1e-3 | Stopping tolerance on gap |

---

## Key Source Files

| File | Role |
|------|------|
| `source/main.c` | Entry point: parses args, reads data, initializes, calls `sdplrlib`, writes output |
| `source/sdplrlib.c` | **Core algorithm**: augmented Lagrangian outer loop, convergence checks, scaling |
| `source/lbfgs.c` | L-BFGS inner solver for the smooth subproblem over `R` |
| `source/linesearch.c` | Line search used by L-BFGS |
| `source/rankreduce.c` | Rank reduction heuristic |
| `source/eigen.c` | Eigenvalue computations (calls LAPACK) |
| `source/dataoper.c` | Sparse matrix data operations (computing `A(X)`, etc.) |
| `source/readdata.c` | Parsers for SDPA and SDPLR input formats |
| `source/initialize.c` | Problem initialization and setup |
| `source/params.c` | Read/write parameter files |
| `source/misc.c` | Miscellaneous utilities |
| `source/util.c` | Memory and math utility functions |
| `source/timefuncs.c` | Portable timing functions |
| `source/copystructures.c` | Deep copy of problem data structures |
| `source/mexsdplr.c` | MATLAB MEX wrapper around `sdplrlib` |
| `source/structures.h` | Core data structure definitions (`problemdata`, `lbfgsvec`, etc.) |
| `source/macros.h` | `MYCALLOC`, `MYFREE`, `DATABLOCKIND`, and other macros |
| `source/headers.h` | Includes for LAPACK/BLAS prototypes |
| `source/globals.h` | Extern declarations for global variables |
| `source/version.h` | Version string (`"1.03-beta"`) |
| `sdplr.m` | MATLAB interface; full documentation of calling convention |
| `mexinstall.m` | Script to compile the MEX file from MATLAB |
| `sdplr.params` | Default parameter file |

---

## Indexing Convention (Two-Zone Model)

The codebase uses a deliberate **two-zone indexing model** to interface cleanly with Fortran BLAS/LAPACK routines:

**External zone (main.c, mexsdplr.c):** Arrays are allocated with standard 0-based C indexing (`MYCALLOC(R, double, nr)`) and initialized with 0-based loops (`for h = 0; h < nr`).

**Boundary:** On entry to `sdplrlib`, pointers are decremented by 1:
```c
sdplrlib(..., R-1, lambda-1, ...);      // main.c
data->blksz   = blksz-1;               // copystructures.c
data->blktype = blktype-1;
data->b       = b-1;
```

**Internal zone (sdplrlib and everything it calls):** All arrays are accessed with 1-based indices. Block loops run `k = 1..numblk`, vector loops run `i = 1..m`, and so on. The `EASY*` macros (`EASYDAXPY`, `EASYDDOT`, etc.) reinforce this by adding `+1` to every pointer before calling BLAS — callers must pass the base pointer (not base+1) and allocate `size+1` elements so that index [0] is unused padding.

**Exception:** The `CA*` arrays (`CAent`, `CArow`, `CAcol`, `CAinfo_entptr`, etc.) are genuinely 0-based throughout and are never pointer-decremented. The `DATABLOCKIND` macro computes 0-based flat indices into these arrays.

**`vio` is a hybrid:** `vio[0]` holds the objective contribution directly (scalar access), while `vio[1..m]` hold constraint violations and are operated on via `EASY*` macros.

The pattern is well-established and pervasive. Do not attempt to normalize to pure 0-based indexing without first building a comprehensive test suite — a single missed conversion produces silent wrong answers in the numerics.

---

## Developer Notes

**Algorithm overview:** The outer loop is an augmented Lagrangian method that penalizes constraint violations while updating dual variables (`lambda`). The penalty parameter `sigma` grows by `sigmafac` when progress stalls. Each inner iteration minimizes the augmented Lagrangian over the low-rank factor `R` using L-BFGS with backtracking line search.

**Rank initialization:** The initial rank for each SDP block is heuristically set to `min(sqrt(2 * nnz_constraints) + 1, block_size)`. See `getstorage()` in `main.c`.

**Dense vs. sparse storage:** Data blocks smaller than `dthresh_dim` or denser than `dthresh_dens` are stored as dense matrices; others use sparse (COO) format. This is decided in `initialize.c`.

**MEX build:** The same `sdplrlib.c` core is compiled for both the standalone binary and the MEX interface. The `__MEX` preprocessor flag enables MATLAB-specific I/O in `main.c` and `sdplrlib.c`.

**Random seed:** The initial point `R` is set using `srand(925)` (fixed seed). To use a random seed instead, set `#define RANDOM 1` in `source/macros.h` (the canonical location; the code then calls `srand((unsigned)time(NULL))` instead).

**Output format:** The solution file written by `writeout()` (and read by `readin()`) stores dual variable `lambda` and the low-rank factor `R` per block, plus algorithmic metadata (`majiter`, `iter`, `sigma`, `scale`, etc.).

**License:** GPL v2 (see `COPYING`). The bundled GSL 1.5 subset is also GPL v2.

---

## SDPLR Format Specification

The SDPLR format is an extension of SDPA sparse format that additionally supports **low-rank data matrices**. Use it when constraint matrices have a known factorization A = BDBᵀ (B dense, D diagonal), which avoids storing large sparse matrices explicitly.

Select with `Input type = 2` in the params file.

### File structure

```
m                          (number of constraints / dual variables)
k                          (number of blocks)
n_1 n_2 ... n_k            (block sizes; negative n_j = diagonal/LP block of size |n_j|)
b_1 b_2 ... b_m            (RHS vector, all on one line)
trace_bound                (currently ignored; reserved for combinatorial dual bounds)
<(m+1)*k data sections>    (objective matrix first, then constraint matrices in order;
                            within each matrix, blocks listed in order)
```

### Sparse block section

Header line: `mat_index  blk_index  s  nnz`

- `mat_index = 0` for objective C; `mat_index = i` for constraint Aᵢ
- `s` indicates sparse storage
- `nnz` = number of nonzero entries in the upper triangle

Followed by `nnz` lines, each: `row  col  value`  (row ≤ col; upper triangle only)

### Low-rank block section

Header line: `mat_index  blk_index  l  r`

- `l` indicates low-rank storage
- `r` = rank of this block (the block is stored as BDBᵀ, B ∈ ℝⁿʲ×ʳ, D ∈ ℝʳ×ʳ diagonal)

Followed by:
- `r` lines containing the diagonal entries of D (d₁, d₂, …, dᵣ)
- `nⱼ * r` lines containing the entries of B in **column-major** order (B is stored dense)

### Sign convention (same as SDPA)

SDPLR negates the objective matrix (entry 0) on read. The internal problem is
**min −C•X** s.t. Aᵢ•X = bᵢ, X ⪰ 0. To minimise f(X) = C•X, write **−C** as entry 0.

### Worked example: Lovász theta for the 5-cycle

The Lovász theta number ϑ(C₅) = √5 is computed by:

```
min   −J•X          (J = all-ones matrix; negated in file as +J)
s.t.  Xᵢᵢ = 1       for i = 1..5
      Xᵢⱼ = 0       for each edge (i,j) of C₅
      X ⪰ 0
```

In SDPLR format (m=6 constraints, 1 block of size 5):

```
6
1
5
0.0 0.0 0.0 0.0 0.0 1.0
-1.0
0 1 l 1
-1.0
1.0
1.0
1.0
1.0
1.0
1 1 s 1
1 1 1.0
2 1 s 1
2 2 1.0
3 1 s 1
3 3 1.0
4 1 s 1
4 4 1.0
5 1 s 1
5 5 1.0
6 1 s 5
1 1 1.0
2 2 1.0
3 3 1.0
4 4 1.0
5 5 1.0
```

The objective block (entry 0) uses low-rank format: B = ones(5,1), D = [−1], giving
BDBᵀ = −J. SDPLR negates this on read, so C_internal = +J, and min −J•X over X with
diagonal 1 gives the theta number. Constraints 1–5 enforce Xᵢᵢ = 1 (sparse, one entry
each); constraint 6 enforces the five edge zeros using a 5×5 diagonal identity block.
