# Breaks caught: assessment leakage, reversed AUROC, outcome in design,
# wrong zero handling, category row loss, and overlapping/incomplete folds.
library(data.table)
for (f in c('load-set-a','audit-missingness','build-wide','cp2-data','cp2-preprocess')) {
 p <- paste0('R/',f,'.R'); if (file.exists(p)) source(p)
}
stopifnot('CP2 preprocessing implemented'=exists('cp2_fit_preprocess'))
err <- function(expr) stopifnot(inherits(try(force(expr),silent=TRUE),'try-error'))
stopifnot(cp2_auc(c(0,0,1,1),c(1,2,3,4))==1,
 cp2_auc(c(0,0,1,1),c(4,3,2,1))==0,
 cp2_auc(c(0,0,1,1),rep(7,4))==.5)
err(cp2_auc(rep(1,4),1:4))
x <- data.table(RecordID=c('1','1','1','1'),Time=c('00:00','00:00','24:00','48:00'),
 time_hours=c(0,0,24,48),Parameter=c('Height','Weight','Weight','MechVent'),
 Value_raw=c('0','0','80','1'),Value=c(0,0,80,1))
a <- audit_measurements(x); z <- cp2_zero_missing(a$long)
stopifnot(identical(z$long$Value_raw,x$Value_raw),identical(z$long$Value,x$Value),
 all(is.na(z$long$Value_analysis[1:2])),z$long$Value_analysis[3]==80,nrow(z$changes)==2,
 a$long$Value_analysis[1]==0,summarize_windows(z$long)[Parameter=='Weight',count]==1)
stopifnot(cp2_ventilation(z$long,c('1','2'))$MechVent_h24_48_documented_1[1]==1,
 cp2_ventilation(z$long,c('1','2'))$MechVent_h24_48_documented_1[2]==0)
ids <- sprintf('%03d',1:60); y <- rep(c(0,1),30)
f <- cp2_folds(ids,y,5,707)
stopifnot(identical(f,cp2_folds(ids,y,5,707)),all(table(f,y)>0),length(f)==60,
 identical(f[60:1],cp2_folds(ids[60:1],y[60:1],5,707)))
for (k in 1:5) {
 tr <- which(f!=k); va <- which(f==k); stopifnot(!length(intersect(tr,va)))
 inn <- cp2_folds(ids[tr],y[tr],3,708)
 stopifnot(all(table(inn,y[tr])>0),length(inn)==length(tr))
}
train <- data.frame(Age=c(10,20,NA,30),Gender=c(0,1,NA,1),ICUType=c(1,2,2,NA),
 HR_h24_48_mean=rep(NA_real_,4),MAP_h24_48_count=c(0,0,0,0))
vars <- names(train)
p <- cp2_fit_preprocess(train,vars,scale=TRUE)
a <- cp2_apply_preprocess(p,train)
stopifnot(p$medians['Age']==20,all(is.finite(a)),nrow(a)==4,
 abs(mean(a[,'Age']))<1e-12,abs(sd(a[,'Age'])-1)<1e-12,
 !'HR_h24_48_mean' %in% colnames(a),!'MAP_h24_48_count' %in% colnames(a))
held <- data.frame(Age=c(NA,999999),Gender=c(99,NA),ICUType=c(99,4),
 HR_h24_48_mean=c(1,2),MAP_h24_48_count=c(7,8))
p2 <- cp2_fit_preprocess(train,vars,scale=TRUE)
b <- cp2_apply_preprocess(p,held)
stopifnot(identical(p,p2),all(is.finite(b)),nrow(b)==2,identical(colnames(a),colnames(b)),
 abs(b[1,'Age'])<1e-12)
# Inner and outer assessment changes cannot change fitted state or analysis matrix.
for (k in c(3,5)) {
 d <- data.frame(Age=seq_len(60),Gender=rep(c(0,1),30),ICUType=rep(1:4,15))
 folds <- cp2_folds(ids,y,k,700+k); tr <- folds!=1; va <- !tr
 pp <- cp2_fit_preprocess(d[tr,],names(d),TRUE)
 d[va,'Age'] <- -1e9; d[va,'ICUType'] <- 999
 stopifnot(identical(pp,cp2_fit_preprocess(d[tr,],names(d),TRUE)))
}
err(cp2_fit_preprocess(data.frame(RecordID=1:4), 'RecordID'))
err(cp2_fit_preprocess(data.frame(SOFA=1:4),'SOFA'))
err(cp2_apply_preprocess(p,held[,setdiff(names(held),'Age')]))
stopifnot(length(cp2_predictors())==449,
 !any(cp2_predictors() %in% c('RecordID','In_hospital_death','SAPS_I','SOFA','Length_of_stay','Survival')))
cat('CP2 data/preprocessing fixtures passed.\n')
