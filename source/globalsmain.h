// global variables

//! \brief Global variable that keeps track of the current SDP block during
//! eigenvalue computation in simple_Stimesvec_block (eigen.c).

// #ifndef __MEX
// #define size_t int
// #endif

size_t           global_blk;

//! \brief Global pointer to the problemdata structure, used by
//! simple_Stimesvec_block (eigen.c) during eigenvalue computation.

problemdata  *global_data;

//! \brief Global variable that is used as temporary space during data
//! operation \ref Aoper of \ref dataoper.c. Specifically used to help
//! with low-rank data matrices.
//!
//! The function \ref Aoper requires temporary space for operations such
//! as \f$ RR^T \f$ and \f$ RD^T \f$, where \f$ R \f$ is the variable
//! and \f$ D \f$ is the direction. This global variable provides that
//! space, and since it is global, it only has to be allocated once.
//! This is in hopes of improving performance as \ref Aoper is called
//! many times.

double       *global_UtB;

//! \brief Global variable that is used as temporary space during data
//! operation \ref Aoper of \ref dataoper.c. Specifically used to help
//! with low-rank data matrices.
//!
//! See \ref global_UtB for full explanation.

double       *global_VtB;

//! \brief Global variable that is used as temporary space during the
//! exact linesearch of \ref linesearch.c.
//!
//! During \ref linesearch, functions such as \ref Aoper require
//! temporary space for operations such as \f$ RR^T \f$ and \f$ RD^T \f$,
//! where \f$ R \f$ is the variable and \f$ D \f$ is the direction. This
//! global variable provides that space, and since it is global, it only
//! has to be allocated once. This is in hopes of improving performance
//! as \ref linesearch and \ref Aoper are called many times.
//! 
//! The size of this variable is related to the size of the XS
//! structures in \ref problemdata.

double *global_UVt;

//! \brief Global variable that is used as temporary space during the
//! exact linesearch of \ref linesearch.c.
//!
//! See \ref global_UVt for full explanation.

double *global_ARD;

//! \brief Global variable that is used as temporary space during the
//! exact linesearch of \ref linesearch.c.
//!
//! See \ref global_UVt for full explanation.

double *global_ADD;
