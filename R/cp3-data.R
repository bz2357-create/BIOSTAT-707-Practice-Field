# External prediction reuses CP2's unchanged deterministic helpers and saved state.
cp3_model_md5 <- '670c1fc1fd4a2241fe9ed572ac722019'
cp3_load_bundle <- function(path='artifacts/cp2_final_model.rds') {
 if(!file.exists(path) || unname(tools::md5sum(path))!=cp3_model_md5) stop('Frozen model hash mismatch')
 b <- readRDS(path)
 stopifnot(b$family=='enet',b$metadata$training_set=='set-a',!any(b$preprocess$predictors %in% cp2_forbidden))
 b
}
cp3_data <- function(split) {
 if(length(split)!=1 || !split %in% c('a','b','c')) stop('Invalid split')
 loaded <- cp3_load_split(paste0('data/set-',split)); long <- loaded$data
 bin_six(long$time_hours)
 if(!all(long$Parameter %in% c(time_series_parameters,'RecordID','Age','Gender','Height','ICUType'))) stop('Unknown parameter')
 ids <- sort(unique(long$RecordID))
 o <- fread(paste0('data/Outcomes-',split,'.txt'),colClasses=list(character='RecordID'),check.names=FALSE)
 validate_outcomes(o,ids)
 audited <- audit_measurements(long); cleaned <- cp2_zero_missing(audited$long)
 built <- cp3_build_wide(cleaned$long,ids,o); w <- built$wide
 x <- as.data.frame(w[,cp2_predictors(),with=FALSE])
 x$MechVent_h24_48_documented_1 <- cp2_ventilation(cleaned$long,w$RecordID)$MechVent_h24_48_documented_1
 bench <- w[,.(SAPS_I_score=SAPS_I,SOFA_score=SOFA)]
 for(n in names(bench)) {
  if(any(bench[[n]] < -1,na.rm=TRUE)) stop('Invalid benchmark score')
  set(bench,which(bench[[n]]==-1),n,NA_real_)
 }
 hard <- audited$long[,.(hard_invalid=sum(hard_invalid)),by=RecordID]
 quality <- merge(data.table(RecordID=w$RecordID,missing_fraction=rowMeans(is.na(x))),hard,by='RecordID',sort=FALSE)
 quality <- quality[match(w$RecordID,RecordID)]
 untyped_counts <- loaded$untyped[,.(untyped_records=.N),by=RecordID]
 quality[,untyped_records:=untyped_counts$untyped_records[match(RecordID,untyped_counts$RecordID)]]
 quality[is.na(untyped_records),untyped_records:=0L]
 list(split=split,x=x,y=w$In_hospital_death,ids=w$RecordID,benchmarks=bench,wide=w,quality=quality,untyped=loaded$untyped,conflicts=built$conflicts)
}
cp3_predict <- function(bundle,x) {
 if(any(names(x) %in% cp2_forbidden)) stop('Forbidden columns in prediction input')
 original <- serialize(bundle$preprocess,NULL)
 p <- cp2_predict(bundle,x)
 stopifnot(identical(original,serialize(bundle$preprocess,NULL)))
 p
}

# Preserve raw source files; unlabeled observations cannot be assigned to a model variable.
cp3_read_patient <- function(path) {
 lines <- readLines(path,warn=FALSE)
 bad <- which(grepl('^[^,]*,[[:space:]]*,[^,]*$',lines))
 untyped <- data.table(RecordID=character(),source_line=integer(),raw_record=character())
 if(!length(bad)) return(list(data=read_patient(path),untyped=untyped))
 untyped <- data.table(RecordID=sub('[.]txt$','',basename(path)),source_line=bad,raw_record=lines[bad])
 td <- tempfile();dir.create(td);on.exit(unlink(td,recursive=TRUE))
 clean_path <- file.path(td,basename(path));writeLines(lines[-bad],clean_path)
 list(data=read_patient(clean_path),untyped=untyped)
}
cp3_load_split <- function(directory) {
 files <- sort(list.files(directory,pattern='[.]txt$',full.names=TRUE,recursive=TRUE))
 if(length(files)!=4000 || anyDuplicated(basename(files))) stop('Expected 4000 unique patient files')
 z <- lapply(files,cp3_read_patient)
 list(data=rbindlist(lapply(z,`[[`,'data')),untyped=rbindlist(lapply(z,`[[`,'untyped')))
}
cp3_build_wide <- function(x,ids,outcomes) {
 ids <- sort(ids)
 d <- x[Parameter %in% admission_fields & time_hours==0]
 conflicts <- d[,.(distinct=uniqueN(Value_analysis),values=paste(unique(Value_analysis),collapse=';')),by=.(RecordID,Parameter)][distinct>1]
 if(!nrow(conflicts)) {
  built <- build_wide(x,ids,outcomes);built$conflicts <- conflicts;return(built)
 }
 # Admission extraction uses first source record; restore EVERY original window statistic.
 rows <- which(x$Parameter %in% admission_fields & x$time_hours==0)
 duplicate <- duplicated(paste(x$RecordID[rows],x$Parameter[rows],sep=':'))
 extraction <- x[-rows[duplicate]]
 built <- build_wide(extraction,ids,outcomes)
 summaries <- summarize_windows(x)
 for(p in time_series_parameters) for(w in window_names) {
  z <- summaries[Parameter==p & window==w];idx <- match(ids,z$RecordID)
  for(stat in summary_names) {
   value <- z[[stat]][idx]
   if(stat=='count') {value[is.na(value)] <- 0L;value <- as.integer(value)}
   set(built$wide,j=paste(p,w,stat,sep='_'),value=value)
  }
 }
 validate_wide(built$wide,ids,outcomes);built$conflicts <- conflicts;built
}
