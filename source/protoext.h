// external
extern void dgemm_(char*, char*, size_t*, size_t*, size_t*, double*, double*, size_t*, double*, size_t*, double*, double*, size_t*);
extern void dgemv_();
extern void dgeqp3_(size_t*, size_t*, double*, size_t*, size_t*, double*, double*, size_t*, size_t*);
extern void dsymv_();
extern void dsymm_(char*, char*, size_t*, size_t*, double*, double*, size_t*, double*, size_t*, double*, double*, size_t*);
extern void dsyr_(char*, size_t*, double*, double*, size_t*, double*, size_t*);
extern void dsyrk_(char*, char*, size_t*, size_t*, double*, double*, size_t*, double*, double*, size_t*);
extern void dsyr2k_(char*, char*, size_t*, size_t*, double*, double*, size_t*, double*, size_t*, double*, double*, size_t*);
extern void dpotrf_();
extern void dtrsv_();
extern void dtrsm_();
extern void dsaupd_();
extern void dseupd_();
extern void dsyev_(char*, char*, size_t*, double*, size_t*, double*, double*, size_t*, size_t*);
extern void dtrmm_();
extern size_t idamax_(size_t*, double*, size_t*);
extern size_t gsl_poly_solve_cubic(double, double, double, double*, double*, double*);
extern double gsl_poly_eval(double*, size_t, double);
extern size_t daxpy_(size_t*, double*, double*, size_t*, double*, size_t*);
extern size_t dcopy_(size_t*, double*, size_t*, double*, size_t*);
extern double ddot_(size_t*, double*, size_t*, double*, size_t*);
extern double dnrm2_(size_t*, double*, size_t*);
extern size_t dscal_(size_t*, double*, double*, size_t*);

/* extern 
        dgemm_(&transr, &transv, &rk, &(A->lr->ncol), &(A->lr->nrow), &one,
               U + base + 1, &(A->lr->nrow), A->lr->ent + 1, &(A->lr->nrow), &zero,
               global_UtB + 1, &rk); */
/*extern void dgemm_(char *, char *, size_t *, size_t *, size_t *, double *, double *, size_t *, double *b, size_t *, double *, double *, size_t *ldc);*/
