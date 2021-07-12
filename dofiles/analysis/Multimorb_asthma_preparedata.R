# Prepare CPRD extract (19/04/2021) for multimorbidity analysis
# Code adapted from David Prieto-Merino
# Amy Mulick, LSHTM
# Begin 19 April 2021


# packages ----------------------------------------------------------------
pacman::p_load('haven')



# load raw data -----------------------------------------------------------

if(grepl("macd0015", Sys.info()["nodename"])){
  datapath <- "/Volumes/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis/"
  dcc <- read.csv(file=paste0(datapath, "asthma_case_control_set.csv"), stringsAsFactors = F)
    dpi <- read.csv(file=paste0(datapath, "asthma_patient_info.csv"), stringsAsFactors = F)
    drc <- haven::read_dta(paste0(datapath,'asthma_read_chapter.dta')) 
    # drc <- read.csv(file="asthma_read_chapter.csv", colClasses = c("integer", "character", "NULL", "character"))
  
}else{
  setwd("Z:/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis")
  datapath <- "Z:/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis"
  dcc <- read.csv(file="asthma_case_control_set.csv", stringsAsFactors = F)
  dpi <- read.csv(file="asthma_patient_info.csv", stringsAsFactors = F)
  drc <- haven::read_dta('asthma_read_chapter.dta') 
  # drc <- read.csv(file="asthma_read_chapter.csv", colClasses = c("integer", "character", "NULL", "character"))
}




sum(dcc$caseid==dcc$contid)
length(unique(dcc$caseid))
length(unique(dcc$contid))
length(unique(drc$patid))

# In the dcc there are 2,300,000 rows associated but actually only 1,393,367 different control ids and 460,052 case ids. 
# In dpi there are 1,984,015 patients
# In drc there are 1,905,316 patients with 56,055,636 events



## Prepare data for analyis

# get case for each control

# Get IDs of events and cases
ide <- unique(dcc$caseid)  # ID of asthma pat
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
drd <- drc[,-3]
names(drd) <- c("pa","ed","rc")
drd$pa <- drd$pa - mipid + 1
drd$ed <- as.numeric(as.Date("2020-12-12") - as.Date(drd$ed, "%d%b%Y"))/365.25


## Save simplified data
save(dpd, dcd, drd, file=paste0(datapath,"simpdata_asthma.RData"))


