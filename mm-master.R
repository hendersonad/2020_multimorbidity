## Fetch data
library(haven)
library(here)
library(arrow)
library(readr)

source(here::here("mm-filepaths.R"))

for(study in c("asthma", "eczema")){
  study_info <- read_csv(file = paste0(datapath, study, "_patient_info.csv"))
  case_control <- read_csv(file = paste0(datapath, study, "_case_control_set.csv"))
  readcodes <- read.csv(paste0(datapath, study,"_read_chapter.csv"), colClasses = c("integer", "character", "NULL", "character")) 
  
  ## write as parquet files in local directory
  write_parquet(study_info, sink = paste0(datapath,study,"_patient_info.gz.parquet"))
  write_parquet(case_control, sink = paste0(datapath,study,"_case_control_set.gz.parquet"))
  write_parquet(readcodes, sink = paste0(datapath,study,"_read_chapter.gz.parquet"))
} 

## delete the original read_chapter files because they are very big indeed
for(study in c("asthma", "eczema")){
  file.remove(paste0(datapath, study,"_read_chapter.csv"))
}

## make tables 1 and 2
source(here("dofiles/analysis/tab1-summariseStudy.R"))
source(here("dofiles/analysis/tab2-read-by-age-sex.R"))

# Asthma ------------------------------------------------------------------
## Prepare data
source(here("dofiles/analysis/Multimorb_asthma_preparedata.R"))

## Run regressions
source(here("dofiles/analysis/networks4_asthma.R"))

## Run regressions

## plot networks 

# Eczema ------------------------------------------------------------------
## Prepare data
source(here("dofiles/analysis/Multimorb_asthma_preparedata.R"))

## Make tables 
source(here("dofiles/analysis/networks4_asthma.R"))

## Run regressions

## plot networks 