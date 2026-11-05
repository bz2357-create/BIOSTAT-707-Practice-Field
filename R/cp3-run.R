cp3_run <- function() {
 start <- proc.time()[['elapsed']];dir.create('output',showWarnings=FALSE)
 warnings <- character()
 result <- withCallingHandlers({
  b <- cp3_load_bundle();before <- serialize(b$preprocess,NULL)
  datasets <- lapply(c('a','b','c'),function(s) {message('Constructing Set ',toupper(s));cp3_data(s)});names(datasets) <- c('a','b','c')
  stopifnot(!length(intersect(datasets$a$ids,datasets$b$ids)),!length(intersect(datasets$a$ids,datasets$c$ids)),!length(intersect(datasets$b$ids,datasets$c$ids)))
  result <- cp3_analyze(b,datasets)
  stopifnot(identical(before,serialize(b$preprocess,NULL)),unname(tools::md5sum('artifacts/cp2_final_model.rds'))==cp3_model_md5)
  for(s in c('b','c')) {
   d <- datasets[[s]]
   fwrite(data.table(RecordID=d$ids,outcome=d$y,risk=result$predictions[[s]]),paste0('output/cp3_predictions_',s,'.csv'))
   fwrite(d$quality,paste0('output/cp3_quality_',s,'.csv'))
   fwrite(d$untyped,paste0('output/cp3_untyped_records_',s,'.csv'))
   fwrite(d$conflicts,paste0('output/cp3_descriptor_conflicts_',s,'.csv'))
  }
  for(n in c('cohort','discrimination','cv_comparison','difference','dca','thresholds','subgroups','coefficients','cases','cases_private')) fwrite(result[[n]],paste0('output/cp3_',n,'.csv'),na='NA')
  result$calibration_summary <- rbindlist(lapply(c('b','c'),function(s) {z <- copy(result$calibration[[s]]$summary);z[,split:=toupper(s)];z}))
  fwrite(result$calibration_summary,'output/cp3_calibration_summary.csv')
  fwrite(data.table(intercept=result$sofa_mapping$coefficients[1],slope=result$sofa_mapping$coefficients[2],training_n=result$sofa_mapping$n,training_deaths=result$sofa_mapping$deaths),'output/cp3_sofa_mapping.csv')
  writeLines(c(paste('Model MD5:',cp3_model_md5),'Serialized preprocessing unchanged during prediction: TRUE','No external fitting in CP2 prediction path.'),'output/cp3_frozen_check.txt')
  result
 },warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
 result$warnings <- unique(c(warnings,unlist(lapply(result$calibration,`[[`,'warnings'))))
 writeLines(if(length(result$warnings)) result$warnings else 'No R analysis warnings.','output/cp3_warnings.log')
 saveRDS(result,'output/cp3_result.rds')
 writeLines(c(paste('Pipeline elapsed seconds:',proc.time()[['elapsed']]-start),paste('R:',R.version.string),paste('Machine:',paste(Sys.info()[c('sysname','machine')],collapse=' ')),'Bootstrap replicates: 2000; base seed 70732026; single-threaded data.table/BLAS.'),'output/cp3_runtime.txt')
 result
}
