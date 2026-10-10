# CP2 uses CP1 functions without altering their semantics or outputs.
cp2_predictors <- function() c('Age','Gender','Height','ICUType','AdmissionWeight',feature_columns())
cp2_forbidden <- c('RecordID','In_hospital_death','In-hospital_death',
                  'SAPS_I','SAPS-I','SOFA','Length_of_stay','Survival')
cp2_zero_missing <- function(x) {
 z <- copy(x)
 mask <- z$Parameter %in% c('Height','Weight') & !is.na(z$Value_analysis) & z$Value_analysis==0
 changes <- z[mask,.(RecordID,Time,time_hours,Parameter,Value_raw,Value)]
 changes[,reason:='CP2: zero height/weight is not a usable body-size measurement']
 z[mask,Value_analysis:=NA_real_]
 list(long=z,changes=changes)
}
cp2_ventilation <- function(x,ids) {
 documented <- unique(x[Parameter=='MechVent' & time_hours>=24 & time_hours<=48 &
                         !is.na(Value_analysis) & Value_analysis==1,RecordID])
 data.table(RecordID=ids,MechVent_h24_48_documented_1=as.integer(ids %in% documented))
}
cp2_data <- function() {
 if (!dir.exists('data/set-a') || !file.exists('data/Outcomes-a.txt')) stop('Missing allowed set-a inputs')
 loaded <- load_set_a('data/set-a'); long <- loaded$data
 bin_six(long$time_hours) # Fail for any out-of-window source observation.
 allowed <- c(time_series_parameters,'RecordID','Age','Gender','Height','ICUType')
 if (!all(long$Parameter %in% allowed)) stop('Unexpected source Parameter')
 ids <- sort(unique(long$RecordID)); check_population(ids)
 o <- fread('data/Outcomes-a.txt',colClasses=list(character='RecordID'),check.names=FALSE)
 validate_outcomes(o,ids)
 if (anyNA(o$RecordID) || any(!nzchar(o$RecordID))) stop('Missing outcome ID')
 audit <- audit_measurements(long); cleaned <- cp2_zero_missing(audit$long)
 built <- build_wide(cleaned$long,ids,o); w <- built$wide
 ventilation <- cp2_ventilation(cleaned$long,w$RecordID)
 predictors <- as.data.frame(w[,cp2_predictors(),with=FALSE])
 predictors$MechVent_h24_48_documented_1 <- ventilation$MechVent_h24_48_documented_1
 benchmarks <- w[,.(RecordID,SAPS_I_score=SAPS_I,SOFA_score=SOFA)]
 for (p in c('SAPS_I_score','SOFA_score')) {
  if (any(benchmarks[[p]]< -1,na.rm=TRUE)) stop('Undocumented negative benchmark score')
  set(benchmarks,which(benchmarks[[p]]==-1),p,NA_real_)
 }
 list(wide=w,x=predictors,y=w$In_hospital_death,ids=w$RecordID,benchmarks=benchmarks,
      cleaning=cleaned$changes,hard_summary=audit$summary,flags=audit$flags,
      descriptors=built$descriptor_audit,duplicates=built$duplicates,
      source_summary=data.table(source_rows=nrow(long),stays=length(ids),
       hard_invalid=sum(audit$long$hard_invalid),sentinel_missing=sum(is.na(long$Value)),
       min_hour=min(long$time_hours),max_hour=max(long$time_hours)),
      input_manifest=data.table(path=c(loaded$files,'data/Outcomes-a.txt'),
       md5=unname(tools::md5sum(c(loaded$files,'data/Outcomes-a.txt')))))
}
cp2_dictionary <- function() {
 # Units from the official Challenge variable definitions. Counts have unit records.
 units <- c(Age='years',Gender='0 female / 1 male',Height='cm',ICUType='1 CCU / 2 CSRU / 3 MICU / 4 SICU',
  AdmissionWeight='kg',Albumin='g/dL',ALP='IU/L',ALT='IU/L',AST='IU/L',Bilirubin='mg/dL',BUN='mg/dL',
  Cholesterol='mg/dL',Creatinine='mg/dL',DiasABP='mmHg',FiO2='fraction',GCS='3–15 score',Glucose='mg/dL',
  HCO3='mmol/L',HCT='%',HR='beats/min',K='mEq/L',Lactate='mmol/L',Mg='mmol/L',MAP='mmHg',
  MechVent='0/1 documentation',Na='mEq/L',NIDiasABP='mmHg',NIMAP='mmHg',NISysABP='mmHg',
  PaCO2='mmHg',PaO2='mmHg',pH='pH units',Platelets='cells/nL',RespRate='breaths/min',SaO2='%',
  SysABP='mmHg',Temp='degrees C',TroponinI='ug/L',TroponinT='ug/L',Urine='mL',WBC='cells/nL',Weight='kg')
 rationale <- c(admission='Demographics, body size and care setting describe case mix.',
  first='Earliest observed level describes the start of each window.',
  last='Latest observed level describes the end of each window.',
  min='Lowest observed value summarizes physiological extremes.',
  max='Highest observed value summarizes physiological extremes.',
  mean='Average observed level summarizes window physiology.',
  count='Monitoring intensity and measurement absence can carry predictive information.',
  documentation='Recorded ventilation can reflect treatment and illness severity.')
 rows <- lapply(cp2_predictors(),function(n) {
  admission <- n %in% names(units)[1:5]
  stat <- if (admission) 'admission' else sub('.*_','',n)
  parent <- if (admission) n else sub('_h.*','',n)
  window <- if (admission) 'time 0' else if (grepl('_h0_24_',n)) '[0,24)' else '[24,48]'
  definition <- if (admission) 'Time-zero descriptor; no later-value replacement' else switch(stat,
   count='Number of valid records; zero = never validly measured',first='First valid value; time then source order',
   last='Last valid value; time then source order',min='Minimum valid value',max='Maximum valid value',
   mean='Arithmetic mean of valid records (not time weighted)')
  data.table(predictor=n,source=parent,group=stat,window=window,definition=definition,
   unit=if (stat=='count') 'records' else unname(units[parent]),rationale=rationale[stat],
   model_pool='Elastic net / forest')
 })
 rbindlist(c(rows,list(data.table(predictor='MechVent_h24_48_documented_1',source='MechVent',
  group='documentation',window='[24,48]',definition='At least one valid recorded MechVent = 1; zero means no such documentation',
  unit='0/1',rationale=rationale['documentation'],model_pool='GAM only'))))
}
cp2_gam_variables <- c('Age','Gender','ICUType','HR_h24_48_mean','Temp_h24_48_mean',
 'MAP_h24_48_mean','RespRate_h24_48_mean','GCS_h24_48_min','Creatinine_h24_48_last',
 'BUN_h24_48_last','WBC_h24_48_last','Platelets_h24_48_last','Lactate_h24_48_last',
 'MechVent_h24_48_documented_1','MAP_h24_48_count','Creatinine_h24_48_count','Lactate_h24_48_count')
