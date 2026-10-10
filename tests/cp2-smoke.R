library(data.table)
for (f in c('load-set-a','audit-missingness','build-wide','cp2-data','cp2-preprocess','cp2-models')) source(paste0('R/',f,'.R'))
d <- cp2_data(); f <- cp2_folds(d$ids,d$y,5,7072026)
tr <- which(f!=1); inner <- cp2_folds(d$ids[tr],d$y[tr],3,7072027)
idx <- tr[inner!=1]
start <- proc.time()[['elapsed']]
m <- cp2_fit_model('forest',d$x[idx,],d$y[idx],cp2_predictors(),
                   list(mtry_rule='third',node=5,trees=500),7072027)
seconds <- proc.time()[['elapsed']]-start
writeLines(c(paste('500-tree third-mtry/node-5 training-only smoke seconds:',seconds),
 paste('training stays:',length(idx),'design columns:',length(m$preprocess$columns)),
 'This timing probe used no outer-assessment outcomes or scores.'),'output/cp2_smoke_timing.txt')
print(data.table(stays=nrow(d$wide),columns=ncol(d$wide),deaths=sum(d$y),
 death_percent=100*mean(d$y),hard_invalid=d$source_summary$hard_invalid,
 height_zero=sum(d$cleaning$Parameter=='Height'),weight_zero=sum(d$cleaning$Parameter=='Weight'),
 smoke_seconds=seconds))
