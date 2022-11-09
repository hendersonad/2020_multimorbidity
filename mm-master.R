## Fetch data
library(haven)
library(here)
library(arrow)
library(readr)
library(tidyverse)

source(here::here("mm-filepaths.R"))

for(study in c("asthma", "eczema")){
  study_info <- read_csv(file = paste0(datapath, study, "_patient_info.csv"))
  case_control <- read_csv(file = paste0(datapath, study, "_case_control_set.csv"))
  readcodes <- read_csv(paste0(datapath, study,"_read_chapter.csv"))
  
  ## write as parquet files in local directory
  write_parquet(study_info, sink = paste0(datapath,study,"_patient_info.gz.parquet"))
  write_parquet(case_control, sink = paste0(datapath,study,"_case_control_set.gz.parquet"))
  write_parquet(readcodes, sink = paste0(datapath,study,"_read_chapter.gz.parquet"))
} 
source(here("dofiles/analysis/multimorbidity_preparedata.R"))


## make tables 1 and 2
source(here("dofiles/analysis/tab1-summariseStudy.R"))
source(here("dofiles/analysis/tab2-read-by-age-sex.R"))

## Prepare data

## Run regressions
source(here("dofiles/analysis/networks_e_a.R"))

## plot networks 
source(here("dofiles/analysis/networks_plots.R"))

## delete the original read_chapter files because they are very big indeed and we have the parquet version now
for(study in c("asthma", "eczema")){
  file.remove(paste0(datapath, study,"_read_chapter.csv"))
  file.remove(paste0(datapath, study,"_read_chapter.dta"))
}
