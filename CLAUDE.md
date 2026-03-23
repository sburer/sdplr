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

Edit `Makefile.inc` (or use the platform-specific variants) to set paths and compiler flags:

```
LAPACK_LIB_DIR=   # directory containing liblapack (blank = system default)
LAPACK_LIB= -llapack
BLAS_LIB_DIR=
BLAS_LIB= -lblas
CC       = gcc
CFLAGS   = -O3
```

Platform-specific templates: `Makefile.inc.linux`, `Makefile.inc.mac`, `Makefile.inc.mingw`. Copy the appropriate one to `Makefile.inc` before building.

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
```

This produces `mexsdplr.mex*` which is called by `sdplr.m`.

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

# Generate a default params file
./sdplr gen_params
```

### Input Formats

Controlled by the `Input type` parameter in `sdplr.params`:
- `1` — **SDPA sparse format** (`.dat-s`), the default and most common
- `2` — SDPLR native format
- `1000` — raw binary format

Example input files are in `data/`:
- `data/vibra1.dat-s` — SDPA format problem
- `data/gpp100.dat-s.sdplr` — SDPLR format problem
- `data/vibra1.dat-s.out` — expected output for reference

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

## Developer Notes

**Algorithm overview:** The outer loop is an augmented Lagrangian method that penalizes constraint violations while updating dual variables (`lambda`). The penalty parameter `sigma` grows by `sigmafac` when progress stalls. Each inner iteration minimizes the augmented Lagrangian over the low-rank factor `R` using L-BFGS with backtracking line search.

**Rank initialization:** The initial rank for each SDP block is heuristically set to `min(sqrt(2 * nnz_constraints) + 1, block_size)`. See `getstorage()` in `main.c`.

**Dense vs. sparse storage:** Data blocks smaller than `dthresh_dim` or denser than `dthresh_dens` are stored as dense matrices; others use sparse (COO) format. This is decided in `initialize.c`.

**MEX build:** The same `sdplrlib.c` core is compiled for both the standalone binary and the MEX interface. The `__MEX` preprocessor flag enables MATLAB-specific I/O in `main.c` and `sdplrlib.c`.

**Random seed:** The initial point `R` is set using `srand(925)` (fixed seed). To use a random seed instead, uncomment the `srand((unsigned)time(NULL))` line and set `#define RANDOM 1` in `main.c`.

**Output format:** The solution file written by `writeout()` (and read by `readin()`) stores dual variable `lambda` and the low-rank factor `R` per block, plus algorithmic metadata (`majiter`, `iter`, `sigma`, `scale`, etc.).

**License:** GPL v2 (see `COPYING`). The bundled GSL 1.5 subset is also GPL v2.
