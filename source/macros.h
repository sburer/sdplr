#ifndef __WIN32
#define _isnan isnan
#endif

#ifdef __MEX
#define printf mexPrintf
#endif

// #ifndef __MEX
// #define size_t int
// #endif

#define MYCALLOC(VAR,TYPE,SIZE) do { \
    (VAR) = (TYPE*)calloc((SIZE), sizeof(TYPE)); \
    if ((VAR) == NULL) { \
        printf("Error: memory allocation of %zu bytes failed (%s:%d)\n", \
               (size_t)(SIZE) * sizeof(TYPE), __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)
#define MYFREE(VAR) free(VAR);

#define mymaxint(A, B) ((A) > (B) ? (A) : (B))
// #define mymin(A, B) ((A) < (B) ? (A) : (B))
#define mymax(A, B) ((A) - (B) > DBL_EPSILON ? (A) : (B))
#define mymin(A, B) ((B) - (A) > DBL_EPSILON ? (A) : (B))

#define SMATIND(I,J,DIM) (J-1)*DIM + I
#define LMATIND(I,J,DIM) DIM*(DIM+1)/2 -(DIM-J+1)*(DIM-J+2)/2 + I - J + 1

// INDEXING CONVENTION (internal / 1-based zone):
//   All solver-internal arrays (R, lambda, b, blksz, blktype, X, S, y, vio,
//   rank, maxrank, G, D, lbfgs vecs, …) are accessed with 1-based indices.
//   Entry points (main.c, mexsdplr.c) allocate these arrays 0-based, then
//   pass pointer-decremented versions (e.g. R-1, lambda-1, blksz-1) so that
//   index [1] lands on the first element.  Index [0] is always unused padding.
//
//   Consequence for EASY* macros: each macro adds +1 to every pointer before
//   calling the underlying BLAS routine, so callers must pass the base pointer
//   (not base+1) and must have allocated at least DIM+1 elements.
//
//   CA* data arrays (CAent, CArow, CAcol, CAinfo_*) are the exception: they
//   use genuine 0-based indexing throughout and are never pointer-decremented.
#define EASYDAXPY(DIM,SCAL,X,Y)   mydaxpy(DIM,SCAL,X+1,1,Y+1,1)
#define EASYDCOPY(DIM,X,Y)        mydcopy(DIM,X+1,1,Y+1,1)
#define EASYDDOT(DIM,X,Y)         myddot(DIM,X+1,1,Y+1,1)
#define EASYDNRM2(DIM,X)          mydnrm2(DIM,X+1,1)
#define EASYDSCAL(DIM,SCAL,X)     mydscal(DIM,SCAL,X+1,1)
#define ZEROVEC(X,DIM)            mydscal(DIM,0.0,X+1,1)

// RANDOM: controls srand seed for R initialisation.
//   0 = fixed seed 925 (reproducible; default)
//   1 = time-based seed (non-deterministic)
#define RANDOM 0

#define SDPBLK  's'
#define DIAGBLK 'd'
#define SPARSE  's'
#define DENSE   'd'

#define DATABLOCKIND(DATA,BLOCK,NUMBLOCK) ((DATA+1)-1)*NUMBLOCK + BLOCK - 1

#ifdef __WIN32
#ifndef __MINGW32__
#define dsyr_ dsyr
#define dsyrk_ dsyrk
#define dsyr2k_ dsyr2k
#define dgemm_ dgemm
#define dsymm_ dsymm
#define idamax_ idamax
#define dsyev_ dsyev
#define dgeqp3_ dgeqp3
#define daxpy_ daxpy
#define dcopy_ dcopy
#define ddot_ ddot
#define dnrm2_ dnrm2
#define dscal_ dscal
#endif
#endif


#ifdef __MEX
#undef exit
#define exit(er) mexErrMsgTxt("SDPLR Error\n");
#endif
