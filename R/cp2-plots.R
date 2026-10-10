cp2_roc_data <- function(y,score,method) {
 r <- pROC::roc(y,score,levels=c(0,1),direction='<',quiet=TRUE)
 stopifnot(abs(as.numeric(pROC::auc(r))-cp2_auc(y,score))<1e-12)
 d <- data.table(method=method,fpr=1-r$specificities,tpr=r$sensitivities)
 attr(d,'auc') <- as.numeric(pROC::auc(r));d
}
cp2_effect_data <- function(bundle,x,variable) {
 design <- as.data.frame(cp2_apply_preprocess(bundle$preprocess,x))
 observed <- x[[variable]][!is.na(x[[variable]])]
 term <- paste0('s(',variable,')')
 if (!term %in% rownames(mgcv::summary.gam(bundle$model)$s.table)) stop('Requested plot is not a fitted smooth')
 grid <- design[rep(1,200),,drop=FALSE]
 grid[[variable]] <- seq(min(observed),max(observed),length.out=200)
 pred <- mgcv::predict.gam(bundle$model,newdata=grid,type='terms',terms=term,se.fit=TRUE)
 curve <- data.table(variable=variable,x=grid[[variable]],fit=as.numeric(pred$fit),se=as.numeric(pred$se.fit))
 curve[,`:=`(lower=fit-1.96*se,upper=fit+1.96*se)]
 # These evaluations describe the fitted shape without imposing an anticipated shape.
 q <- unname(quantile(observed,c(.1,.5,.9)))
 profiles <- design[rep(1,3),,drop=FALSE];profiles[[variable]] <- q
 f <- as.numeric(mgcv::predict.gam(bundle$model,newdata=profiles,type='terms',terms=term))
 list(curve=curve,support=data.table(x=observed),term=term,
  summary=data.table(variable=variable,observed_n=length(observed),imputed_n=sum(is.na(x[[variable]])),
   minimum=min(observed),q10=q[1],median=q[2],q90=q[3],maximum=max(observed),
   contribution_q10=f[1],contribution_median=f[2],contribution_q90=f[3],
   edf=mgcv::summary.gam(bundle$model)$s.table[term,'edf']))
}
cp2_make_plots <- function(result) {
 library(ggplot2)
 theme_set(theme_minimal(base_size=12))
 coef <- result$coefficients[retained==TRUE]
 top <- head(coef[order(-abs(standardized_coefficient))],25)
 coefficient <- ggplot(top,aes(x=standardized_coefficient,y=reorder(predictor,standardized_coefficient)))+
  geom_vline(xintercept=0,color='grey65')+geom_segment(aes(x=0,xend=standardized_coefficient,yend=predictor),color='#246987')+
  geom_point(color='#246987',size=2)+labs(x='Log-odds coefficient per training SD',y=NULL,
   subtitle='25 largest absolute nonzero coefficients; intercept excluded')+
  theme(axis.text.y=element_text(size=9),panel.grid.major.y=element_blank())
 ggsave('output/cp2_coefficients.png',coefficient,width=9,height=8,dpi=150)
 stab <- result$stability[retained_folds>0]
 stab_top <- head(stab[order(-retained_folds,-abs(standardized_coefficient),na.last=TRUE)],25)
 stability <- ggplot(stab_top,aes(x=retained_folds,y=reorder(predictor,retained_folds)))+
  geom_col(fill='#42654a',width=.65)+scale_x_continuous(breaks=0:5,limits=c(0,5))+
  labs(x='Outer fits retaining the predictor (out of 5)',y=NULL,
   subtitle='25 predictors with highest frequency; ties by absolute full-fit coefficient')+
  theme(axis.text.y=element_text(size=9),panel.grid.major.y=element_blank())
 ggsave('output/cp2_stability.png',stability,width=9,height=8,dpi=150)
 variables <- c('Age','HR_h24_48_mean','Temp_h24_48_mean')
 labels <- c('Age (years)','Mean heart rate, 24–48 h (beats/min)','Mean temperature, 24–48 h (degrees C)')
 effects <- lapply(variables,function(v) cp2_effect_data(result$full$gam,result$data$x,v))
 temperature_full <- NULL
 effect_plots <- lapply(seq_along(variables),function(i) {
  e <- effects[[i]]
  p <- ggplot(e$curve,aes(x=x,y=fit))+geom_ribbon(aes(ymin=lower,ymax=upper),fill='#c7dce6')+
   geom_line(color='#246987',linewidth=.8)+geom_hline(yintercept=0,linetype='dashed',color='grey50')+
   geom_rug(data=e$support,aes(x=x),inherit.aes=FALSE,alpha=.08)+
   labs(x=labels[i],y='Centered contribution to the log odds',
    subtitle=paste('Approximate 95% pointwise band; EDF =',round(e$summary$edf,2)))
  if (variables[i]=='Temp_h24_48_mean') {
   temperature_full <<- p
   ggsave('output/cp2_gam_temperature_full_range.png',p,width=8,height=5,dpi=150)
   limits <- unname(quantile(e$support$x,c(.01,.99)))
   visible <- e$curve[x>=limits[1] & x<=limits[2]]
   p <- p+coord_cartesian(xlim=limits,ylim=range(c(visible$lower,visible$upper)))+
    labs(subtitle=paste('EDF =',round(e$summary$edf,2),'; view: observed 1st–99th percentiles'))
  }
  ggsave(paste0('output/cp2_gam_',variables[i],'.png'),p,width=8,height=5,dpi=150);p
 })
 fwrite(rbindlist(lapply(effects,`[[`,'curve')),'output/cp2_gam_effect_curves.csv')
 effect_summary <- rbindlist(lapply(effects,`[[`,'summary'))
 fwrite(effect_summary,'output/cp2_gam_effect_summary.csv')
 common <- result$comparison$common;o <- result$oof
 curves <- rbindlist(lapply(names(cp2_methods),function(m)
  cp2_roc_data(o$outcome[common],o[[cp2_methods[m]]][common],m)))
 fwrite(curves,'output/cp2_roc_curve_data.csv')
 pooled <- result$comparison$pooled
 labels_roc <- setNames(sprintf('%s (pooled %.3f)',pooled$method,pooled$pooled_auc),pooled$method)
 roc <- ggplot(curves,aes(x=fpr,y=tpr,color=method))+geom_path(linewidth=.8)+
  geom_abline(slope=1,intercept=0,linetype='dashed',color='grey60')+coord_equal()+
  scale_color_manual(values=c('Elastic net'='#246987','GAM'='#b76721','Random forest'='#42654a',
    'SAPS-I'='#9467bd','SOFA'='#b24756'),breaks=names(cp2_methods),labels=labels_roc)+
  labs(x='False positive rate',y='True positive rate',color=NULL,
   subtitle='Common score-available cohort; one OOF prediction per stay')+theme(legend.position='bottom')+
  guides(color=guide_legend(nrow=3))
 ggsave('output/cp2_roc.png',roc,width=8,height=7,dpi=150)
 list(coefficient=coefficient,stability=stability,effects=effect_plots,effect_summary=effect_summary,temperature_full=temperature_full,roc=roc)
}
