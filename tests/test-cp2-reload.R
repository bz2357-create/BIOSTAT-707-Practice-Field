# Run as a fresh R process: saved prediction must not depend on namespaces
# left loaded by fitting, and GAM effect extraction must survive reload.
library(data.table)
for(f in c('cp2-data','cp2-preprocess','cp2-models','cp2-plots')) source(paste0('R/',f,'.R'))
b <- readRDS('output/cp2_final_model.rds')
fixture <- readRDS('output/cp2_prediction_fixture.rds')
stopifnot(max(abs(cp2_predict(b,fixture$predictors)-fixture$probability))<1e-12)
g <- readRDS('output/cp2_interpretation_gam.rds')
w <- fread('output/cp2_modeling_table.csv')
w[,MechVent_h24_48_documented_1:=as.integer(!is.na(MechVent_h24_48_max) & MechVent_h24_48_max==1)]
x <- as.data.frame(w[,g$preprocess$predictors,with=FALSE])
stopifnot(!any(names(x) %in% cp2_forbidden))
stopifnot(length(cp2_predict(g,x[1:10,]))==10)
e <- cp2_effect_data(g,x,'Age')
stopifnot(nrow(e$curve)==200)
cat('CP2 fresh-process saved prediction/effect extraction passed.\n')
