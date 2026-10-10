source('tests/test-cp2.R')
if (file.exists('R/cp2-run.R')) source('R/cp2-run.R')
stopifnot('OOF comparison implemented'=exists('cp2_compare'))
# Breaks caught: different benchmark/model cohorts, automatic ROC reversal,
# pooled score substituted for mean folds, duplicate/misaligned OOF rows.
o <- data.table(RecordID=as.character(1:12),outcome=rep(c(0,0,1,1),3),outer_fold=rep(1:3,each=4),
 enet_probability=rep(c(.1,.2,.8,.9),3),gam_probability=.5,
 forest_probability=rep(c(.9,.8,.2,.1),3),SAPS_I_score=rep(1:4,3),SOFA_score=rep(4:1,3))
r <- cp2_compare(o,k=3)
stopifnot(r$summary[method=='Elastic net',mean_auc]==1,r$summary[method=='GAM',mean_auc]==.5,
 r$summary[method=='Random forest',mean_auc]==0,r$summary[method=='SAPS-I',sd_auc]==0)
o$SOFA_score[1] <- NA
r <- cp2_compare(o,k=3)
stopifnot(sum(r$common)==11,all(r$fold[fold==1,n]==3),nrow(o)==12,
 nrow(r$fold)==15)
err(cp2_validate_oof(rbind(o,o[1]),as.character(1:12),rep(c(0,0,1,1),3),rep(1:3,each=4)))
cat('CP2 comparison fixtures passed.\n')
# Adjacent doubles must not become tied scores when the final OOF CSV is reloaded.
close <- copy(o)
close[,forest_probability:=rep(c(.5,.5+.Machine$double.eps/2,.5+.Machine$double.eps,.6),3)]
path <- tempfile(fileext='.csv')
cp2_write_oof(close,path)
reloaded <- fread(path);unlink(path)
stopifnot(identical(close$forest_probability,reloaded$forest_probability),
 identical(close$enet_probability,reloaded$enet_probability),
 identical(close$gam_probability,reloaded$gam_probability),
 identical(cp2_auc(close$outcome,close$forest_probability),cp2_auc(reloaded$outcome,reloaded$forest_probability)))
cat('CP2 exact-double OOF CSV roundtrip fixture passed.\n')
