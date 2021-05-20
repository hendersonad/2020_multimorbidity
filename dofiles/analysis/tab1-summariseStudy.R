library(tidyr)
library(dplyr)
library(readr)
library(haven)
library(ggplot2)
library(data.table)
library(here)
library(grid)
library(gridExtra)
library(dataReporter) # https://github.com/ekstroem/dataReporter

names <- read_csv(here("datafiles/chapter_names.csv"))
readcodes <- haven::read_dta(here::here("datafiles", paste0(study,"_read_chapter.dta")))

get_table1 <- function(study = "asthma"){
  study_info <- read_csv(file = here::here("datafiles",paste0(study, "_patient_info.csv")))
  case_control <- read_csv(file = here::here("datafiles",paste0(study, "_case_control_set.csv")))
  cases <- case_control %>%
    select(caseid) %>% 
    distinct() %>%
    mutate(exposed = 1)
  controls <- case_control %>%
    select(contid) %>% 
    distinct() %>%
    mutate(exposed = 0)
  patid_CC  <- study_info %>%
    select(patid, gender, realyob) %>%
    left_join(cases, by = c("patid" = "caseid")) %>%
    mutate(exp = replace_na(exposed, 0)) %>%
    select(-exposed) %>%
    left_join(controls, by =c("patid" = "contid", "exp" = "exposed")) %>%
    mutate_at(c("exp", "gender"), ~as.factor(.))
  
  n_summ <- patid_CC %>% 
    group_by(exp) %>%
    summarise(n = n()) %>%
    pivot_wider(names_from = exp, values_from = n) %>%
    mutate(var = "n", control_pc = NA, case_pc = NA) %>%
    select(var, control_n = `0`, control_pc, case_n = `1`, case_pc)
  age_summ <- patid_CC %>%
    mutate(age = 2015-realyob) %>%
    group_by(exp) %>%
    summarise(med = median(age), sd = sd(age)) %>%
    ungroup() %>%
    pivot_wider(names_from = exp, values_from = c(med, sd)) %>%
    mutate(var = "age") %>%
    select(var, control_n = med_0, control_pc = sd_0, case_n = med_1, case_pc = sd_1)
  age_summ
  agecut_summ <- patid_CC %>%
    mutate(age = 2018-realyob,
           agecut = cut(age, breaks = c(0,18,seq(20,100,20)))) %>%
    group_by(exp, agecut) %>%
    summarise(n = n()) %>%
    ungroup() %>%
    pivot_wider(id_cols = agecut, names_from = exp, values_from = n) %>%
    rename(control_n = `0`, case_n = `1`) %>%
    mutate(control_pc = control_n / sum(control_n),
           case_pc = case_n / sum(case_n)) %>%
    select(var = agecut, control_n, control_pc , case_n , case_pc )
  agecut_summ
  
  (t1 <- table(patid_CC$gender, patid_CC$exp))
  (t1p <- prop.table(t1, margin=2))
  sex_summ <- rbind(t1, t1p) 
  sex_summ_df <- as.data.frame(apply(sex_summ, 2, unlist))
  names(sex_summ_df) <- c("case", "control")
  sex_summ_df$gender <- rownames(sex_summ)
  sex_summ_df <- sex_summ_df %>%
    mutate(var = c("n","n","pc","pc")) %>%
    pivot_wider(id_cols = gender, names_from = var, values_from = c(case, control)) %>%
    select(var = gender, control_n , control_pc, case_n , case_pc)
  
  out1 <- bind_rows(
    n_summ,
    age_summ,
    agecut_summ,
    sex_summ_df
  )
  out1
  
  # READ chapter ------------------------------------------------------------
  DT <- data.table(readcodes)
  PTD <- data.table(patid_CC)
  
  fullDT <- merge(DT, PTD, by = "patid")
  
  readcollapse <- fullDT[, list(sum_read = .N), by=list(exp, readchapter)]
  
  DF <- tibble(readcollapse) %>%
    arrange(readchapter) %>%
    mutate_at("exp", ~ifelse(.==0, "control", "case")) %>%
    pivot_wider(names_from = exp, values_from = sum_read) %>%
    mutate_at(c("control", "case"), ~replace_na(., 0))
  
  DF$control_pc <- signif(prop.table(DF$control), digits = 2)
  DF$case_pc <- signif(prop.table(DF$case), digits = 2)
  
  DF_out <- DF %>%
    select(var = readchapter, control_n = control, control_pc, case_n = case, case_pc)
  DF_out <- bind_rows(
    out1, 
    DF_out
  )
  DF_out
}

table1_asthma <- get_table1(study = "asthma")
table1_eczema <- get_table1(study = "eczema")

  
  