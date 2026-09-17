# Read all fields as text first so original Time and Value strings survive.
read_patient <- function(path) {
  fail <- function(message) stop(basename(path), ': ', message, call. = FALSE)
  filename <- basename(path)
  if (!grepl('^[0-9]+[.]txt$', filename)) fail('invalid filename RecordID')
  id <- sub('[.]txt$', '', filename)
  # fread can still auto-detect a header after a preamble; check the first line.
  if (!identical(readLines(path, n = 1L, warn = FALSE), 'Time,Parameter,Value')) {
    fail('expected source columns Time,Parameter,Value on the first line')
  }
  x <- withCallingHandlers(
    data.table::fread(path, skip = 0, header = TRUE, sep = ',',
                     colClasses = 'character', na.strings = NULL,
                     strip.white = FALSE, blank.lines.skip = FALSE,
                     check.names = FALSE, showProgress = FALSE),
    warning = function(w) fail(paste('reader warning:', conditionMessage(w)))
  )
  if (!identical(names(x), c('Time', 'Parameter', 'Value'))) {
    fail('expected source columns Time,Parameter,Value')
  }
  if (!nrow(x)) fail('empty patient table')
  if (anyNA(x$Parameter) || any(!nzchar(trimws(x$Parameter)))) fail('empty Parameter')
  # Allow signed elapsed hours for auditing; never silently drop out-of-range rows.
  valid_time <- !is.na(x$Time) & grepl('^-?[0-9]{2,}:[0-5][0-9]$', x$Time)
  if (!all(valid_time)) fail(paste('invalid Time at source row', which(!valid_time)[1]))
  magnitude <- sub('^-', '', x$Time)
  hours <- as.numeric(sub(':.*$', '', magnitude))
  minutes <- as.numeric(sub('^.*:', '', magnitude))
  elapsed <- (hours + minutes / 60) * ifelse(startsWith(x$Time, '-'), -1, 1)
  if (any(!is.finite(elapsed))) fail('non-finite Time')
  raw <- x$Value
  numeric_pattern <- '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
  valid_value <- !is.na(raw) & grepl(numeric_pattern, raw)
  values <- suppressWarnings(as.numeric(raw))
  valid_value <- valid_value & is.finite(values)
  if (!all(valid_value)) fail(paste('invalid numeric Value at source row', which(!valid_value)[1]))
  internal <- which(x$Parameter == 'RecordID')
  if (length(internal) != 1L || raw[internal] != id) {
    fail('exactly one internal RecordID must agree with filename')
  }
  cleaned <- values
  cleaned[values == -1] <- NA_real_
  data.table::data.table(RecordID = id, Time = x$Time, time_hours = elapsed,
                         Parameter = x$Parameter, Value_raw = raw, Value = cleaned)
}

load_set_a <- function(directory) {
  files <- sort(list.files(directory, pattern = '[.]txt$', full.names = TRUE,
                           recursive = TRUE))
  if (length(files) != 4000L) stop('Expected exactly 4000 patient files; found ', length(files))
  ids <- sub('[.]txt$', '', basename(files))
  if (anyDuplicated(basename(files)) || anyDuplicated(ids)) stop('Duplicate filename/RecordID')
  if (!all(grepl('^[0-9]+$', ids))) stop('Invalid filename RecordID')
  tables <- lapply(files, read_patient)
  long <- data.table::rbindlist(tables, use.names = TRUE)
  stopifnot(data.table::uniqueN(long$RecordID) == 4000L,
            nrow(long) == sum(vapply(tables, nrow, integer(1))),
            setequal(unique(long$RecordID), ids))
  list(data = long, files = files)
}
