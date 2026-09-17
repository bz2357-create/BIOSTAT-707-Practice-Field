local({
 if (file.exists('R/informative-missingness.R')) source('R/informative-missingness.R')
 stopifnot('Informative-missingness helper exists'=exists('informative_missingness'))
 ids <- as.character(1:4000)
 o <- data.table(RecordID=ids,`SAPS-I`=1,SOFA=1,Length_of_stay=2,Survival=-1,
                 `In-hospital_death`=as.integer(ids %in% c('1','3')))
 x <- data.table(RecordID=c('1','1','2','3'),Parameter='HR',time_hours=c(0,48,24,5),
                 Value_analysis=c(80,90,70,NA_real_))
 z <- informative_missingness(x,ids,o)
 stopifnot(nrow(z)==37,all(z$n_measured+z$n_not_measured==4000),
 z[Parameter=='HR',n_measured]==2,z[Parameter=='HR',deaths_measured]==1,
 z[Parameter=='HR',deaths_not_measured]==1,
 z[Parameter=='HR',death_pct_measured]==50,
 abs(z[Parameter=='HR',difference_pp]-(50-100/3998))<1e-12,
 z[Parameter=='pH',n_measured]==0,is.na(z[Parameter=='pH',death_pct_measured]),
 !any(is.nan(z$difference_pp)))
 all_measured <- data.table(RecordID=ids,Parameter='HR',time_hours=0,Value_analysis=80)
 q <- informative_missingness(all_measured,ids,o)
 stopifnot(q[Parameter=='HR',n_not_measured]==0,is.na(q[Parameter=='HR',death_pct_not_measured]))
 cat('Round 4 informative-missingness tests passed.\n')
})
