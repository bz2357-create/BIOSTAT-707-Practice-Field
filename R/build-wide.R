# Requires data.table and the existing Round 2 helper.
admission_fields <- c('Age','Gender','Height','ICUType','Weight')
summary_names <- c('count','first','last','min','max','mean')
window_names <- c('h0_24','h24_48')
outcome_names <- c('SAPS_I','SOFA','Length_of_stay','Survival','In_hospital_death')
feature_columns <- function() unlist(lapply(time_series_parameters,function(p)
 unlist(lapply(window_names,function(w) paste(p,w,summary_names,sep='_')),use.names=FALSE)),use.names=FALSE)
count_columns <- function() grep('_count$',feature_columns(),value=TRUE)
wide_columns <- function() c('RecordID','Age','Gender','Height','ICUType','AdmissionWeight',
                             feature_columns(),outcome_names)

window_24 <- function(hours) {
 bin_six(hours) # Reuse existing finite-value and 0–48 validation.
 ifelse(hours<24,'h0_24','h24_48')
}

summarize_windows <- function(x) {
 y <- x[Parameter %in% time_series_parameters,
        .(RecordID,Parameter,time_hours,Value_analysis)]
 y[,source_order:=.I]
 y[,window:=window_24(time_hours)]
 y <- y[!is.na(Value_analysis)]
 stopifnot(all(is.finite(y$Value_analysis)))
 setorder(y,RecordID,Parameter,window,time_hours,source_order)
 y[,.(count=.N,first=Value_analysis[1L],last=Value_analysis[.N],
      min=min(Value_analysis),max=max(Value_analysis),mean=mean(Value_analysis)),
   by=.(RecordID,Parameter,window)]
}

build_wide <- function(x,ids,outcomes) {
 check_population(ids); validate_outcomes(outcomes,ids)
 stopifnot(all(x$RecordID %in% ids))
 ids <- sort(ids)
 # Descriptor grid detects absent source rows as well as repeated ones.
 d <- x[Parameter %in% admission_fields & time_hours==0,
        .(RecordID,Parameter,Value_analysis)]
 audit <- d[,.(source_rows=.N,distinct_values=uniqueN(Value_analysis),
                valid_values=uniqueN(Value_analysis,na.rm=TRUE)),by=.(RecordID,Parameter)]
 audit <- merge(CJ(RecordID=ids,Parameter=admission_fields),audit,
                by=c('RecordID','Parameter'),all.x=TRUE)
 for (column in c('source_rows','distinct_values','valid_values')) set(audit,which(is.na(audit[[column]])),column,0L)
 if (any(audit$distinct_values>1L)) stop('Conflicting admission descriptors: review before extraction')
 # Identical duplicate values (including all-NA duplicates) collapse by source order.
 d <- d[,.(value=Value_analysis[1L]),by=.(RecordID,Parameter)]
 wide <- data.table(RecordID=ids)
 for (p in admission_fields) {
  values <- d[Parameter==p]; name <- if (p=='Weight') 'AdmissionWeight' else p
  set(wide,j=name,value=values$value[match(ids,values$RecordID)])
 }
 summaries <- summarize_windows(x)
 for (p in time_series_parameters) for (w in window_names) {
  z <- summaries[Parameter==p & window==w]; index <- match(ids,z$RecordID)
  for (stat in summary_names) {
   values <- z[[stat]][index]
   if (stat=='count') { values[is.na(values)] <- 0L; values <- as.integer(values) }
   set(wide,j=paste(p,w,stat,sep='_'),value=values)
  }
 }
 o <- copy(outcomes)
 setnames(o,c('SAPS-I','In-hospital_death'),c('SAPS_I','In_hospital_death'))
 for (name in outcome_names) set(wide,j=name,value=o[[name]][match(ids,o$RecordID)])
 setcolorder(wide,wide_columns())
 duplicates <- x[,.(rows=.N,valid_distinct=uniqueN(Value_analysis,na.rm=TRUE)),
                 by=.(RecordID,Parameter,Time)][rows>1L]
 validate_wide(wide,ids,outcomes)
 list(wide=wide,descriptor_audit=audit,duplicates=duplicates)
}

validate_wide <- function(wide,ids,outcomes) {
 check_population(ids); validate_outcomes(outcomes,ids)
 stopifnot(nrow(wide)==4000L,ncol(wide)==455L,uniqueN(wide$RecordID)==4000L,
           setequal(wide$RecordID,ids),setequal(wide$RecordID,outcomes$RecordID),
           !anyDuplicated(names(wide)),identical(names(wide),wide_columns()))
 numeric_cols <- setdiff(names(wide),'RecordID')
 stopifnot(all(vapply(wide[,..numeric_cols],is.numeric,logical(1))))
 stopifnot(!any(vapply(wide[,..numeric_cols],function(v) any(is.infinite(v)|is.nan(v)),logical(1))))
 for (p in time_series_parameters) for (w in window_names) {
  prefix <- paste(p,w,sep='_'); n <- wide[[paste0(prefix,'_count')]]
  values <- as.matrix(wide[,paste(prefix,summary_names[-1],sep='_'),with=FALSE])
  stopifnot(!anyNA(n),all(n>=0 & n==floor(n)),
            all(rowSums(is.na(values))[n==0]==5),all(rowSums(is.na(values))[n>0]==0))
  observed <- n>0
  lo <- wide[[paste0(prefix,'_min')]]; hi <- wide[[paste0(prefix,'_max')]]
  av <- wide[[paste0(prefix,'_mean')]]
  tol <- 1e-10*pmax(1,abs(lo),abs(hi))
  stopifnot(all(lo[observed]<=av[observed]+tol[observed]),
            all(av[observed]<=hi[observed]+tol[observed]))
 }
 source_names <- c('SAPS-I','SOFA','Length_of_stay','Survival','In-hospital_death')
 for (i in seq_along(outcome_names)) {
  stopifnot(isTRUE(all.equal(wide[[outcome_names[i]]],
   outcomes[[source_names[i]]][match(wide$RecordID,outcomes$RecordID)],check.attributes=FALSE)))
 }
 invisible(TRUE)
}

wide_missingness <- function(wide) {
 rbindlist(lapply(time_series_parameters,function(p) rbindlist(lapply(window_names,function(w) {
  n <- sum(wide[[paste(p,w,'count',sep='_')]]==0)
  data.table(Parameter=p,window=w,n_missing=n,denominator=nrow(wide),p_missing=n/nrow(wide))
 }))))
}

outcome_description <- function(wide) {
 # Retain raw outcome fields; these field-specific copies alone map -1 to NA.
 rbindlist(lapply(c('Length_of_stay','SAPS_I','SOFA'),function(p) {
  v <- wide[[p]]; v[v == -1] <- NA_real_
  stopifnot(all(is.na(v) | v>=0))
  q <- quantile(v,c(.25,.5,.75),na.rm=TRUE,names=FALSE)
  data.table(field=p,nonmissing_N=sum(!is.na(v)),missing_N=sum(is.na(v)),
             median=q[2],q1=q[1],q3=q[3],IQR=q[3]-q[1])
 }))
}
