cp3_plots <- function(r) {
 library(ggplot2);theme_set(theme_minimal(base_size=12))
 pr <- ggplot(r$pr$curve,aes(x=recall,y=precision))+geom_step(direction='vh',color='#216b8a',linewidth=.8)+
  geom_hline(yintercept=r$pr$prevalence,linetype='dashed',color='#a14c34')+coord_cartesian(xlim=c(0,1),ylim=c(0,1))+
  labs(x='Recall / sensitivity',y='Precision / positive predictive value',subtitle=sprintf('Set B: death-rate baseline %.3f; average precision %.3f',r$pr$prevalence,r$pr$average_precision))
 calibration <- lapply(c('b','c'),function(s) {
  z <- r$calibration[[s]]
  ggplot(z$curve,aes(x=p,y=fit))+geom_ribbon(aes(ymin=lower,ymax=upper),fill='#c7dce6')+
   geom_line(color='#216b8a',linewidth=.8)+geom_abline(slope=1,intercept=0,linetype='dashed')+
   geom_rug(data=z$support,aes(x=p),inherit.aes=FALSE,sides='b',alpha=.035)+coord_cartesian(xlim=c(0,1),ylim=c(0,1))+
   labs(x='Unchanged model-predicted mortality risk',y='Smoothed observed mortality risk',subtitle=paste('Set',toupper(s),': logistic spline diagnostic, approximate 95% pointwise band'))
 });names(calibration) <- c('B','C')
 dca <- lapply(c('B','C'),function(s) {
  ggplot(r$dca[split==s],aes(x=threshold,y=net_benefit,color=method,linetype=method))+geom_line(linewidth=.8)+
   geom_vline(xintercept=.2,color='grey50',linetype='dotted')+scale_color_manual(values=c('Model'='#216b8a','SOFA (A-mapped)'='#a14c34','Treat all'='#777777','Treat none'='#333333'))+
   labs(x='Risk threshold',y='Net benefit per patient',subtitle=paste('Set',s,': identical SOFA-available cohort; dotted line = prespecified 20%'))+
   theme(legend.position='bottom')
 });names(dca) <- c('B','C')
 z <- head(r$coefficients[order(-abs(coefficient))],25)
 coefficients <- ggplot(z,aes(x=coefficient,y=reorder(predictor,coefficient)))+geom_vline(xintercept=0,color='grey70')+
  geom_segment(aes(x=0,xend=coefficient,yend=predictor),color='#216b8a')+geom_point(color='#216b8a')+
  labs(x='Frozen log-odds coefficient per Set A training SD',y=NULL,subtitle='25 largest absolute coefficients; original CP2 fit, no external refit')+theme(axis.text.y=element_text(size=9))
 out <- list(pr=pr,calibration_B=calibration$B,calibration_C=calibration$C,dca_B=dca$B,dca_C=dca$C,coefficients=coefficients)
 for(n in names(out)) ggsave(paste0('output/cp3_',n,'.png'),out[[n]],width=9,height=if(n=='coefficients') 8 else 6,dpi=140)
 out
}
