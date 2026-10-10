cp2_methods <- c('Elastic net'='enet_probability','GAM'='gam_probability',
 'Random forest'='forest_probability','SAPS-I'='SAPS_I_score','SOFA'='SOFA_score')
cp2_write_oof <- function(oof,path) {
 # fwrite's usual 15 significant digits can merge adjacent forest probabilities.
 # Keep 17 digits; the reloaded CSV is the canonical representation for metrics.
 csv <- copy(oof)
 for (n in unname(cp2_methods)[1:3])
  set(csv,j=n,value=ifelse(is.na(csv[[n]]),NA_character_,sprintf('%.17g',csv[[n]])))
 fwrite(csv,path,na='NA')
}
cp2_validate_oof <- function(o,ids,y,folds) {
 stopifnot(nrow(o)==length(ids),!anyDuplicated(o$RecordID),!anyNA(o$RecordID),
  identical(o$RecordID,ids),identical(o$outcome,y),identical(o$outer_fold,folds))
 for (p in unname(cp2_methods)[1:3]) stopifnot(all(is.finite(o[[p]])),all(o[[p]]>=0 & o[[p]]<=1))
 invisible(TRUE)
}
cp2_compare <- function(o,k=5) {
 common <- complete.cases(o[,.(SAPS_I_score,SOFA_score)])
 fold <- rbindlist(lapply(names(cp2_methods),function(method) rbindlist(lapply(seq_len(k),function(f) {
  idx <- common & o$outer_fold==f
  data.table(method=method,fold=f,n=sum(idx),deaths=sum(o$outcome[idx]),
             auc=cp2_auc(o$outcome[idx],o[[cp2_methods[method]]][idx]))
 }))))
 summary <- fold[,.(mean_auc=mean(auc),sd_auc=sd(auc),n=sum(n),deaths=sum(deaths)),by=method]
 summary <- merge(summary,dcast(fold,method~fold,value.var='auc'),by='method',sort=FALSE)
 summary <- summary[match(names(cp2_methods),method)]
 full_models <- rbindlist(lapply(names(cp2_methods)[1:3],function(m) rbindlist(lapply(seq_len(k),function(f) {
  idx <- o$outer_fold==f
  data.table(method=m,fold=f,n=sum(idx),deaths=sum(o$outcome[idx]),
             auc=cp2_auc(o$outcome[idx],o[[cp2_methods[m]]][idx]))
 }))))
 pooled <- rbindlist(lapply(names(cp2_methods),function(m) data.table(method=m,
  pooled_auc=cp2_auc(o$outcome[common],o[[cp2_methods[m]]][common]))))
 list(common=common,fold=fold,summary=summary,full_models=full_models,pooled=pooled)
}
cp2_coefficients <- function(bundle,tolerance=1e-8) {
 c <- as.matrix(coef(bundle$model,s=bundle$hyperparameters$lambda))
 c <- c[rownames(c)!='(Intercept)',,drop=FALSE]
 data.table(predictor=rownames(c),standardized_coefficient=c[,1],retained=abs(c[,1])>tolerance)
}
cp2_run <- function() {
 start <- proc.time()[['elapsed']]; dir.create('output',showWarnings=FALSE)
 warnings <- character();stage <- 'data reconstruction'
 writeLines(character(),'output/cp2_warnings.log')
 result <- withCallingHandlers({
  d <- cp2_data(); x <- d$x;y <- d$y;ids <- d$ids
  seed <- 7072026L; folds <- cp2_folds(ids,y,5,seed)
  fwrite(data.table(RecordID=ids,outcome=y,outer_fold=folds),'output/cp2_outer_folds.csv')
  fwrite(d$wide,'output/cp2_modeling_table.csv',na='NA')
  for (n in c('cleaning','hard_summary','flags','descriptors','duplicates','source_summary','input_manifest'))
   fwrite(d[[n]],paste0('output/cp2_',n,'.csv'),na='NA')
  dictionary <- cp2_dictionary();fwrite(dictionary,'output/cp2_predictor_dictionary.csv')
  oof <- data.table(RecordID=ids,outcome=y,outer_fold=folds,
   enet_probability=NA_real_,gam_probability=NA_real_,forest_probability=NA_real_,
   SAPS_I_score=d$benchmarks$SAPS_I_score,SOFA_score=d$benchmarks$SOFA_score)
  tuning_enet <- list();tuning_forest <- list();audit <- list();outer <- list();inner_records <- list()
  hp_records <- list();drop_records <- list();gam_diagnostics <- list();gam_terms <- list()
  progress <- function(s) {stage <<- s;write(s,'output/cp2_progress.txt',append=TRUE);message(s)}
  writeLines('Starting five outer folds; frozen grids.','output/cp2_progress.txt')
  for (f in 1:5) {
   tr <- which(folds!=f);va <- which(folds==f);ctx <- paste0('outer_',f)
   inner <- cp2_folds(ids[tr],y[tr],3,seed+f)
   inner_records[[f]] <- data.table(context=ctx,RecordID=ids[tr],inner_fold=inner)
   progress(paste(ctx,'elastic-net tuning'))
   en <- cp2_tune_enet(x[tr,],y[tr],ids[tr],inner,cp2_predictors(),context=ctx)
   progress(paste(ctx,'forest tuning'))
   rf <- cp2_tune_forest(x[tr,],y[tr],ids[tr],inner,cp2_predictors(),seed+100*f,context=ctx)
   tuning_enet[[f]] <- en$scores;tuning_forest[[f]] <- rf$scores
   audit[[paste0(ctx,'_enet_inner')]] <- en$audit;audit[[paste0(ctx,'_forest_inner')]] <- rf$audit
   fits <- list()
   for (family in c('enet','gam','forest')) {
    progress(paste(ctx,family,'outer-training refit'))
    hp <- switch(family,enet=en$hyperparameters,gam=list(k=5),forest=rf$hyperparameters)
    vars <- if (family=='gam') cp2_gam_variables else cp2_predictors()
    fitted <- cp2_fit_model(family,x[tr,],y[tr],vars,hp,seed+100*f)
    oof[va,(paste0(family,'_probability')):=cp2_predict(fitted,x[va,])]
    fits[[family]] <- fitted
    audit[[paste0(ctx,'_',family,'_refit')]] <- list(context=ctx,training_ids=ids[tr],assessment_ids=ids[va],preprocess=fitted$preprocess)
    hp_records[[length(hp_records)+1L]] <- data.table(context=ctx,family=family,
     design_p=length(fitted$preprocess$columns),lambda=if(family=='enet') hp$lambda else NA_real_,
     boundary=if(family=='enet') en$boundary else NA,
     mtry=if(family=='forest') fitted$hyperparameters$mtry else NA_integer_,
     mtry_rule=if(family=='forest') hp$mtry_rule else NA_character_,node=if(family=='forest') hp$node else NA_real_)
    drop <- copy(fitted$preprocess$dropped);drop[,`:=`(context=ctx,family=family)]
    drop_records[[length(drop_records)+1L]] <- drop
    if(family=='gam') {
     diag <- copy(fitted$diagnostics);diag[,context:=ctx];gam_diagnostics[[f]] <- diag
     terms <- copy(fitted$terms);terms[,context:=ctx];gam_terms[[f]] <- terms
    }
   }
   outer[[f]] <- fits
   fwrite(oof,'output/cp2_oof_in_progress.csv',na='NA')
  }
  cp2_validate_oof(oof,ids,y,folds)
  cp2_write_oof(oof,'output/cp2_oof_predictions.csv')
  # Fast CSV parsers can move adjacent doubles by one ULP. Evaluate the exact
  # persisted representation, so the report/ROC are reproducible from this CSV.
  oof <- fread('output/cp2_oof_predictions.csv',colClasses=list(character='RecordID'))
  cp2_validate_oof(oof,ids,y,folds);comparison <- cp2_compare(oof)
  fwrite(comparison$fold,'output/cp2_fold_performance.csv')
  fwrite(comparison$summary,'output/cp2_performance.csv')
  fwrite(comparison$full_models,'output/cp2_full_cohort_fold_performance.csv')
  fwrite(comparison$pooled,'output/cp2_pooled_auc.csv')
  # Selection on the same common cohort used in the five-method comparison.
  learned <- comparison$summary[method %in% names(cp2_methods)[1:3]]
  winner <- learned[mean_auc>=max(mean_auc)-cp2_tolerance][order(match(method,names(cp2_methods)[1:3])),method][1]
  selected_family <- c('Elastic net'='enet','GAM'='gam','Random forest'='forest')[winner]
  progress(paste('Selected family:',selected_family,'; all-set-a interpretation/final fits'))
  full_inner <- cp2_folds(ids,y,3,seed+900L)
  inner_records[[6]] <- data.table(context='full',RecordID=ids,inner_fold=full_inner)
  en <- cp2_tune_enet(x,y,ids,full_inner,cp2_predictors(),context='full')
  tuning_enet[[6]] <- en$scores;audit$full_enet_inner <- en$audit
  full <- list(enet=cp2_fit_model('enet',x,y,cp2_predictors(),en$hyperparameters,seed+900L),
               gam=cp2_fit_model('gam',x,y,cp2_gam_variables,list(k=5),seed+900L))
  if(selected_family=='forest') {
   rf <- cp2_tune_forest(x,y,ids,full_inner,cp2_predictors(),seed+900L,context='full')
   tuning_forest[[6]] <- rf$scores;audit$full_forest_inner <- rf$audit
   full$forest <- cp2_fit_model('forest',x,y,cp2_predictors(),rf$hyperparameters,seed+900L)
  }
  for (family in names(full)) {
   fitted <- full[[family]]
   audit[[paste0('full_',family,'_refit')]] <- list(context='full',training_ids=ids,assessment_ids=character(),preprocess=fitted$preprocess)
   drop <- copy(fitted$preprocess$dropped);drop[,`:=`(context='full',family=family)];drop_records[[length(drop_records)+1L]] <- drop
   hp <- fitted$hyperparameters
   hp_records[[length(hp_records)+1L]] <- data.table(context='full',family=family,design_p=length(fitted$preprocess$columns),
    lambda=if(family=='enet') hp$lambda else NA_real_,boundary=if(family=='enet') en$boundary else NA,
    mtry=if(family=='forest') hp$mtry else NA_integer_,mtry_rule=if(family=='forest') hp$mtry_rule else NA_character_,
    node=if(family=='forest') hp$node else NA_real_)
  }
  diag <- copy(full$gam$diagnostics);diag[,context:='full'];gam_diagnostics[[6]] <- diag
  terms <- copy(full$gam$terms);terms[,context:='full'];gam_terms[[6]] <- terms
  coef_all <- cp2_coefficients(full$enet)
  fold_coef <- rbindlist(lapply(1:5,function(f) {z <- cp2_coefficients(outer[[f]]$enet);z[,outer_fold:=f];z}))
  all_names <- sort(unique(c(coef_all$predictor,fold_coef$predictor)))
  stability <- data.table(predictor=all_names)
  for (f in 1:5) {
   z <- fold_coef[outer_fold==f];v <- z$retained[match(all_names,z$predictor)];v[is.na(v)] <- FALSE
   set(stability,j=paste0('fold_',f),value=v)
  }
  stability[,retained_folds:=rowSums(.SD),.SDcols=paste0('fold_',1:5)]
  stability[,frequency:=retained_folds/5]
  stability <- merge(stability,coef_all,by='predictor',all.x=TRUE)
  setorder(stability,-retained_folds,predictor)
  bundle <- full[[selected_family]]
  bundle$metadata <- list(schema_version=1L,outcome='In_hospital_death',source_outcome='In-hospital_death',
   event_mapping=c('0'='survived','1'='in-hospital death'),training_set='set-a',training_n=length(ids),
   training_deaths=sum(y),outer_seed=seed,inner_seeds=c(seed+1:5,seed+900L),
   fold_reference='output/cp2_outer_folds.csv',inner_fold_reference='output/cp2_inner_folds.csv',
   feature_spec=list(windows=c('[0,24)','[24,48]'),summaries=summary_names,
    time_series=time_series_parameters,admission='time zero only',ties='time then source order',
    invalid='CP1 sentinel/hard-invalid rules; CP2 Height/Weight zero to missing',
    ventilation='any valid MechVent = 1 in [24,48]; GAM only'),
   prediction_function='cp2_predict in R/cp2-models.R; expects constructed predictor table; no outcomes',
   package_versions=sapply(c('glmnet','mgcv','ranger','data.table','pROC'),function(p) as.character(packageVersion(p))))
  saveRDS(bundle,'output/cp2_final_model.rds')
  fixture <- x[seq_len(40),bundle$preprocess$predictors,drop=FALSE]
  before <- cp2_predict(bundle,fixture);after <- cp2_predict(readRDS('output/cp2_final_model.rds'),fixture)
  reload_error <- max(abs(before-after));stopifnot(reload_error<1e-12)
  saveRDS(list(predictors=fixture,probability=before,tolerance=1e-12),'output/cp2_prediction_fixture.rds')
  fwrite(data.table(max_absolute_reload_error=reload_error,tolerance=1e-12),'output/cp2_reload_check.csv')
  fwrite(rbindlist(inner_records),'output/cp2_inner_folds.csv')
  fwrite(rbindlist(tuning_enet),'output/cp2_tuning_enet.csv')
  fwrite(rbindlist(tuning_forest),'output/cp2_tuning_forest.csv')
  fwrite(rbindlist(hp_records,fill=TRUE),'output/cp2_selected_hyperparameters.csv')
  drops <- unique(rbindlist(drop_records,fill=TRUE));fwrite(drops,'output/cp2_dropped_columns.csv')
  fwrite(rbindlist(gam_diagnostics,fill=TRUE),'output/cp2_gam_diagnostics.csv')
  fwrite(rbindlist(gam_terms),'output/cp2_gam_terms.csv')
  fwrite(coef_all,'output/cp2_coefficients.csv');fwrite(stability,'output/cp2_selection_stability.csv')
  saveRDS(audit,'output/cp2_preprocessing_audit.rds')
  saveRDS(full$enet,'output/cp2_interpretation_enet.rds');saveRDS(full$gam,'output/cp2_interpretation_gam.rds')
  list(data=d,oof=oof,comparison=comparison,outer=outer,full=full,selected=winner,
       bundle=bundle,coefficients=coef_all,stability=stability,drops=drops,
       hyperparameters=rbindlist(hp_records,fill=TRUE),dictionary=dictionary,
       gam_diagnostics=rbindlist(gam_diagnostics,fill=TRUE),warnings=warnings)
 },warning=function(w) {
  entry <- paste(stage,conditionMessage(w),sep=': ')
  warnings <<- c(warnings,entry);write(entry,'output/cp2_warnings.log',append=TRUE)
  invokeRestart('muffleWarning')
 })
 result$warnings <- warnings
 if (!length(warnings)) writeLines('No R modeling warnings during this run.','output/cp2_warnings.log')
 writeLines(c(paste('Pipeline elapsed seconds:',proc.time()[['elapsed']]-start),
  paste('R:',R.version.string),paste('Machine:',paste(Sys.info()[c('sysname','release','machine')],collapse=' ')),
  paste('Logical cores:',parallel::detectCores()),'ranger threads: 1'), 'output/cp2_runtime.txt')
 result
}
