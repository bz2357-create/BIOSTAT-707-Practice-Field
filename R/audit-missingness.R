# Metadata names TropI/TropT correspond to TroponinI/TroponinT in these files.
time_series_parameters <- c('Albumin','ALP','ALT','AST','Bilirubin','BUN',
 'Cholesterol','Creatinine','DiasABP','FiO2','GCS','Glucose','HCO3','HCT','HR',
 'K','Lactate','Mg','MAP','MechVent','Na','NIDiasABP','NIMAP','NISysABP',
 'PaCO2','PaO2','pH','Platelets','RespRate','SaO2','SysABP','Temp',
 'TroponinI','TroponinT','Urine','WBC','Weight')
stopifnot(length(time_series_parameters) == 37L, !anyDuplicated(time_series_parameters))

# Rule counts may overlap (e.g. a negative pH violates two rules).
audit_measurements <- function(long) {
  x <- copy(long)
  x[, `:=`(Value_analysis = Value, hard_invalid = FALSE, quality_reason = NA_character_)]
  flags <- list(); summaries <- list()
  add_rule <- function(mask, parameter, rule, type) {
    rows <- which(!is.na(mask) & mask)
    treatment <- if (type == 'hard') 'Set Value_analysis to NA; preserve evidence' else 'Retain unchanged; review only'
    summaries[[length(summaries)+1L]] <<- data.table(Parameter=parameter,
      validity_rule=rule, flag_type=type, violations=length(rows),
      example_values=paste(head(sort(unique(x$Value[rows])), 8), collapse=', '), treatment=treatment)
    if (length(rows)) {
      f <- x[rows, .(RecordID, Time, time_hours, Parameter, Value_raw, Value)]
      f[, `:=`(source_row = rows, flag_type = type, reason = rule)]
      flags[[length(flags)+1L]] <<- f
      if (type == 'hard') {
        prior <- x$quality_reason[rows]
        set(x, rows, 'quality_reason', ifelse(is.na(prior),rule,paste(prior,rule,sep='; ')))
        set(x, rows, 'hard_invalid', TRUE)
        set(x, rows, 'Value_analysis', NA_real_)
      }
    }
  }
  add_rule(x$Value < 0, 'All parameters', 'Nonmissing values must be non-negative', 'hard')
  for (p in c('Gender','ICUType','MechVent')) {
    allowed <- switch(p, Gender=c(0,1), ICUType=1:4, MechVent=c(0,1))
    add_rule(x$Parameter==p & !is.na(x$Value) & !(x$Value %in% allowed), p,
             paste0('Allowed categories: ',paste(allowed,collapse=', ')), 'hard')
  }
  ranges <- list(GCS=c(3,15),FiO2=c(0,1),SaO2=c(0,100),pH=c(0,14))
  for (p in names(ranges)) {
    r <- ranges[[p]]
    add_rule(x$Parameter==p & (x$Value < r[1] | x$Value > r[2]), p,
             paste0('Documented bounds: ',r[1],' to ',r[2]), 'hard')
  }
  add_rule(x$Parameter=='Height' & !x$hard_invalid & (x$Value<100 | x$Value>250),
           'Height','Analyst screen: outside 100–250 cm (not an official range)','soft')
  for (p in c('Weight','HR','RespRate','DiasABP','SysABP','MAP',
              'NIDiasABP','NISysABP','NIMAP','PaO2')) {
    add_rule(x$Parameter==p & x$Value==0, p,'Zero value: context or monitoring review needed','soft')
  }
  # Inspect each continuous variable's highest observed positive value. This is
  # a transparent rank-based review, not a claim that the maximum is an error.
  continuous <- setdiff(unique(x$Parameter),c('RecordID','Gender','ICUType','MechVent','GCS'))
  for (p in continuous) {
    candidates <- which(x$Parameter==p & !x$hard_invalid & !is.na(x$Value) & x$Value>0)
    if (length(candidates)) {
      highest <- max(x$Value[candidates])
      add_rule(x$Parameter==p & !x$hard_invalid & x$Value==highest,p,
        'Exploratory positive maximum (all ties); not a clinical cutoff','soft_extreme_review')
    }
  }
  stopifnot(identical(x$Value_raw,long$Value_raw), identical(x$Value,long$Value))
  list(long=x, flags=rbindlist(flags), summary=rbindlist(summaries))
}

bin_six <- function(hours) {
  if (anyNA(hours) || any(!is.finite(hours)) || any(hours < 0 | hours > 48)) {
    stop('Time must be within 0 to 48 hours for temporal analysis')
  }
  as.integer(pmin(floor(hours / 6)+1,8))
}

check_population <- function(ids) {
  if (length(ids)!=4000L || anyNA(ids) || anyDuplicated(ids)) stop('Expected 4000 unique RecordIDs')
}

measurement_availability <- function(x, ids) {
  check_population(ids)
  stopifnot(all(x$RecordID %in% ids))
  valid <- x[Parameter %in% time_series_parameters & !is.na(Value_analysis) &
               time_hours >= 0 & time_hours <= 48, .(RecordID,Parameter,time_hours)]
  valid[, bin := bin_six(time_hours)]
  counts <- valid[, .(n_measured=uniqueN(RecordID)), by=Parameter]
  overall <- merge(data.table(Parameter=time_series_parameters),counts,by='Parameter',all.x=TRUE)
  overall[is.na(n_measured),n_measured:=0L]
  overall[, `:=`(denominator=4000L, p_measured=n_measured/4000, p_missing=1-n_measured/4000)]
  setorder(overall,n_measured,Parameter)
  grid <- CJ(Parameter=time_series_parameters,bin=1:8)
  temporal <- merge(grid,valid[,.(n_measured=uniqueN(RecordID)),by=.(Parameter,bin)],
                    by=c('Parameter','bin'),all.x=TRUE)
  temporal[is.na(n_measured),n_measured:=0L]
  temporal[, `:=`(denominator=4000L,p_measured=n_measured/4000,p_missing=1-n_measured/4000)]
  # The 24:00 boundary is in the second window; 48:00 is also included there.
  valid[, period := ifelse(time_hours<24,'first','second')]
  half <- merge(CJ(Parameter=time_series_parameters,period=c('first','second')),
     valid[,.(n_measured=uniqueN(RecordID)),by=.(Parameter,period)],
     by=c('Parameter','period'),all.x=TRUE)
  half[is.na(n_measured),n_measured:=0L]
  half[, proportion:=n_measured/4000]
  halves <- dcast(half,Parameter~period,value.var='proportion')
  setnames(halves,c('first','second'),c('p_first','p_second'))
  halves[, difference_pp:=100*(p_second-p_first)]
  stopifnot(nrow(overall)==37L,nrow(temporal)==296L,
            all(temporal$n_measured<=4000L),all(overall$n_measured<=4000L))
  list(overall=overall,temporal=temporal,halves=halves)
}

admission_availability <- function(x,ids) {
  check_population(ids)
  fields <- c('Age','Gender','Height','ICUType','Weight')
  admission <- x[Parameter %in% fields & time_hours==0 & !is.na(Value_analysis)]
  out <- merge(data.table(Parameter=fields),
      admission[,.(n_measured=uniqueN(RecordID)),by=Parameter],by='Parameter',all.x=TRUE)
  out[is.na(n_measured),n_measured:=0L]
  out[, `:=`(denominator=4000L,n_missing=4000L-n_measured,p_missing=1-n_measured/4000)]
  out
}

validate_outcomes <- function(outcomes,ids) {
  check_population(ids)
  expected <- c('RecordID','SAPS-I','SOFA','Length_of_stay','Survival','In-hospital_death')
  if (!identical(names(outcomes),expected)) stop('Unexpected outcome columns')
  if (nrow(outcomes)!=4000L || uniqueN(outcomes$RecordID)!=4000L) stop('Expected 4000 unique outcome rows')
  if (!setequal(outcomes$RecordID,ids)) stop('Outcome RecordID set mismatch')
  if (anyNA(outcomes[['In-hospital_death']]) ||
      !all(outcomes[['In-hospital_death']] %in% c(0,1))) stop('In-hospital_death must contain only 0/1')
  invisible(TRUE)
}
