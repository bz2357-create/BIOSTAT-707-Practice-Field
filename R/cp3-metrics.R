cp3_validate <- function(y,p,probability=TRUE) {
 if(!length(y) || length(y)!=length(p) || anyNA(y) || !all(y %in% 0:1) || any(!is.finite(p))) stop('Invalid evaluation input')
 if(probability && any(p<0 | p>1)) stop('Invalid probabilities')
}
cp3_auc_boot <- function(y,score,R=2000L,seed=70732026L) {
 cp3_validate(y,score,FALSE)
 n1 <- sum(y==1); n0 <- sum(y==0)
 if(!n1 || !n0) return(list(auc=NA_real_,lower=NA_real_,upper=NA_real_,draws=rep(NA_real_,R),n=length(y),deaths=n1,status='Undefined: one outcome class'))
 if(R<2) stop('Need at least two bootstrap replicates')
 set.seed(seed);pos <- which(y==1);neg <- which(y==0)
 draws <- replicate(R,{i <- c(pos[sample.int(n1,n1,replace=TRUE)],neg[sample.int(n0,n0,replace=TRUE)]); cp2_auc(y[i],score[i])})
 ci <- unname(quantile(draws,c(.025,.975)))
 list(auc=cp2_auc(y,score),lower=ci[1],upper=ci[2],draws=draws,n=length(y),deaths=n1,status='OK')
}
cp3_threshold <- function(y,p,threshold=.20) {
 cp3_validate(y,p)
 if(length(threshold)!=1 || threshold<=0 || threshold>1) stop('Invalid threshold')
 flag <- p>=threshold
 TP <- sum(flag & y==1);FP <- sum(flag & y==0);FN <- sum(!flag & y==1);TN <- sum(!flag & y==0)
 se <- if(TP+FN) TP/(TP+FN) else NA_real_
 ppv <- if(TP+FP) TP/(TP+FP) else NA_real_
 data.table(threshold=threshold,n=length(y),TP=TP,FP=FP,FN=FN,TN=TN,sensitivity=se,PPV=ppv,flagged_per_100=100*mean(flag),event1=if(anyNA(c(se,ppv))) NA_real_ else min(se,ppv))
}
cp3_pr <- function(y,p) {
 cp3_validate(y,p)
 g <- data.table(y=y,p=p)[,.(positive=sum(y),total=.N),by=p][order(-p)]
 g[,`:=`(tp=cumsum(positive),flagged=cumsum(total))]
 n1 <- sum(y)
 g[,`:=`(recall=if(n1) tp/n1 else NA_real_,precision=tp/flagged)]
 ap <- if(n1) sum(diff(c(0,g$recall))*g$precision) else NA_real_
 list(curve=rbind(data.table(p=Inf,recall=0,precision=1),g[,.(p,recall,precision)]),average_precision=ap,prevalence=mean(y))
}
cp3_dca <- function(y,model_p,sofa_p,thresholds=seq(.05,.40,.005)) {
 cp3_validate(y,model_p);cp3_validate(y,sofa_p)
 if(any(thresholds<=0 | thresholds>=1)) stop('Invalid DCA thresholds')
 rbindlist(lapply(thresholds,function(t) {
  nb <- function(p) {f <- p>=t;mean(f & y==1)-mean(f & y==0)*t/(1-t)}
  data.table(threshold=t,method=c('Model','SOFA (A-mapped)','Treat all','Treat none'),net_benefit=c(nb(model_p),nb(sofa_p),mean(y)-(1-mean(y))*t/(1-t),0),n=length(y))
 }))
}
cp3_calibration <- function(y,p,smooth=TRUE) {
 cp3_validate(y,p);eps <- 1e-8;lp <- qlogis(pmin(1-eps,pmax(eps,p)));warnings <- character()
 capture <- function(expr) withCallingHandlers(tryCatch(expr,error=function(e) {warnings <<- c(warnings,conditionMessage(e));NULL}),warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
 summary <- data.table(n=length(y),deaths=sum(y),prevalence=mean(y),mean_risk=mean(p),intercept=NA_real_,intercept_lower=NA_real_,intercept_upper=NA_real_,slope=NA_real_,slope_lower=NA_real_,slope_upper=NA_real_,brier=mean((y-p)^2),scaled_brier=if(mean(y)>0 && mean(y)<1) 1-mean((y-p)^2)/(mean(y)*(1-mean(y))) else NA_real_,clipped=sum(p<eps | p>1-eps),status='OK')
 curve <- data.table(p=numeric(),fit=numeric(),lower=numeric(),upper=numeric())
 if(length(unique(y))<2) {
  summary[,status:='Undefined: one outcome class'];return(list(summary=summary,curve=curve,support=data.table(p=p),warnings='One outcome class'))
 }
 dd <- data.frame(y=y,lp=lp)
 citl <- capture(glm(y~1+offset(lp),data=dd,family=binomial()))
 slope <- capture(glm(y~lp,data=dd,family=binomial()))
 if(!is.null(citl) && isTRUE(citl$converged)) {
  ci <- coef(citl)[1]+c(-1,1)*1.96*sqrt(vcov(citl)[1,1]);summary[,`:=`(intercept=unname(coef(citl)[1]),intercept_lower=ci[1],intercept_upper=ci[2])]
 } else warnings <- c(warnings,'Calibration intercept did not converge')
 if(!is.null(slope) && isTRUE(slope$converged) && is.finite(coef(slope)[2])) {
  estimate <- unname(coef(slope)[2]); ci <- estimate+c(-1,1)*1.96*sqrt(vcov(slope)[2,2]);summary[,`:=`(slope=estimate,slope_lower=ci[1],slope_upper=ci[2])]
 } else warnings <- c(warnings,'Calibration slope undefined or did not converge')
 if(smooth && length(unique(lp))>=5) {
  formula <- as.formula('y ~ s(lp,k=5)',env=asNamespace('mgcv'))
  fit <- capture(mgcv::gam(formula,data=dd,family=binomial(),method='REML'))
  if(!is.null(fit) && isTRUE(fit$converged)) {
   grid <- seq(min(lp),max(lp),length.out=200)
   pred <- capture(predict(fit,newdata=data.frame(lp=grid),type='link',se.fit=TRUE))
   if(!is.null(pred)) curve <- data.table(p=plogis(grid),fit=plogis(pred$fit),lower=plogis(pred$fit-1.96*pred$se.fit),upper=plogis(pred$fit+1.96*pred$se.fit))
  } else warnings <- c(warnings,'Calibration smoother did not converge')
 }
 if(length(warnings)) summary[,status:=paste(unique(warnings),collapse='; ')]
 list(summary=summary,curve=curve,support=data.table(p=p),warnings=unique(warnings))
}
