# Post-run integration checks. This does not refit models or read CP1 generated tables.
library(data.table)
for(f in c('load-set-a','audit-missingness','build-wide','cp2-data','cp2-preprocess','cp2-models','cp2-run','cp2-plots'))
 source(paste0('R/',f,'.R'))
required <- c('cp2_final_model.rds','cp2_oof_predictions.csv','cp2_outer_folds.csv','cp2_inner_folds.csv',
 'cp2_preprocessing_audit.rds','cp2_prediction_fixture.rds','cp2_performance.csv',
 'cp2_coefficients.png','cp2_stability.png','cp2_gam_Age.png','cp2_gam_HR_h24_48_mean.png',
 'cp2_gam_Temp_h24_48_mean.png','cp2_roc.png','cp2_roc_curve_data.csv','cp2_gam_effect_curves.csv',
 'checkpoint2.html')
stopifnot(all(file.exists(file.path('output',required))),
 all(file.info(file.path('output',required))$size>0))
d <- cp2_data()
o <- fread('output/cp2_oof_predictions.csv',colClasses=list(character='RecordID'))
f <- cp2_folds(d$ids,d$y,5,7072026L)
cp2_validate_oof(o,d$ids,d$y,f)
stopifnot(identical(o$SAPS_I_score,d$benchmarks$SAPS_I_score),identical(o$SOFA_score,d$benchmarks$SOFA_score))
outer <- fread('output/cp2_outer_folds.csv',colClasses=list(character='RecordID'))
stopifnot(identical(outer$RecordID,d$ids),identical(outer$outer_fold,f),identical(outer$outcome,d$y))
inner <- fread('output/cp2_inner_folds.csv',colClasses=list(character='RecordID'))
for(k in 1:5) {
 z <- inner[context==paste0('outer_',k)]
 stopifnot(setequal(z$RecordID,d$ids[f!=k]),!any(z$RecordID %in% d$ids[f==k]),
 all(table(z$inner_fold,d$y[match(z$RecordID,d$ids)])>0))
}
audit <- readRDS('output/cp2_preprocessing_audit.rds'); checked <- 0L
check_state <- function(z) {
 if(!is.null(z$preprocess)) {
  pp <- z$preprocess;tr <- match(z$training_ids,d$ids)
  expected <- cp2_fit_preprocess(d$x[tr,],pp$predictors,pp$scale,pp$log_counts)
  # data.table runtime self-reference pointers do not survive RDS serialization.
  # Compare exact values/attributes after representing the drop table as a frame.
  comparable <- function(p) {p$dropped <- as.data.frame(p$dropped);p}
  stopifnot(!anyNA(tr),!length(intersect(z$training_ids,z$assessment_ids)),
   identical(comparable(pp),comparable(expected)))
  if(startsWith(z$context,'outer_')) {
   k <- as.integer(sub('outer_','',z$context));stopifnot(all(f[tr]!=k))
  }
  checked <<- checked+1L
 } else for(a in z) check_state(a)
}
for(z in audit) check_state(z)
stopifnot(checked>=50)
r <- cp2_compare(o)
stored <- fread('output/cp2_performance.csv')
stopifnot(isTRUE(all.equal(stored,r$summary,tolerance=1e-12,check.attributes=FALSE)))
stored_fold <- fread('output/cp2_fold_performance.csv')
stopifnot(isTRUE(all.equal(stored_fold,r$fold,tolerance=1e-12,check.attributes=FALSE)))
curves <- fread('output/cp2_roc_curve_data.csv')
for(method_name in names(cp2_methods)) {
 expected <- cp2_roc_data(o$outcome[r$common],o[[cp2_methods[method_name]]][r$common],method_name)
 stopifnot(isTRUE(all.equal(curves[method==method_name],expected,tolerance=1e-12,check.attributes=FALSE)))
}
b <- readRDS('output/cp2_final_model.rds')
stopifnot(checked==50L+if (b$family=='forest') 4L else 0L)
fixture <- readRDS('output/cp2_prediction_fixture.rds')
stopifnot(!any(names(fixture$predictors) %in% cp2_forbidden),
 max(abs(cp2_predict(b,fixture$predictors)-fixture$probability))<fixture$tolerance,
 !any(b$preprocess$predictors %in% cp2_forbidden),b$metadata$training_set=='set-a',b$event==1)
g <- readRDS('output/cp2_interpretation_gam.rds')
e <- rbindlist(lapply(c('Age','HR_h24_48_mean','Temp_h24_48_mean'),function(v) cp2_effect_data(g,d$x,v)$curve))
stopifnot(isTRUE(all.equal(e,fread('output/cp2_gam_effect_curves.csv'),tolerance=1e-12,check.attributes=FALSE)))
manifest <- fread('output/cp2_input_manifest.csv')
stopifnot(nrow(manifest)==4001,all(startsWith(manifest$path,'data/set-a/') | manifest$path=='data/Outcomes-a.txt'))
cat('CP2 artifact integration passed:',nrow(o),'OOF stays;',checked,'verified training-only states; metrics/plots/reload aligned.\n')
