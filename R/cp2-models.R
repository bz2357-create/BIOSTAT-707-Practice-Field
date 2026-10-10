cp2_lambda <- 10^seq(0,-4,length.out=30)
cp2_tolerance <- 1e-10
cp2_choose_lambda <- function(lambda,means) {
 max(lambda[means>=max(means)-cp2_tolerance])
}
cp2_choose_forest <- function(grid) {
 eligible <- which(grid$mean_auc>=max(grid$mean_auc)-cp2_tolerance)
 # sqrt always gives the smaller mtry for the broad CP2 design.
 eligible[order(-grid$node[eligible],match(grid$mtry_rule[eligible],c('sqrt','third')))][1]
}
cp2_mtry <- function(rule,p) as.integer(max(1L,min(p,if (rule=='sqrt') floor(sqrt(p)) else floor(p/3))))
cp2_enet_path <- function(x,y,lambda) {
 fit <- glmnet::glmnet(x,factor(y,levels=0:1),family='binomial',alpha=.5,
  lambda=sort(lambda,decreasing=TRUE),standardize=FALSE,
  control=list(fdev=0,devmax=1,maxit=100000))
 if (fit$jerr!=0 || length(fit$lambda)!=length(lambda)) stop('Incomplete/nonconverged elastic-net path')
 fit
}
cp2_forest_fit <- function(x,y,hp,seed) {
 ranger::ranger(x=x,y=factor(y,levels=c(0,1)),probability=TRUE,
  num.trees=hp$trees,mtry=cp2_mtry(hp$mtry_rule,ncol(x)),min.node.size=hp$node,
  splitrule='gini',replace=TRUE,sample.fraction=1,importance='none',
  seed=seed,num.threads=1,write.forest=TRUE,na.action='na.fail')
}
cp2_fit_model <- function(family,x,y,predictors,hp,seed) {
 stopifnot(length(y)==nrow(x),all(y %in% c(0,1)),length(unique(y))==2)
 pp <- cp2_fit_preprocess(x,predictors,scale=family=='enet',log_counts=family=='gam')
 design <- cp2_apply_preprocess(pp,x); terms <- NULL; diagnostics <- NULL
 if (family=='enet') {
  # Fit the frozen whole path, then select the tuned lambda, not a lone-lambda approximation.
  fit <- cp2_enet_path(design,y,sort(unique(c(cp2_lambda,hp$lambda)),decreasing=TRUE))
 } else if (family=='forest') {
  fit <- cp2_forest_fit(design,y,hp,seed)
  hp$mtry <- cp2_mtry(hp$mtry_rule,ncol(design))
 } else if (family=='gam') {
  smooth_vars <- setdiff(predictors,c('Gender','ICUType','MechVent_h24_48_documented_1',
                                      grep('_count$',predictors,value=TRUE)))
  term_list <- lapply(colnames(design),function(n) {
   distinct <- length(unique(design[,n]))
   smooth <- n %in% smooth_vars && distinct>=hp$k
   data.table(column=n,distinct=distinct,
    kind=if (smooth) 'smooth' else if (n %in% smooth_vars) 'linear: fewer than 5 distinct training values' else 'parametric',
    term=if (smooth) paste0('s(',n,',k=',hp$k,')') else n)
  })
  terms <- rbindlist(term_list)
  formula <- as.formula(paste('death ~',paste(terms$term,collapse=' + ')),env=asNamespace('mgcv'))
  d <- as.data.frame(design); d$death <- y
  fit <- mgcv::gam(formula,data=d,family=binomial(),method='REML',na.action=na.fail)
  if (!isTRUE(fit$converged)) stop('GAM did not converge')
  if (!is.null(fit$outer.info$conv) && fit$outer.info$conv!='full convergence') stop('GAM REML optimization did not converge')
  set.seed(seed); check <- mgcv::k.check(fit,subsample=5000,n.rep=200)
  diagnostics <- as.data.table(check,keep.rownames='term')
 } else stop('Unknown family')
 list(family=family,model=fit,preprocess=pp,hyperparameters=hp,seed=seed,
      terms=terms,diagnostics=diagnostics,event=1L)
}
cp2_predict <- function(bundle,x) {
 design <- cp2_apply_preprocess(bundle$preprocess,x)
 pred <- switch(bundle$family,
  enet={
   # Loading the namespace registers the binomial lognet prediction method after RDS reload.
   loadNamespace('glmnet')
   as.numeric(predict(bundle$model,newx=design,s=bundle$hyperparameters$lambda,type='response'))
  },
  gam=as.numeric(mgcv::predict.gam(bundle$model,newdata=as.data.frame(design),type='response')),
  forest={
   loadNamespace('ranger')
   prob <- predict(bundle$model,data=design,num.threads=1)$predictions
   if (!'1' %in% colnames(prob)) stop('Death probability column absent')
   as.numeric(prob[,'1'])
  },stop('Unknown saved family'))
 stopifnot(length(pred)==nrow(x),all(is.finite(pred)),all(pred>=0 & pred<=1));pred
}
cp2_tune_enet <- function(x,y,ids,inner,predictors,lambda=cp2_lambda,context='') {
 scores <- list();audit <- list()
 for (j in sort(unique(inner))) {
  tr <- which(inner!=j);va <- which(inner==j)
  pp <- cp2_fit_preprocess(x[tr,,drop=FALSE],predictors,TRUE)
  a <- cp2_apply_preprocess(pp,x[tr,,drop=FALSE]); b <- cp2_apply_preprocess(pp,x[va,,drop=FALSE])
  fit <- cp2_enet_path(a,y[tr],lambda)
  pred <- predict(fit,newx=b,s=lambda,type='response')
  scores[[j]] <- data.table(context=context,inner_fold=j,lambda=lambda,
    auc=vapply(seq_along(lambda),function(i) cp2_auc(y[va],pred[,i]),numeric(1)))
  audit[[j]] <- list(context=context,inner_fold=j,training_ids=ids[tr],assessment_ids=ids[va],preprocess=pp)
 }
 scores <- rbindlist(scores); means <- scores[,.(mean_auc=mean(auc)),by=lambda]
 selected <- cp2_choose_lambda(means$lambda,means$mean_auc)
 list(hyperparameters=list(lambda=selected,alpha=.5),scores=scores,means=means,audit=audit,
      boundary=selected %in% range(lambda))
}
cp2_tune_forest <- function(x,y,ids,inner,predictors,seed,trees=500,context='') {
 grid <- CJ(mtry_rule=c('sqrt','third'),node=c(5L,20L,50L))
 scores <- list();audit <- list()
 for (j in sort(unique(inner))) {
  tr <- which(inner!=j);va <- which(inner==j)
  pp <- cp2_fit_preprocess(x[tr,,drop=FALSE],predictors,FALSE)
  a <- cp2_apply_preprocess(pp,x[tr,,drop=FALSE]); b <- cp2_apply_preprocess(pp,x[va,,drop=FALSE])
  g <- copy(grid);g[,mtry:=vapply(mtry_rule,cp2_mtry,integer(1),p=ncol(a))]
  # Broad CP2 p makes the rules distinct; keep alias rows when deduplicating fits.
  predictions <- list()
  for (i in seq_len(nrow(g))) {
   key <- paste(g$mtry[i],g$node[i],sep='_')
   if (is.null(predictions[[key]])) {
    hp <- list(mtry_rule=g$mtry_rule[i],node=g$node[i],trees=trees)
    fit <- cp2_forest_fit(a,y[tr],hp,seed+j)
    prob <- predict(fit,data=b,num.threads=1)$predictions
    if (!'1' %in% colnames(prob)) stop('Death probability column absent')
    predictions[[key]] <- prob[,'1']
   }
   scores[[length(scores)+1L]] <- data.table(context=context,inner_fold=j,
    mtry_rule=g$mtry_rule[i],mtry=g$mtry[i],p=ncol(a),node=g$node[i],trees=trees,
    auc=cp2_auc(y[va],predictions[[key]]))
  }
  audit[[j]] <- list(context=context,inner_fold=j,training_ids=ids[tr],assessment_ids=ids[va],preprocess=pp)
 }
 scores <- rbindlist(scores)
 means <- scores[,.(mean_auc=mean(auc)),by=.(mtry_rule,node)]
 best <- cp2_choose_forest(means)
 list(hyperparameters=list(mtry_rule=means$mtry_rule[best],node=means$node[best],trees=trees),
      scores=scores,means=means,audit=audit)
}
