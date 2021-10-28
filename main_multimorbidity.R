## Fetch data
library(haven)
library(here)
library(arrow)
library(readr)


datapath <- "/Volumes/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis/"

for(study in c("asthma", "eczema")){
  study_info <- read_csv(file = paste0(datapath, study, "_patient_info.csv"))
  case_control <- read_csv(file = paste0(datapath, study, "_case_control_set.csv"))
  readcodes <- haven::read_dta(paste0(datapath, study,"_read_chapter.dta")) 
  
  ## write as parquet files in local directory
    write_parquet(study_info, sink = here("datafiles", paste0(study, "_patient_info.gz.parquet")))
    write_parquet(case_control, sink = here("datafiles", paste0(study, "_case_control_set.gz.parquet")))
    write_parquet(readcodes, sink = here("datafiles", paste0(study, "_read_chapter.gz.parquet")))
} 


# Asthma ------------------------------------------------------------------
## Prepare data
source(here("dofiles/analysis/Multimorb_asthma_preparedata.R"))

## Make tables 
source(here("dofiles/analysis/networks4_asthma.R"))

## Run regressions

## plot networks 