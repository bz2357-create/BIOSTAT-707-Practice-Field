cp3_contributions <- function(bundle,x) {
 loadNamespace('glmnet')
 design <- cp2_apply_preprocess(bundle$preprocess,x)
 b <- as.matrix(coef(bundle$model,s=bundle$hyperparameters$lambda))[,1]
 terms <- sweep(design,2,b[colnames(design)],'*'); intercept <- unname(b['(Intercept)'])
 p <- plogis(intercept+rowSums(terms))
 stopifnot(max(abs(p-cp3_predict(bundle,x)))<1e-10)
 list(intercept=intercept,contributions=terms,reconstructed_p=p,coefficients=data.table(predictor=names(b)[-1],coefficient=unname(b[-1])))
}
cp3_sofa_mapping <- function(set_a) {
 d <- data.frame(y=set_a$y,score=set_a$benchmarks$SOFA_score)
 d <- d[complete.cases(d),];stopifnot(length(unique(d$y))==2)
 fit <- glm(y~score,data=d,family=binomial())
 stopifnot(isTRUE(fit$converged),all(is.finite(coef(fit))))
 list(coefficients=unname(coef(fit)),n=nrow(d),deaths=sum(d$y),training_set='set-a',formula='logit(risk) = intercept + slope * raw SOFA')
}
cp3_discrimination <- function(y,p,benchmarks,R=2000L,seed=70732026L) {
 common <- complete.cases(benchmarks)
 out <- list();draws <- list()
 add <- function(method,pop,idx,score,offset) {
  a <- cp3_auc_boot(y[idx],score[idx],R,seed+offset)
  out[[length(out)+1L]] <<- data.table(method=method,population=pop,n=a$n,deaths=a$deaths,auc=a$auc,lower=a$lower,upper=a$upper,status=a$status)
  draws[[paste(method,pop,sep=':')]] <<- a$draws
 }
 add('Elastic net','All stays',rep(TRUE,length(y)),p,1)
 for(j in 1:3) {
  method <- c('Elastic net','SAPS-I','SOFA')[j]
  score <- list(p,benchmarks$SAPS_I_score,benchmarks$SOFA_score)[[j]]
  if(!any(common)) stop('No common benchmark cohort')
  add(method,'Common scores',common,score,10+j)
 }
 list(summary=rbindlist(out),draws=draws,common=common)
}
cp3_subgroups <- function(x,y,p,R=2000L,seed=70732026L) {
 groups <- list(Age=ifelse(is.na(x$Age),'Unknown',ifelse(x$Age<65,'<65',ifelse(x$Age<80,'65–79','>=80'))),
  Sex=ifelse(is.na(x$Gender),'Unknown',ifelse(x$Gender==0,'Female',ifelse(x$Gender==1,'Male','Unknown'))),
  ICU=ifelse(is.na(x$ICUType),'Unknown',paste0('Type ',x$ICUType)))
 out <- list();j <- 0L
 for(axis in names(groups)) for(group in sort(unique(groups[[axis]]))) {
  j <- j+1L;idx <- groups[[axis]]==group
  a <- cp3_auc_boot(y[idx],p[idx],R,seed+j)
  c <- cp3_calibration(y[idx],p[idx],smooth=FALSE)$summary
  out[[j]] <- data.table(axis=axis,group=group,n=sum(idx),deaths=sum(y[idx]),auc=a$auc,auc_lower=a$lower,auc_upper=a$upper,intercept=c$intercept,intercept_lower=c$intercept_lower,intercept_upper=c$intercept_upper,small_group=min(sum(y[idx]),sum(1-y[idx]))<20,status=paste(a$status,c$status,sep='; '))
 }
 rbindlist(out)
}
cp3_error_cases <- function(bundle,d,p) {
 contrib <- cp3_contributions(bundle,d$x)
 survivors <- which(d$y==0);deaths <- which(d$y==1)
 chosen <- c(head(survivors[order(-p[survivors],d$ids[survivors])],5),head(deaths[order(p[deaths],d$ids[deaths])],5))
 public <- rbindlist(lapply(seq_along(chosen),function(j) {
  i <- chosen[j];z <- contrib$contributions[i,];top <- head(order(-abs(z)),5)
  drivers <- vapply(top,function(k) {
   name <- names(z)[k];raw_name <- sub('__.*$','',name);raw <- d$x[[raw_name]][i]
   sprintf('%s [raw %s; contribution %+.3f]',name,ifelse(is.na(raw),'missing',format(raw,digits=4)),z[k])
  },character(1))
  data_review_flag <- max(abs(z))>5 || d$quality$missing_fraction[i]>.5 || d$quality$hard_invalid[i]>0 || d$quality$untyped_records[i]>0
  dominant <- names(z)[which.max(abs(z))]
  concern <- if(max(abs(z))>5) paste0('Source-scale/unit or data-entry review warranted: ',dominant,' contributes ',round(z[which.max(abs(z))],2),' log-odds units alone. This is a diagnostic flag, not proof of bad data; values and predictions remain unchanged.') else if(d$quality$missing_fraction[i]>.5 || d$quality$hard_invalid[i]>0 || d$quality$untyped_records[i]>0) 'Data-quality/missingness concern coexists with model error; it does not establish its cause.' else 'Model overlap or unobserved course is plausible; available data cannot determine the cause.'
  data.table(case=paste0(if(j<=5) 'Survivor-' else 'Death-',if(j<=5) j else j-5),outcome=d$y[i],risk=p[i],Age=d$x$Age[i],Gender=d$x$Gender[i],ICUType=d$x$ICUType[i],missing_fraction=d$quality$missing_fraction[i],hard_invalid=d$quality$hard_invalid[i],untyped_records=d$quality$untyped_records[i],data_review_flag=data_review_flag,top_contributions=paste(drivers,collapse='; '),intercept=contrib$intercept,all_contributions_sum=sum(z),judgment=concern)
 }))
 list(public=public,private=data.table(case=public$case,RecordID=d$ids[chosen]),coefficients=contrib$coefficients)
}
cp3_analyze <- function(bundle,datasets,R=2000L) {
 # This benchmark-only mapping is estimated on A before any external metric.
 mapping <- cp3_sofa_mapping(datasets$a)
 preds <- lapply(datasets[c('b','c')],function(d) cp3_predict(bundle,d$x))
 disc <- list();cal <- list();dca <- list();thresholds <- list();cohort <- list()
 for(split in c('b','c')) {
  message('Evaluating Set ',toupper(split),' (bootstrap intervals)')
  d <- datasets[[split]];p <- preds[[split]];offset <- if(split=='b') 100L else 10000L
  disc[[split]] <- cp3_discrimination(d$y,p,d$benchmarks,R,70732026L+offset)
  cal[[split]] <- cp3_calibration(d$y,p)
  idx <- !is.na(d$benchmarks$SOFA_score)
  sofa <- plogis(mapping$coefficients[1]+mapping$coefficients[2]*d$benchmarks$SOFA_score[idx])
  dca[[split]] <- cp3_dca(d$y[idx],p[idx],sofa);dca[[split]][,split:=toupper(split)]
  thresholds[[split]] <- cp3_threshold(d$y,p);thresholds[[split]][,split:=toupper(split)]
  cohort[[split]] <- data.table(split=toupper(split),stays=length(d$y),deaths=sum(d$y),death_percent=100*mean(d$y),common_scores=sum(disc[[split]]$common),SOFA_available=sum(idx),SAPS_available=sum(!is.na(d$benchmarks$SAPS_I_score)),untyped_records=nrow(d$untyped),untyped_stays=uniqueN(d$untyped$RecordID),descriptor_conflicts=nrow(d$conflicts))
 }
 cv <- fread('artifacts/cp2-cv-summary.csv')
 discrimination <- rbindlist(lapply(names(disc),function(s) {z <- copy(disc[[s]]$summary);z[,split:=toupper(s)];z}))
 cmp <- merge(discrimination[population=='Common scores'],cv[,.(method,cv_mean=mean_auc,cv_sd=sd_auc,cv_n=n)],by='method',all.x=TRUE)
 difference <- rbindlist(lapply(c('All stays','Common scores'),function(pop) {
  bd <- disc$b$draws[[paste('Elastic net',pop,sep=':')]];cd <- disc$c$draws[[paste('Elastic net',pop,sep=':')]]
  ci <- quantile(bd-cd,c(.025,.975));data.table(population=pop,difference=disc$b$summary[method=='Elastic net' & population==pop,auc]-disc$c$summary[method=='Elastic net' & population==pop,auc],lower=unname(ci[1]),upper=unname(ci[2]))
 }))
 pr <- cp3_pr(datasets$b$y,preds$b)
 subgroups <- cp3_subgroups(datasets$b$x,datasets$b$y,preds$b,R,70752026L)
 cases <- cp3_error_cases(bundle,datasets$b,preds$b)
 list(cohort=rbindlist(cohort),predictions=preds,discrimination=discrimination,cv_comparison=cmp,difference=difference,calibration=cal,pr=pr,dca=rbindlist(dca),thresholds=rbindlist(thresholds),subgroups=subgroups,coefficients=cases$coefficients,cases=cases$public,cases_private=cases$private,sofa_mapping=mapping,bootstrap_R=R)
}
