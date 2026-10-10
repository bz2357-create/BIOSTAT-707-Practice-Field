# No outcome or assessment rows are accepted by fit_preprocess.
cp2_fit_preprocess <- function(x,predictors,scale=FALSE,log_counts=FALSE) {
 if (any(predictors %in% cp2_forbidden) || anyDuplicated(predictors)) stop('Forbidden/duplicate predictor')
 if (!all(predictors %in% names(x)) || !nrow(x)) stop('Missing training schema/rows')
 x <- as.data.frame(x)[,predictors,drop=FALSE]
 numeric_names <- setdiff(predictors,c('Gender','ICUType'))
 if (any(!vapply(x[numeric_names],is.numeric,logical(1)))) stop('Non-numeric measurement')
 if (any(vapply(x[numeric_names],function(v) any(is.infinite(v)|is.nan(v)),logical(1)))) stop('Nonfinite measurement')
 medians <- vapply(x[numeric_names],function(v) if (all(is.na(v))) NA_real_ else median(v,na.rm=TRUE),numeric(1))
 categories <- list()
 for (n in intersect(predictors,c('Gender','ICUType'))) {
  v <- as.character(x[[n]]); valid <- if (n=='Gender') c('0','1') else as.character(1:4)
  if (any(!is.na(v) & !v %in% valid)) stop('Invalid training category')
  observed <- sort(unique(v[!is.na(v)]))
  tab <- table(factor(v,levels=observed)); mode <- if (length(observed)) observed[which.max(tab)] else 'missing'
  lev <- c(observed,if (anyNA(v) || !length(observed)) 'missing')
  categories[[n]] <- list(levels=lev,fallback=if ('missing' %in% lev) 'missing' else mode,
                          reference=lev[1])
 }
 state <- list(predictors=predictors,medians=medians,categories=categories,scale=scale,
               log_counts=log_counts,columns=NULL,means=NULL,sds=NULL)
 raw <- cp2_raw_design(state,x)
 variance <- vapply(seq_len(ncol(raw)),function(j) stats::sd(raw[,j]),numeric(1))
 retained <- colnames(raw)[is.finite(variance) & variance>0]
 if (!length(retained)) stop('No usable design columns')
 state$columns <- retained
 state$means <- if (scale) colMeans(raw[,retained,drop=FALSE]) else setNames(rep(0,length(retained)),retained)
 state$sds <- if (scale) variance[match(retained,colnames(raw))] else rep(1,length(retained))
 names(state$sds) <- retained
 dropped_missing <- names(medians)[is.na(medians)]
 dropped_constant <- setdiff(colnames(raw),retained)
 state$dropped <- data.table(column=c(dropped_missing,dropped_constant),
  reason=c(rep('100% missing in training',length(dropped_missing)),
           rep('zero variance after training imputation/encoding',length(dropped_constant))))
 state
}
cp2_raw_design <- function(state,x) {
 if (!all(state$predictors %in% names(x))) stop('Missing prediction schema')
 x <- as.data.frame(x); out <- list()
 for (n in state$predictors) {
  if (n %in% names(state$categories)) {
   rule <- state$categories[[n]]; v <- as.character(x[[n]])
   v[is.na(v) | !v %in% rule$levels] <- rule$fallback
   for (lev in setdiff(rule$levels,rule$reference)) out[[paste0(n,'__',lev)]] <- as.numeric(v==lev)
  } else if (!is.na(state$medians[n])) {
   v <- x[[n]]
   if (!is.numeric(v) || any(is.infinite(v)|is.nan(v))) stop('Invalid numeric prediction input')
   v[is.na(v)] <- state$medians[n]
   if (state$log_counts && grepl('_count$',n)) {
    if (any(v<0)) stop('Negative count'); v <- log1p(v)
   }
   out[[n]] <- v
  }
 }
 if (!length(out)) return(matrix(numeric(),nrow(x),0))
 m <- do.call(cbind,out); storage.mode(m) <- 'double'; m
}
cp2_apply_preprocess <- function(state,x) {
 raw <- cp2_raw_design(state,x)
 m <- raw[,state$columns,drop=FALSE]
 m <- sweep(sweep(m,2,state$means,'-'),2,state$sds,'/')
 stopifnot(nrow(m)==nrow(x),identical(colnames(m),state$columns),all(is.finite(m)))
 m
}
cp2_folds <- function(ids,y,k,seed) {
 if (length(ids)!=length(y) || anyNA(ids) || anyDuplicated(ids) || anyNA(y) ||
     !all(y %in% c(0,1)) || min(table(factor(y,levels=0:1)))<k) stop('Invalid stratified fold inputs')
 set.seed(seed); folds <- integer(length(y))
 for (event in 0:1) {
  idx <- which(y==event); idx <- idx[order(ids[idx])]
  folds[idx] <- sample(rep(seq_len(k),length.out=length(idx)))
 }
 stopifnot(all(table(folds,y)>0)); folds
}
cp2_auc <- function(y,score) {
 if (length(y)!=length(score) || anyNA(y) || any(!is.finite(score)) ||
     !all(y %in% c(0,1)) || length(unique(y))!=2) stop('Invalid AUROC input')
 n1 <- sum(y==1); n0 <- sum(y==0)
 (sum(rank(score,ties.method='average')[y==1])-n1*(n1+1)/2)/(n1*n0)
}
