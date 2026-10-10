source('tests/test-cp2-models.R')
if(file.exists('R/cp2-plots.R')) source('R/cp2-plots.R')
stopifnot('Effect bands implemented'=exists('cp2_effect_data'))
# Breaks caught: absolute-risk label/curve instead of centered term, missing bands,
# missing original support, and wrong ROC orientation.
e <- cp2_effect_data(g,x,'HR_h24_48_mean')
stopifnot(nrow(e$curve)==200,all(is.finite(e$curve$fit)),
 all(e$curve$lower<=e$curve$fit & e$curve$fit<=e$curve$upper),
 nrow(e$support)==sum(!is.na(x$HR_h24_48_mean)),
 all(e$curve$fit>=e$curve$lower),e$term=='s(HR_h24_48_mean)')
roc <- cp2_roc_data(c(0,0,1,1),c(1,2,3,4),'perfect')
stopifnot(attr(roc,'auc')==1,all(roc$fpr>=0 & roc$fpr<=1),
 all(roc$tpr>=0 & roc$tpr<=1))
cat('CP2 plotting fixtures passed.\n')
