prefix <- normalizePath(Sys.getenv("CONDA_PREFIX"), mustWork = TRUE)
stopifnot(startsWith(normalizePath(R.home()), paste0(prefix, "/")),
          all(startsWith(normalizePath(.libPaths()), paste0(prefix, "/"))))
library(data.table)
if (file.exists('R/load-set-a.R')) source('R/load-set-a.R')
stopifnot('Loader is implemented' = exists('read_patient'))
d <- tempfile('set-a-test-'); dir.create(d)
f <- file.path(d, '123456.txt')
write_fixture <- function(rows, header = 'Time,Parameter,Value') {
  writeLines(c(header, rows), f)
}
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr); NA_character_}, error = function(e) conditionMessage(e))
  stopifnot(!is.na(msg), grepl(pattern, msg))
}
write_fixture(c('00:00,RecordID,123456', '01:30,Height,-1',
                '49:01,HR,9999', '00:10,Temp,-2', '00:20,Weight,70.00'))
x <- read_patient(f)
stopifnot(identical(x$Time, c('00:00','01:30','49:01','00:10','00:20')),
          x$time_hours[2] == 1.5, abs(x$time_hours[3] - (49 + 1/60)) < 1e-10,
          x$Value_raw[2] == '-1', x$Value_raw[5] == '70.00',
          is.na(x$Value[2]), x$Value[3] == 9999, x$Value[4] == -2,
          all(x$RecordID == '123456'), nrow(x) == 5)
expect_error(load_set_a(d), '4000')
for (case in list(
  c('00:00,RecordID,999999','RecordID'),
  c('00:00,HR,80','RecordID'),
  c('00:60,RecordID,123456','Time'),
  c('00:00,RecordID,abc','numeric'),
  c('00:00,RecordID,','numeric'),
  c('00:00,RecordID,Inf','numeric'),
  c('00:00,,123456','Parameter'))) {
  write_fixture(case[1]); expect_error(read_patient(f), case[2])
}
write_fixture(c('00:00,RecordID,123456','00:00,RecordID,123456'))
expect_error(read_patient(f), 'RecordID')
write_fixture('00:00,RecordID,123456', 'Time,Variable,Value')
expect_error(read_patient(f), 'columns')
write_fixture(c('00:00,RecordID,123456','-01:30,HR,80'))
stopifnot(read_patient(f)$time_hours[2] == -1.5)
writeLines(c('discarded preamble', 'Time,Parameter,Value', '00:00,RecordID,123456',
             '00:01,HR,90'), f)
expect_error(read_patient(f), 'columns|reader warning')
unlink(d, recursive = TRUE)
cat('All loader fixture tests passed.\n')

source("tests/test-round2.R")

source("tests/test-round3.R")

source("tests/test-round4.R")
