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

get_table1 <- function(study = "asthma"){
  test <- read_csv(file = here::here("datafiles",paste0(study, "_patient_info.csv")))
  case_control <- read_csv(file = here::here("datafiles",paste0(study, "_case_control_set.csv")))
  cases <- case_control %>%
    select(caseid) %>% 
    distinct() %>%
    mutate(exposed = 1)
  controls <- case_control %>%
    select(contid) %>% 
    distinct() %>%
    mutate(exposed = 0)
  patid_CC  <- test %>%
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
  
  # pacman::p_load("pubh")
  # test %>%
  #   select(-c(id, setno)) %>%
  #   #copy_labels(test) %>%
  #   cross_tab(case ~ sex +.) %>%
  #   theme_pubh()  
  
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
  readcodes <- haven::read_dta(here::here("datafiles", paste0(study,"_read_chapter.dta")))
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

# who is in both? ----------------------------------------------------------
asthma_CC <- read_csv(file = here::here("datafiles",paste0("asthma", "_case_control_set.csv")))
asthma_cases <- asthma_CC %>%
  select(caseid) %>% 
  distinct() %>%
  mutate(cohort = "asthma")
asthma_conts <- asthma_CC %>%
  select(contid) %>% 
  distinct() %>%
  mutate(cohort = "asthma")

eczema_CC <- read_csv(file = here::here("datafiles",paste0("eczema", "_case_control_set.csv")))
eczema_cases <- eczema_CC %>%
  select(caseid) %>% 
  distinct() %>%
  mutate(cohort = "eczema")
eczema_conts <- eczema_CC %>%
  select(contid) %>% 
  distinct() %>%
  mutate(cohort = "eczema")

head(eczema_cases); head(asthma_cases)

both_surveys <- full_join(eczema_cases, asthma_cases, by = c("caseid")) %>%
  arrange(caseid)

summ_cohorts <- both_surveys %>%
  count(cohort.x, cohort.y) %>%
  mutate(name = ifelse(!is.na(cohort.x) & !is.na(cohort.y), "Both",
                       ifelse(!is.na(cohort.x) & is.na(cohort.y), "Eczema only",
                              ifelse(is.na(cohort.x) & !is.na(cohort.y), "Asthma only",NA)))) %>%
  select(-starts_with("cohort")) 
summ_cohorts
summ_full_case <- summ_cohorts %>%
  bind_rows(
    filter(summ_cohorts, name == "Both")
  ) %>%
  mutate(id = c(0,0,1,1)) %>%
  pivot_wider(values_from = n, names_from = id) %>%
  rename(eczema_n = `0`, asthma_n = `1`) %>%
  mutate(eczema_pc = eczema_n / sum(eczema_n, na.rm = T),
         asthma_pc = asthma_n / sum(asthma_n, na.rm = T)) %>%
  select(var = name, eczema_n, eczema_pc , asthma_n , asthma_pc)
summ_full_case

both_controls <- full_join(eczema_conts, asthma_conts, by = c("contid")) %>%
  arrange(contid)
summ_controls <- both_controls %>%
  count(cohort.x, cohort.y) %>%
  mutate(name = ifelse(!is.na(cohort.x) & !is.na(cohort.y), "Both",
                       ifelse(!is.na(cohort.x) & is.na(cohort.y), "Eczema only",
                              ifelse(is.na(cohort.x) & !is.na(cohort.y), "Asthma only",NA)))) %>%
  select(-starts_with("cohort")) 
summ_full_cont <- summ_controls %>%
  bind_rows(
    filter(summ_controls, name == "Both")
  ) %>%
  mutate(id = c(0,0,1,1)) %>%
  pivot_wider(values_from = n, names_from = id) %>%
  rename(eczema_n = `0`, asthma_n = `1`) %>%
  mutate(eczema_pc = eczema_n / sum(eczema_n, na.rm = T),
         asthma_pc = asthma_n / sum(asthma_n, na.rm = T)) %>%
  select(var = name, eczema_n, eczema_pc , asthma_n , asthma_pc)
summ_full_cont

# full table 1 -------------------------------------------------------------
new_names <- c("var", "AcontN", "AcontPC", "AcaseN", "AcasePC", "EcontN", "EcontPC", "EcaseN", "EcasePC")
tab1 <- left_join(slice(table1_asthma, 1:30),
                  slice(table1_eczema, 1:30), by = "var")
names(tab1) <- new_names
tab1 <- bind_rows(
  slice(tab1, 1:2) %>%
  mutate(
    Ecase = paste0(prettyNum(EcaseN, big.mark = ",", scientific = F), " (", signif(EcasePC,3),")"),
    Econt = paste0(prettyNum(EcontN, big.mark = ",", scientific = F), " (", signif(EcontPC,3),")"),
    Acase = paste0(prettyNum(AcaseN, big.mark = ",", scientific = F), " (", signif(AcasePC,3),")"),
    Acont = paste0(prettyNum(AcontN, big.mark = ",", scientific = F), " (", signif(AcontPC,3),")")
  ),
  slice(tab1, -(1:2)) %>%
  mutate(
    Ecase = paste0(prettyNum(EcaseN, big.mark = ",", scientific = F), " (", signif(EcasePC*100,3),")"),
    Econt = paste0(prettyNum(EcontN, big.mark = ",", scientific = F), " (", signif(EcontPC*100,3),")"),
    Acase = paste0(prettyNum(AcaseN, big.mark = ",", scientific = F), " (", signif(AcasePC*100,3),")"),
    Acont = paste0(prettyNum(AcontN, big.mark = ",", scientific = F), " (", signif(AcontPC*100,3),")")
  )  
)

tab1 <- tab1 %>% left_join(names, by = c("var")) %>%
  mutate_at("name", ~ifelse(is.na(.), var, .)) %>%
  select(-var, var = name)
  
names(summ_full_case) <- c("var", "AcaseN", "AcasePC", "EcaseN", "EcasePC")
names(summ_full_cont) <- c("var", "AcontN", "AcontPC", "EcontN", "EcontPC")
summ_full2 <- summ_full_case %>%
  bind_cols(select(summ_full_cont, -var)) %>%
  mutate(arrange = c("both", "one", "one")) %>%
  group_by(arrange) %>%
  summarise_all(~max(., na.rm = T)) %>%
  select(-var) %>%
  rename(var = arrange) %>%
  mutate(
    Ecase = paste0(prettyNum(EcaseN, big.mark = ",", scientific = F), " (", signif(EcasePC*100,3),")"),
    Econt = paste0(prettyNum(EcontN, big.mark = ",", scientific = F), " (", signif(EcontPC*100,3),")"),
    Acase = paste0(prettyNum(AcaseN, big.mark = ",", scientific = F), " (", signif(AcasePC*100,3),")"),
    Acont = paste0(prettyNum(AcontN, big.mark = ",", scientific = F), " (", signif(AcontPC*100,3),")")
  )

blank_rows <- slice(tab1, 1:3) %>%
  mutate_all(~NA)

tab1_out <- bind_rows(tab1, summ_full2, blank_rows) %>%
  select("var",  "Ecase", "Econt", "Acase", "Acont") %>%
  mutate(order = c(1,5:11,13:14,16:35,2:4,12,15)) %>%
  arrange(order) %>% select(-order)

write.csv(tab1_out, here::here("out/table1_v2.csv"))

# Read chapter bar charts -------------------------------------------------
asthma_out <- table1_asthma %>%
  mutate(exposure = "Asthma")
eczema_out <- table1_eczema %>%
  mutate(exposure = "Eczema")
DF_out <- bind_rows(
    asthma_out,
    eczema_out
  ) %>%
  pivot_wider(names_from = exposure, 
              id_cols = var, 
              values_from = c(control_n, control_pc, case_n, case_pc)) %>%
  select(var, ends_with("Asthma"), ends_with("Eczema")) %>%
  mutate_if(is.numeric, ~round(.,2)) %>%
  mutate(asthma_dif = case_pc_asthma-control_pc_asthma,
         eczema_dif = case_pc_eczema-control_pc_eczema)
DF_out
write_csv(DF_out, path = here::here("out", "table1.csv"))


fig1 <- DF_out %>% 
  filter(!var %in% c("Female", "Male", "n", "age")) %>%
  select(var, control_n_asthma, control_n_eczema, 
         case_n_asthma, case_n_eczema) %>%
  pivot_longer(names_to = "cohort", cols = -var) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig1 <- fig1 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.))



ggplot(fig1, aes(x = name, y = value, colour = exp, fill = exp, group = exp)) +
  geom_col(position = position_dodge(), alpha = 0.2) +
  facet_wrap(~condition) +
  labs(x = "Read Chapter", y = "No. of primary care records", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  theme_bw() +
  theme(strip.background = element_blank(), 
        axis.text.x = element_text(hjust = 1, angle = 65))
dev.copy(pdf, here::here("out/Fig1.pdf"), width = 8, height = 5)
  dev.off()


fig2 <- DF_out %>% 
  filter(!var %in% c("Female", "Male", "n", "age")) %>%
  select(var, control_pc_asthma, control_pc_eczema, 
         case_pc_asthma, case_pc_eczema) %>%
  pivot_longer(names_to = "cohort", cols = -var) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig2 <- fig2 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.))

ggplot(fig2, aes(x = name, y = value, colour = exp, fill = exp, group = exp)) +
  geom_col(position = position_dodge(), alpha = 0.2) +
  facet_wrap(~condition) +
  labs(x = "Read Chapter", y = "Percentage of all primary care records by Read chapter", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  theme_bw() +
  theme(strip.background = element_blank(), 
        axis.text.x = element_text(hjust = 1, angle = 65))

dev.copy(pdf, here::here("out/Fig1_pc.pdf"), width = 8, height = 5)
  dev.off()
  