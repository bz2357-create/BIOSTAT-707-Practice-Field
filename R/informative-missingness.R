# Descriptive mortality comparison; validity comes from the frozen analysis copy.
informative_missingness <- function(x, ids, outcomes) {
  validate_outcomes(outcomes, ids)
  stopifnot(all(x$RecordID %in% ids))
  measured <- unique(x[Parameter %in% time_series_parameters &
    !is.na(Value_analysis) & time_hours >= 0 & time_hours <= 48,
    .(RecordID, Parameter)])
  measured[, ever_measured := TRUE]
  groups <- merge(CJ(RecordID=ids, Parameter=time_series_parameters), measured,
                  by=c('RecordID','Parameter'), all.x=TRUE)
  groups[is.na(ever_measured), ever_measured := FALSE]
  groups <- merge(groups, outcomes[, .(RecordID, death=`In-hospital_death`)],
                  by='RecordID', all.x=TRUE)
  result <- groups[, .(n_measured=sum(ever_measured),
    n_not_measured=sum(!ever_measured),
    deaths_measured=sum(death[ever_measured]),
    deaths_not_measured=sum(death[!ever_measured])), by=Parameter]
  result[, `:=`(death_pct_measured=100*deaths_measured/pmax(n_measured,1L),
    death_pct_not_measured=100*deaths_not_measured/pmax(n_not_measured,1L))]
  result[n_measured==0, death_pct_measured:=NA_real_]
  result[n_not_measured==0, death_pct_not_measured:=NA_real_]
  result[, difference_pp:=death_pct_measured-death_pct_not_measured]
  result[order(-abs(difference_pp), Parameter, na.last=TRUE)]
}
