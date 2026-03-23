#include "myinclude.h"
#ifdef __MEX
#include "mex.h"
#endif

/* #ifdef __MEX */
/* #undef exit */
/* #define exit(er) mexWarnMsgTxt("SDPLR Error\n"); return mxGetNaN(); */
/* #endif */


size_t simple_Stimesvec_block(double* out, double* in)
{
  // This routine is called by ARPACK, which assumes
  // out and in are numbered from 0

  Stimesmat(global_data, global_data->S + global_data->XS_blkptr[global_blk] - 1, global_data->y, in - 1, out - 1, global_data->blksz[global_blk], 1, global_blk);

  return 0;
}

int Smineval(problemdata* d, double* eval)
{
  int problem, ct, i, k;
  double *blkevals;

  problem = 0;

  *eval = 1.0e10;

  ct = 0;
  for(k = 1; k <= d->numblk; k++)
    if(d->blktype[k] == SDPBLK) ct++;
    else if(d->blktype[k] == DIAGBLK) ct += d->blksz[k];

  MYCALLOC(blkevals, double, ct+1);

  problem = Sblockmineval(d, blkevals);

  for(i = 1; i <= ct; i++)
    *eval = mymin(*eval, blkevals[i]);

  MYFREE(blkevals);

  return problem;
}

int Sblockmineval(problemdata* d, double* blkevals)
{
  int problem=0;
  size_t ct, i, k, nev, maxitr, printlevel;
  char which[3];
  double eval;
  size_t maxblksz, info, dimwork;
  char uplo, jobz;
  double *work, *Scopy, *evals;

  // Note this function overwrites S!

  
  global_data = d;
  nev = 1;
  strcpy(which, "SA\0");
  maxitr = 500;
  printlevel = 0;


  // If necessary, allocate workspace for dsyev_
  maxblksz = 0;
  for(k = 1; k <= d->numblk; k++)
    if(d->blktype[k] == SDPBLK && d->XS_blksto[k] == DENSE)
      maxblksz = mymaxint(maxblksz, d->blksz[k]);
  if(maxblksz > 0) {
    dimwork = mymaxint(1, 3*maxblksz - 1);
    MYCALLOC(Scopy, double, maxblksz*maxblksz + 1);
    MYCALLOC(work, double, dimwork + 1);
    MYCALLOC(evals, double, maxblksz + 1);
  }
  else { work = Scopy = evals = NULL; }

  ct = 0;

  for(k = 1; k <= d->numblk; k++) {

    if(d->blktype[k] == SDPBLK && d->XS_blksto[k] == SPARSE) {
      
      /* Sparse SDP blocks: return sentinel value (ARPACK support removed) */
      eval = -1.0e10;

      blkevals[++ct] = eval;

    }
    else if(d->blktype[k] == SDPBLK && d->XS_blksto[k] == DENSE) {

        jobz = 'n'; uplo = 'l';
        EASYDCOPY(d->blksz[k]*d->blksz[k], d->S + d->XS_blkptr[k] - 1, Scopy);
        dsyev_(&jobz, &uplo, &(d->blksz[k]), Scopy + 1, &(d->blksz[k]), evals + 1, work + 1, &dimwork, &info);
        if((int)info != 0) { printf("Eigenvalue computation failed.\n"); exit(1); }
        blkevals[++ct] = evals[1]; 

    }
    else if(d->blktype[k] == DIAGBLK) {

      for(i = 1; i <= d->blksz[k]; i++)
        blkevals[++ct] = d->S[d->XS_blkptr[k] - 1 + i];

    }

  }

  // If necessary, deallocate workspace used for dsyev_
  if(maxblksz > 0) {
    MYFREE(Scopy);
    MYFREE(work);
    MYFREE(evals);
  }

  return problem;
}

// double dualbound(problemdata* data)
// {
//   size_t problem;
//   double eval;

//   EASYDCOPY(data->m, data->lambda, data->S[1]->y);
//   problem = Smineval(data, &eval);
//  
//   return EASYDDOT(data->m, data->b, data->S[1]->y) - data->evaladj*mymin(eval, 0.0);

// }


