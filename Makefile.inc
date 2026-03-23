# Makefile.inc — local build configuration for SDPLR
#
# The easiest way to set this up is to run:
#
#   ./configure.sh
#
# That script detects your LAPACK/BLAS installation and writes this file
# automatically.  Alternatively, copy the platform example that best
# matches your system (Makefile.inc.linux, Makefile.inc.mac,
# Makefile.inc.mingw) and edit as needed.
#
# NOTE: Paths for LAPACK_LIB_DIR and BLAS_LIB_DIR should be absolute,
# or relative to the source/ subdirectory.
#
# The defaults below assume LAPACK and BLAS are on the system library
# path (e.g., /usr/lib) and no extra -L flag is needed.

################################
# LAPACK directory and library #
################################

# If a relative path is given next, it should be relative from the
# source/ subdirectory.

LAPACK_LIB_DIR=
LAPACK_LIB= -llapack

##############################
# BLAS directory and library #
##############################

# If a relative path is given next, it should be relative from the
# source/ subdirectory.

BLAS_LIB_DIR=
BLAS_LIB= -lblas

####################
# Main definitions #
####################

CC       = gcc
CFLAGS   = -O3
LIB_DIRS = -L$(LAPACK_LIB_DIR) -L$(BLAS_LIB_DIR)
LIBS     = -lgsl $(LAPACK_LIB) $(BLAS_LIB) -lgfortran -lm
