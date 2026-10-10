source('tests/test-cp2.R')
if (file.exists('R/cp2-models.R')) source('R/cp2-models.R')
stopifnot('Model helpers implemented'=exists('cp2_fit_model'))
# Breaks caught: selecting smaller penalties/nodes on ties, survival probabilities,
# global preprocessing in inner CV, missing GAM small-support fallback, reload drift.
stopifnot(cp2_choose_lambda(c(1,.1,.01),c(.7,.7,.6))==1,
 cp2_choose_forest(data.table(mtry_rule=c('third','sqrt','sqrt'),node=c(50,50,5),
 mean_auc=c(.7,.7,.7)))==2)
child_script <- tempfile(fileext='.R')
writeLines(c("library(data.table)",
 "for(f in c('cp2-data','cp2-preprocess','cp2-models')) source(paste0('R/',f,'.R'))",
 "a <- commandArgs(TRUE); b <- readRDS(a[1]); z <- readRDS(a[2])",
 "stopifnot(max(abs(cp2_predict(b,z$x)-z$probability))<1e-12)"),child_script)
set.seed(12); n <- 120
x <- data.frame(Age=runif(n,20,85),Gender=rep(c(0,1),60),ICUType=rep(1:4,30),
 HR_h24_48_mean=rnorm(n,85,15),Temp_h24_48_mean=rnorm(n,37,.8),
 MAP_h24_48_count=sample(0:20,n,TRUE))
y <- as.integer(seq_len(n)%%3==0); ids <- sprintf('%03d',1:n)
x$Age[c(1,4)] <- NA_real_
inn <- cp2_folds(ids,y,3,12)
tune <- cp2_tune_enet(x,y,ids,inn,names(x),lambda=c(.1,.01),context='fixture')
stopifnot(nrow(tune$scores)==6,length(tune$audit)==3)
for (a in tune$audit) {
 idx <- match(a$training_ids,ids)
 stopifnot(!length(intersect(a$training_ids,a$assessment_ids)),
 identical(a$preprocess,cp2_fit_preprocess(x[idx,],names(x),TRUE)))
}
for (family in c('enet','gam','forest')) {
 vars <- if (family=='gam') names(x) else names(x)
 hp <- switch(family,enet=list(lambda=.01),gam=list(k=5),
              forest=list(mtry_rule='sqrt',node=5,trees=30))
 m <- cp2_fit_model(family,x,y,vars,hp,42)
 pred <- cp2_predict(m,x[1:20,])
 stopifnot(length(pred)==20,all(is.finite(pred)),all(pred>=0 & pred<=1))
 f <- tempfile(fileext='.rds');saveRDS(m,f)
 stopifnot(max(abs(cp2_predict(readRDS(f),x[1:20,])-pred))<1e-12)
 fixture_path <- tempfile(fileext='.rds')
 saveRDS(list(x=x[1:20,],probability=pred),fixture_path)
 status <- system2(file.path(R.home(),'bin','Rscript'),
  c('--vanilla',shQuote(child_script),shQuote(f),shQuote(fixture_path)))
 stopifnot(status==0L);unlink(c(f,fixture_path))
 if(family=='forest') {
  xx <- cp2_apply_preprocess(m$preprocess,x[1:20,])
  manual <- predict(m$model,data=xx,num.threads=1)$predictions[,'1']
  stopifnot(identical(pred,as.numeric(manual)))
 }
}
x$Age <- rep(c(20,40,60),40)
g <- cp2_fit_model('gam',x,y,names(x),list(k=5),42)
stopifnot(g$terms[column=='Age',kind]=='linear: fewer than 5 distinct training values',
 !any(vapply(g$model$smooth,function(s) 'Age' %in% s$term,logical(1))))
cat('CP2 real estimator/tuning fixtures passed.\n')
rf <- cp2_tune_forest(x,y,ids,inn,names(x),42,trees=10,context='fixture')
stopifnot(nrow(rf$scores)==18,length(rf$audit)==3)

unlink(child_script)
