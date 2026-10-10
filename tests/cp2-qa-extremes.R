# Read-only scientific diagnostic of the existing Set A OOF GAM predictions.
# Reconstruct only their frozen outer-fold GAMs, without tuning or overwriting CP2.
library(data.table)
setDTthreads(1)
for (f in c('load-set-a','audit-missingness','build-wide','cp2-data',
            'cp2-preprocess','cp2-models','cp2-run')) source(paste0('R/',f,'.R'))
start <- proc.time()[['elapsed']]
d <- cp2_data()
o <- fread('output/cp2_oof_predictions.csv',colClasses=list(character='RecordID'))
folds <- cp2_folds(d$ids,d$y,5,7072026L)
cp2_validate_oof(o,d$ids,d$y,folds)
cases <- o[(outcome==1 & gam_probability<1e-10) |
           (outcome==0 & gam_probability>1-1e-10)]
stopifnot(nrow(cases)==3L)
cases[,case:=LETTERS[seq_len(.N)]]
audit <- readRDS('output/cp2_preprocessing_audit.rds')
summaries <- list();features <- list();contributions <- list();source_rows <- list();category_support <- list()
for (f in sort(unique(cases$outer_fold))) {
 tr <- which(folds!=f); va <- which(folds==f)
 # Same formula, k, REML, seed and training IDs as the original outer fit.
 b <- cp2_fit_model('gam',d$x[tr,],d$y[tr],cp2_gam_variables,list(k=5),7072026L+100L*f)
 old <- audit[[paste0('outer_',f,'_gam_refit')]]
 comparable <- function(p) {p$dropped <- as.data.frame(p$dropped);p}
 stopifnot(identical(old$training_ids,d$ids[tr]),
           identical(comparable(b$preprocess),comparable(old$preprocess)),
           !length(intersect(old$training_ids,old$assessment_ids)))
 prediction <- cp2_predict(b,d$x[va,])
 max_error <- max(abs(prediction-o$gam_probability[va]))
 stopifnot(max_error<1e-12)
 gender <- data.table(level=ifelse(is.na(d$x$Gender[tr]),'missing',as.character(d$x$Gender[tr])),outcome=d$y[tr])
 support <- gender[,.(training_n=.N,training_deaths=sum(outcome),training_survivors=sum(outcome==0)),by=level]
 support[,outer_fold:=f]
 category_support[[as.character(f)]] <- support
 for (j in which(cases$outer_fold==f)) {
  id <- cases$RecordID[j]; label <- cases$case[j]; i <- match(id,d$ids)
  x <- d$x[i,,drop=FALSE]
  design <- as.data.frame(cp2_apply_preprocess(b$preprocess,x))
  terms <- mgcv::predict.gam(b$model,newdata=design,type='terms')
  eta <- as.numeric(mgcv::predict.gam(b$model,newdata=design,type='link'))
  intercept <- as.numeric(attr(terms,'constant'))
  stopifnot(abs(sum(terms)+intercept-eta)<1e-8)
  ct <- data.table(case=label,term=colnames(terms),contribution=as.numeric(terms))
  ct <- ct[order(-abs(contribution))];contributions[[label]] <- ct
  raw <- read_patient(file.path('data/set-a',paste0(id,'.txt')))
  cleaned <- cp2_zero_missing(audit_measurements(raw)$long)$long
  parents <- unique(sub('_h.*','',cp2_gam_variables))
  src <- cleaned[(Parameter %in% c('Age','Gender','ICUType') & time_hours==0) |
                  (Parameter %in% setdiff(parents,c('Age','Gender','ICUType')) & time_hours>=24 & time_hours<=48)]
  src[,case:=label];source_rows[[label]] <- src
  ft <- rbindlist(lapply(cp2_gam_variables,function(v) {
   observed <- d$x[[v]][tr];support <- observed[!is.na(observed)]
   value <- x[[v]]
   q <- quantile(support,c(.01,.99),names=FALSE)
   is_category <- v %in% c('Gender','ICUType')
   processed <- if (is_category) {
    rule <- b$preprocess$categories[[v]];val <- as.character(value)
    if (is.na(val) || !val %in% rule$levels) rule$fallback else val
   } else as.character(design[[v]])
   data.table(case=label,predictor=v,source_value=value,missing=is.na(value),
    training_imputation=if(is_category) NA_real_ else b$preprocess$medians[v],
    applied_design_value=processed,transformation=if(grepl('_count$',v)) 'log1p' else if(is_category) 'training-defined dummy encoding' else 'original units',
    observed_training_n=length(support),training_min=min(support),training_max=max(support),
    training_q01=q[1],training_q99=q[2],
    outside_training_range=if(is.na(value)) FALSE else value<min(support) || value>max(support),
    outside_training_q01_q99=if(is.na(value)) FALSE else value<q[1] || value>q[2])
  }))
  features[[label]] <- ft
  summaries[[label]] <- data.table(case=label,outcome=cases$outcome[j],outer_fold=f,
   stored_probability=cases$gam_probability[j],reconstructed_probability=cp2_predict(b,x),
   linear_predictor=eta,intercept=intercept,contribution_sum=sum(terms),
   fold_max_prediction_error=max_error,missing_sources=sum(ft$missing),
   outside_training_range=sum(ft$outside_training_range),
   largest_term=ct$term[1],largest_contribution=ct$contribution[1],
   gender_missing_training_n=sum(is.na(d$x$Gender[tr])),
   gender_missing_training_deaths=sum(d$y[tr][is.na(d$x$Gender[tr])]),
   gender_missing_coefficient=coef(b$model)['Gender__missing'],
   gender_missing_standard_error=mgcv::summary.gam(b$model)$p.table['Gender__missing','Std. Error'],
   converged=b$model$converged,outer_convergence=b$model$outer.info$conv)
 }
}
fwrite(cases,'output/cp2_qa_extreme_case_index.csv') # Local IDs; summaries use A–C only.
fwrite(rbindlist(summaries),'output/cp2_qa_extreme_summary.csv')
fwrite(rbindlist(features),'output/cp2_qa_extreme_features.csv',na='NA')
fwrite(rbindlist(contributions),'output/cp2_qa_extreme_contributions.csv')
fwrite(rbindlist(source_rows),'output/cp2_qa_extreme_source_rows.csv',na='NA')
fwrite(rbindlist(category_support),'output/cp2_qa_gender_training_support.csv')
print(rbindlist(summaries))
for (label in names(features)) {
 cat('\nCase',label,'largest terms and out-of-training-range inputs:\n')
 print(head(contributions[[label]],4))
 print(features[[label]][outside_training_range==TRUE,
  .(predictor,source_value,training_min,training_max)])
}
cat('Frozen-GAM diagnostic elapsed seconds:',proc.time()[['elapsed']]-start,'\n')
