#!/usr/bin/env bash
# configure.sh — detect LAPACK/BLAS and write Makefile.inc for SDPLR
#
# Usage:  ./configure.sh [--help]
#
# Probes common installation paths for LAPACK and BLAS libraries, then
# writes Makefile.inc with the correct LIB_DIRS so that 'make' works
# without manual editing.
#
# Supported platforms: Linux (Debian/Ubuntu, Fedora/RHEL, Arch),
#                      macOS (Homebrew, Accelerate framework).
# For MinGW/Windows use Makefile.inc.mingw as a starting point instead.

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()  { printf '  %s\n'    "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
die()   { printf '\nError: %s\n' "$*" >&2; exit 1; }

# Find a shared or static library by name under a list of candidate dirs.
# Prints the first directory that contains libNAME.so*, libNAME.dylib, or
# libNAME.a; prints nothing if not found.
find_lib() {
    local name="$1"; shift
    local dir f
    for dir in "$@"; do
        [ -d "$dir" ] || continue
        for f in "$dir"/lib${name}.so* \
                 "$dir"/lib${name}.dylib \
                 "$dir"/lib${name}.a; do
            # The glob above may be unexpanded (no match); -e checks the actual path
            [ -e "$f" ] && printf '%s' "$dir" && return 0
        done
    done
    return 1
}

# Check if a linker-ready .so symlink exists for a library (lib<name>.so).
# If only versioned files (lib<name>.so.N) exist, create a local symlink in
# $LOCALLIB_DIR so the linker can resolve -l<name>.
LOCALLIB_DIR="$(pwd)/locallib"
ensure_linker_symlink() {
    local name="$1"
    local libdir="$2"
    [ -z "$libdir" ] && return 0
    # If a bare .so symlink already exists, nothing to do
    [ -e "$libdir/lib${name}.so" ] && return 0
    # Find the best versioned file to point at
    local versioned
    versioned=$(ls "$libdir"/lib${name}.so.* 2>/dev/null | sort -V | tail -1 || true)
    [ -z "$versioned" ] && return 0
    mkdir -p "$LOCALLIB_DIR"
    ln -sf "$versioned" "$LOCALLIB_DIR/lib${name}.so"
    info "Created symlink: $LOCALLIB_DIR/lib${name}.so -> $versioned"
}

# ── candidate search paths ────────────────────────────────────────────────────

COMMON_DIRS=(
    /usr/lib
    /usr/lib64
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu
    /usr/lib/arm-linux-gnueabihf
    /usr/lib/i386-linux-gnu
    /usr/local/lib
    /usr/local/lib64
    /opt/homebrew/lib          # macOS Homebrew (Apple Silicon)
    /usr/local/opt/lapack/lib  # macOS Homebrew (Intel)
    /usr/local/opt/openblas/lib
    /System/Library/Frameworks # macOS Accelerate (detected separately)
)

# Also honour pkg-config if available
PKG_LAPACK_DIR=""
PKG_BLAS_DIR=""
if command -v pkg-config >/dev/null 2>&1; then
    PKG_LAPACK_DIR=$(pkg-config --variable=libdir lapack 2>/dev/null || true)
    PKG_BLAS_DIR=$(pkg-config --variable=libdir blas   2>/dev/null || true)
fi

# ── platform detection ────────────────────────────────────────────────────────

OS="$(uname -s)"
CC_DEFAULT="gcc"
EXTRA_LIBS="-lgfortran -lm"
LAPACK_LIB="-llapack"
BLAS_LIB="-lblas"

echo ""
echo "=== SDPLR configure.sh ==="
echo ""
info "Platform: $OS"

# macOS Accelerate framework (ships with the OS, no separate install needed)
USE_ACCELERATE=0
if [ "$OS" = "Darwin" ]; then
    if xcrun --show-sdk-path >/dev/null 2>&1 || [ -d /System/Library/Frameworks/Accelerate.framework ]; then
        USE_ACCELERATE=1
        info "macOS detected — will try Accelerate framework"
    fi
    # gfortran may not be present on macOS; tolerate its absence
    if ! command -v gfortran >/dev/null 2>&1; then
        EXTRA_LIBS="-lm"
        warn "gfortran not found; omitting -lgfortran (may cause link errors with reference BLAS/LAPACK)"
    fi
fi

# ── locate LAPACK ─────────────────────────────────────────────────────────────

echo ""
info "Searching for LAPACK..."

LAPACK_LIB_DIR=""

if [ "$USE_ACCELERATE" -eq 1 ]; then
    # Accelerate bundles both LAPACK and BLAS
    LAPACK_LIB="-framework Accelerate"
    BLAS_LIB=""
    LAPACK_LIB_DIR=""
    BLAS_LIB_DIR=""
    ok "Using macOS Accelerate framework"
else
    # Try pkg-config result first, then common dirs
    SEARCH_DIRS=()
    [ -n "$PKG_LAPACK_DIR" ] && SEARCH_DIRS+=("$PKG_LAPACK_DIR")
    SEARCH_DIRS+=("${COMMON_DIRS[@]}")

    if LAPACK_LIB_DIR=$(find_lib lapack "${SEARCH_DIRS[@]}"); then
        ok "Found LAPACK in: $LAPACK_LIB_DIR"
        ensure_linker_symlink lapack "$LAPACK_LIB_DIR"
    else
        warn "Could not find liblapack; leaving LAPACK_LIB_DIR empty (may fail at link time)"
        warn "Install with:  sudo apt-get install liblapack-dev   (Debian/Ubuntu)"
        warn "               sudo dnf install lapack-devel         (Fedora/RHEL)"
        warn "               brew install lapack                   (macOS)"
    fi

    # ── locate BLAS ───────────────────────────────────────────────────────────

    echo ""
    info "Searching for BLAS..."

    BLAS_LIB_DIR=""
    SEARCH_DIRS=()
    [ -n "$PKG_BLAS_DIR" ] && SEARCH_DIRS+=("$PKG_BLAS_DIR")
    SEARCH_DIRS+=("${COMMON_DIRS[@]}")

    # Prefer OpenBLAS if available (often faster than reference BLAS)
    if BLAS_LIB_DIR=$(find_lib openblas "${SEARCH_DIRS[@]}"); then
        BLAS_LIB="-lopenblas"
        ok "Found OpenBLAS in: $BLAS_LIB_DIR  (using -lopenblas)"
        ensure_linker_symlink openblas "$BLAS_LIB_DIR"
    elif BLAS_LIB_DIR=$(find_lib blas "${SEARCH_DIRS[@]}"); then
        ok "Found BLAS in: $BLAS_LIB_DIR"
        ensure_linker_symlink blas "$BLAS_LIB_DIR"
    else
        warn "Could not find libblas or libopenblas; leaving BLAS_LIB_DIR empty"
        warn "Install with:  sudo apt-get install libblas-dev      (Debian/Ubuntu)"
        warn "               sudo dnf install blas-devel            (Fedora/RHEL)"
        warn "               brew install openblas                  (macOS)"
    fi
fi

# ── verify gfortran (Linux) ───────────────────────────────────────────────────

echo ""
info "Checking for gfortran runtime..."
GFORTRAN_DIR=""
SEARCH_DIRS=("${COMMON_DIRS[@]}")
if GFORTRAN_DIR=$(find_lib gfortran "${SEARCH_DIRS[@]}"); then
    ok "Found libgfortran in: $GFORTRAN_DIR"
    ensure_linker_symlink gfortran "$GFORTRAN_DIR"
    # Add gfortran dir to LIB_DIRS search if it differs from the others
    if [ "$GFORTRAN_DIR" != "$LAPACK_LIB_DIR" ] && [ "$GFORTRAN_DIR" != "$BLAS_LIB_DIR" ]; then
        EXTRA_LIB_DIR="$GFORTRAN_DIR"
    else
        EXTRA_LIB_DIR=""
    fi
else
    warn "libgfortran not found in standard paths — link may fail if using Fortran BLAS/LAPACK"
    EXTRA_LIB_DIR=""
fi

# ── build LIB_DIRS string ─────────────────────────────────────────────────────

build_lib_dirs() {
    local dirs=()
    # Always list locallib first if we created any symlinks there
    if [ -d "$LOCALLIB_DIR" ] && ls "$LOCALLIB_DIR"/*.so 2>/dev/null | grep -q .; then
        dirs+=("$LOCALLIB_DIR")
    fi
    for d in "$LAPACK_LIB_DIR" "$BLAS_LIB_DIR" "${EXTRA_LIB_DIR:-}"; do
        [ -z "$d" ] && continue
        # Deduplicate
        local already=0
        local existing
        for existing in "${dirs[@]+"${dirs[@]}"}"; do
            [ "$existing" = "$d" ] && already=1 && break
        done
        [ "$already" -eq 0 ] && dirs+=("$d")
    done
    local result=""
    for d in "${dirs[@]+"${dirs[@]}"}"; do
        result="$result -L$d"
    done
    printf '%s' "${result# }"  # strip leading space
}

LIB_DIRS_VALUE=$(build_lib_dirs)

# For Accelerate, no -L flags needed; framework flag goes into LIBS
if [ "$USE_ACCELERATE" -eq 1 ]; then
    LIB_DIRS_VALUE=""
    LIBS_VALUE="-lgsl $LAPACK_LIB $EXTRA_LIBS"
elif [ -n "$BLAS_LIB" ]; then
    LIBS_VALUE="-lgsl $LAPACK_LIB $BLAS_LIB $EXTRA_LIBS"
else
    LIBS_VALUE="-lgsl $LAPACK_LIB $EXTRA_LIBS"
fi

# ── write Makefile.inc ────────────────────────────────────────────────────────

MAKEFILE_INC="Makefile.inc"

cat > "$MAKEFILE_INC" <<MFEOF
# Makefile.inc — generated by configure.sh on $(date)
# Re-run ./configure.sh to regenerate, or edit manually.
#
# NOTE: Paths are absolute so this works regardless of which subdirectory
# make is invoked from.

################################
# LAPACK directory and library #
################################

# If a relative path is given next, it should be relative from the
# source/ subdirectory.

LAPACK_LIB_DIR=${LAPACK_LIB_DIR}
LAPACK_LIB= ${LAPACK_LIB}

##############################
# BLAS directory and library #
##############################

# If a relative path is given next, it should be relative from the
# source/ subdirectory.

BLAS_LIB_DIR=${BLAS_LIB_DIR}
BLAS_LIB= ${BLAS_LIB}

####################
# Main definitions #
####################

CC       = ${CC_DEFAULT}
CFLAGS   = -O3
LIB_DIRS = ${LIB_DIRS_VALUE}
LIBS     = ${LIBS_VALUE}
MFEOF

echo ""
ok "Wrote $MAKEFILE_INC"
echo ""
echo "=== Configuration summary ==="
echo ""
printf '  %-20s %s\n' "LAPACK_LIB_DIR:"  "${LAPACK_LIB_DIR:-(system default)}"
printf '  %-20s %s\n' "LAPACK_LIB:"      "$LAPACK_LIB"
printf '  %-20s %s\n' "BLAS_LIB_DIR:"    "${BLAS_LIB_DIR:-(system default)}"
printf '  %-20s %s\n' "BLAS_LIB:"        "${BLAS_LIB:-(none, using Accelerate)}"
printf '  %-20s %s\n' "LIB_DIRS:"        "${LIB_DIRS_VALUE:-(none)}"
printf '  %-20s %s\n' "LIBS:"            "$LIBS_VALUE"
echo ""
echo "Now run:  make"
echo ""
