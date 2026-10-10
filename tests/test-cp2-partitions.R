library(data.table)
o <- fread('output/cp2_oof_predictions.csv',colClasses=list(character='RecordID'))
inner <- fread('output/cp2_inner_folds.csv',colClasses=list(character='RecordID'))
audit <- readRDS('output/cp2_preprocessing_audit.rds');n <- 0L
check <- function(z) {
 if (is.null(z$preprocess)) {for(a in z) check(a);return(invisible(NULL))}
 outer <- if(z$context=='full') rep(TRUE,nrow(o)) else o$outer_fold!=as.integer(sub('outer_','',z$context))
 pool <- o$RecordID[outer]
 if(!is.null(z$inner_fold)) {
  records <- inner[context==z$context]
  stopifnot(setequal(records$RecordID,pool))
  expected_tr <- records[inner_fold!=z$inner_fold,RecordID]
  expected_va <- records[inner_fold==z$inner_fold,RecordID]
 } else {
  expected_tr <- pool;expected_va <- o$RecordID[!outer]
 }
 stopifnot(!anyDuplicated(z$training_ids),!anyDuplicated(z$assessment_ids),
  setequal(z$training_ids,expected_tr),setequal(z$assessment_ids,expected_va),
  !length(intersect(z$training_ids,z$assessment_ids)))
 n <<- n+1L
}
for(z in audit) check(z)
stopifnot(n==50L)
cat('All 50 preprocessing states match exact outer/inner training and assessment assignments.\n')
