install.packages("tidyverse")
library("tidyverse")

install.packages("pacman")
pacman::p_lload()

files_in <- "Z:/GPRD_GOLD/Ali/2020_multimorbidity/in"
ecz_files <- list.files("Z:/GPRD_GOLD/Ali/2020_multimorbidity/in", pattern = "ecz_extract3")
setwd(files_in)

read.dta("Therapy_extract_ecz_extract3_9.dta")
