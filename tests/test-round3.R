local({
 if (file.exists('R/build-wide.R')) source('R/build-wide.R')
 stopifnot('Wide helper exists'=exists('build_wide'))
 ids <- as.character(1:4000)
 o <- data.table(RecordID=ids,`SAPS-I`=1,SOFA=1,Length_of_stay=2,Survival=-1,`In-hospital_death`=0)
 # Source-order ties: 90 then 70 at hour 1; earlier value appears later in input.
 x <- data.table(RecordID='1',Parameter=c('HR','HR','HR','HR','HR','HR','Temp','Weight','Weight','Height'),
  time_hours=c(1,1,0,24,48,23.99,3,0,5,0),
  Value_analysis=c(90,70,80,110,120,100,NA,NA,75,1.8))
 x[,Time:=sprintf('%02d:%02d',as.integer(time_hours),as.integer((time_hours%%1)*60))]
 stopifnot(identical(window_24(c(0,23.99,24,48)),c('h0_24','h0_24','h24_48','h24_48')))
 expect_error(window_24(c(-1,49)),'0.*48')
 w <- build_wide(x,ids,o)$wide
 validate_wide(w,ids,o)
 r <- w[RecordID=='1']
 stopifnot(nrow(w)==4000,ncol(w)==455,uniqueN(w$RecordID)==4000,
 r$HR_h0_24_count==4,r$HR_h0_24_first==80,r$HR_h0_24_last==100,
 r$HR_h0_24_min==70,r$HR_h0_24_max==100,r$HR_h0_24_mean==85,
 r$HR_h24_48_count==2,r$HR_h24_48_first==110,r$HR_h24_48_last==120,
 r$HR_h24_48_mean==115,r$Temp_h0_24_count==0,is.na(r$Temp_h0_24_mean),
 is.na(r$AdmissionWeight),r$Weight_h0_24_mean==75,r$Height==1.8,
 w[RecordID=='2',HR_h0_24_count]==0)
 ties <- copy(x[Parameter=='HR' & time_hours==1]);ties[,time_hours:=0]
 s <- summarize_windows(ties)
 stopifnot(s$first==90,s$last==70,s$count==2,s$mean==80)
 conflict <- rbind(x,data.table(RecordID='1',Parameter='Height',time_hours=0,Value_analysis=170,Time='00:00'))
 expect_error(build_wide(conflict,ids,o),'Conflicting admission')
 same <- rbind(x,x[Parameter=='Height'])
 stopifnot(build_wide(same,ids,o)$wide[RecordID=='1',Height]==1.8)
 wrong <- copy(o);wrong[1,RecordID:='2']
 expect_error(build_wide(x,ids,wrong),'4000')
 # Real integration: rebuild from preserved long evidence and existing audit rules.
 long <- load_set_a('data/set-a')$data
 a <- audit_measurements(long)$long
 stopifnot(sum(a$hard_invalid)==33L)
 o <- fread('data/Outcomes-a.txt',colClasses=list(character='RecordID'),check.names=FALSE)
 ids <- sort(unique(long$RecordID))
 result <- build_wide(a,ids,o); validate_wide(result$wide,ids,o)
 stopifnot(sum(result$wide$In_hospital_death)==554,
  sum(as.matrix(result$wide[, count_columns(), with=FALSE]))==sum(!is.na(a$Value_analysis[a$Parameter %in% time_series_parameters])))
 cat('Round 3 tests passed: 4000 rows, 455 columns, 4000 IDs, 554 deaths.\n')
})
