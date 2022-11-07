# Prepare CPRD extract (19/04/2021) for multimorbidity analysis
# Code adapted from David Prieto-Merino
# Amy Mulick, LSHTM
# Begin 19 April 2021

library(here)
library(arrow)
source(here("mm-filepaths.R"))

# load raw data -----------------------------------------------------------
for(study in c("asthma", "eczema")){
  dpi <- read_parquet(paste0(datapath,study,"_patient_info.gz.parquet"))
  dcc <- read_parquet(paste0(datapath,study,"_case_control_set.gz.parquet"))
  drc <-  read_parquet(paste0(datapath,study,"_read_chapter.gz.parquet"))
  
  ## how much data after covid pandemic?
  drc$date2 <- lubridate::parse_date_time(drc$eventdate, orders = "dbY")
  table(drc$date2 > as.Date("2020-04-01"))
  
  sum(dcc$caseid==dcc$contid)
  length(unique(dcc$caseid))
  length(unique(dcc$contid))
  length(unique(drc$patid))
  
  ## Prepare data for analyis
  # get case for each control
  # Get IDs of events and cases
  ide <- unique(dcc$caseid)  # ID of eczema pat
  idc <- unique(dcc$contid)  # ID of control pat
  idc <- idc[!(idc %in% ide)]
  
  # simplifed patient data
  dpd <- dpi[, c("patid", "gender", "realyob", "tod")] # changed deathdate to tod 21 April 2021
  names(dpd) <- c("pa","mu","tb","td")
  mipid <- min(dpi$patid)  # minimum patient ID
  dpd$pa <- dpd$pa - mipid + 1  # Recode patient ID
  dpd$mu <- grepl("Female", dpd$mu)
  dpd$tb <- (dpd$tb - 1900)/10
  dpd$td <- as.numeric(as.Date(dpd$td, "%d%b%Y") - as.Date("1900-01-01"))/(10*365.25)
  dpd$ca <- dpd$pa %in% (ide - mipid +1)
  
  # Simplify case-control data
  dcd <- dcc[dcc$contid %in% idc,]
  names(dcd) <- c("ca","co")
  dcd$ca <- dcd$ca - mipid + 1
  dcd$co <- dcd$co - mipid + 1
  
  # Simplify events data
  drd <- drc
  names(drd) <- c("pa","ed","rc")
  drd$pa <- drd$pa - mipid + 1
  drd$ed <- as.numeric(as.Date("2020-12-12") - as.Date(drd$ed, "%d%b%Y"))/365.25
  
  
  ## Save simplified data
  save(dpd, dcd, drd, file=paste0(datapath,"simpdata_", study, ".RData"))
  
  
  mipid <- 1028
  refde <- "2020-12-12"
  refyb <- 1900
  
  # Extract practice id from each patient (original minid = 1028)
  dpw <- mutate(dpd, pr=c(pa + mipid - 1) %% 1000)
  
  # Assign the control to the case with less controls
  dc1 <- group_by(dcd, ca) %>% mutate(n=n()) %>% ungroup() %>% arrange(co, n) %>% group_by(co) %>% summarise(can=ca[1], nca=n[1])
  dpw <- left_join(dpw, dc1, by=c("pa"="co")) %>% mutate(can=ifelse(is.na(can),pa,can))
  
  # backtransform event dates & YOB
  drd$ed <- as.Date(refde) - drd$ed * 365.25
  dpw$tb <- as.Date(paste0((10*dpw$tb + refyb),"-07-01"))
  dpw$td <- dpw$td*10*365.25+as.Date("1900-01-01")
  dpw$td[is.na(dpw$td)] <- as.Date("2020-06-30")
  dpw$fua <- as.numeric((dpw$td - dpw$tb)/365.25)
  
  # Add first last time of event
  drw <- group_by(drd, pa, rc) %>% summarise(fi=min(ed)) %>% pivot_wider(id_cols=pa, names_from=rc, values_from=c(fi)) %>% ungroup()
  names(drw)[-1] <- paste0('fi_', names(drw)[-1])
  
  # merge pat data with event data
  dpw <- left_join(dpw[, c('pa', 'mu', 'ca', 'pr', 'can', 'tb', 'td', 'fua')], drw, by="pa")
  
  # Turn end of followup dates and dates of events into ages 
  for(c in grep('fi_', names(dpw))) dpw[,c] <- as.numeric( dpw[,c] - dpw$tb ) /365.25
  
  
  save(dpw, file=paste0(datapath, "datawide_", study, ".RData"))
}

