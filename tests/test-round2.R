if (file.exists('R/audit-missingness.R')) source('R/audit-missingness.R')
stopifnot('Round 2 helper exists' = exists('audit_measurements'))
x <- data.table(RecordID = '1', Time = '00:00', time_hours = 0,
 Parameter = c('pH','pH','Temp','Height','HR','Gender','ICUType','MechVent','GCS','FiO2','SaO2','pH'),
 Value_raw = c('734','7.34','-17.8','1.8','0','2','5','2','2','1.2','101','-1'),
 Value = c(734,7.34,-17.8,1.8,0,2,5,2,2,1.2,101,NA_real_))
a <- audit_measurements(x)
stopifnot(identical(a$long$Value_raw,x$Value_raw), identical(a$long$Value,x$Value),
 all(is.na(a$long$Value_analysis[c(1,3,6:11)])),
 a$long$Value_analysis[2]==7.34, a$long$Value_analysis[4]==1.8,
 a$long$Value_analysis[5]==0, !a$long$hard_invalid[12], nrow(x)==12)
stopifnot(identical(bin_six(c(0,5.99,6,12,18,24,30,36,42,48)),
                    c(1L,1L,2L,3L,4L,5L,6L,7L,8L,8L)))
expect_error(bin_six(c(-1,49)), '0.*48')
ids <- as.character(1:4000)
stopifnot(length(time_series_parameters)==37L, !anyDuplicated(time_series_parameters),
          'Weight' %in% time_series_parameters)
y <- data.table(RecordID=c('1','1','2'), Parameter=c('HR','HR','pH'),
 time_hours=c(0,48,6), Value_analysis=c(80,90,NA_real_))
m <- measurement_availability(y, ids)
stopifnot(m$overall[Parameter=='HR',n_measured]==1,
 m$overall[Parameter=='HR',p_missing]==3999/4000,
 m$overall[Parameter=='pH',n_measured]==0,
 all(m$temporal$denominator==4000), nrow(m$temporal)==37*8,
 m$temporal[Parameter=='HR' & bin==8,n_measured]==1,
 m$halves[Parameter=='HR',p_first]==1/4000,
 m$halves[Parameter=='HR',p_second]==1/4000)
z <- data.table(RecordID=c('1','1'), Parameter='Weight', time_hours=c(0,12),
 Value_analysis=c(NA_real_,70))
stopifnot(admission_availability(z,ids)[Parameter=='Weight',n_measured]==0)
o <- data.table(RecordID=ids, `SAPS-I`=1, SOFA=1, Length_of_stay=2,
 Survival=-1, `In-hospital_death`=0)
validate_outcomes(o,ids)
stopifnot(all(o$Survival == -1))
bad <- copy(o); bad[1, `In-hospital_death`:=2]
expect_error(validate_outcomes(bad,ids),'0/1')
bad <- copy(o); bad[1,RecordID:='99999']
expect_error(validate_outcomes(bad,ids),'RecordID')
expect_error(validate_outcomes(o[-1],ids),'4000')
cat('Round 2 synthetic tests passed.\n')

# Integration checks use the provided local outcomes and source-file IDs.
actual_ids <- sub('[.]txt$', '', basename(list.files('data/set-a',pattern='[.]txt$',recursive=TRUE)))
actual_outcomes <- fread('data/Outcomes-a.txt',colClasses=list(character='RecordID'),check.names=FALSE)
validate_outcomes(actual_outcomes,actual_ids)
cat('Outcome integration checks passed: 4000 rows and matching unique RecordIDs.\n')
