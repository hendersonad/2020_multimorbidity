library(tidyr)
library(dplyr)
library(readr)
library(haven)
library(ggplot2)
library(stringr)
library(data.table)
library(here)
library(grid)
library(gridExtra)

datapath <- "/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis/"

theme_ali <- theme_bw() %+replace%
  theme(legend.position = "top",
        strip.background = element_blank(), 
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        axis.text.y = element_text(hjust = 1, angle = 0),
        axis.text.x = element_text(hjust = 1, angle = 0))

theme_ali_noFlip <- theme_bw() %+replace%
  theme(legend.position = "top",
        strip.background = element_blank(), 
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        axis.text.y = element_text(hjust = 0, angle = 0),
        axis.text.x = element_text(angle=0, hjust = 0.5))
        
theme_set(theme_ali)


names <- read_csv(here("codelists/chapter_names.csv"))
if(grepl("macd0015", Sys.info()["nodename"])){
  asthma_CC <- read_csv(file = paste0(datapath, "asthma", "_case_control_set.csv"))
  eczema_CC <- read_csv(file = paste0(datapath, "eczema", "_case_control_set.csv"))
}else{
  asthma_CC <- read_csv(file = here::here("datafiles",paste0("asthma", "_case_control_set.csv")))
  eczema_CC <- read_csv(file = here::here("datafiles",paste0("eczema", "_case_control_set.csv")))
}



## Slightly bodgy way of finding max and min event date
#readcodes <- haven::read_dta(here::here("datafiles", paste0("asthma","_read_chapter.dta")))
## date range of events
min(readcodes$eventdate, na.rm = T)
max(readcodes$eventdate, na.rm = T)
eventdates <- readcodes$eventdate
eventdates[eventdates >= as.Date("2020-07-01") & !is.na(eventdates)] ## any non-NA eventdates that are greater than July 2020

## 1 event in 2052, assume it is 2012
readcodes$eventdate[readcodes$eventdate >= as.Date("2020-07-01") & !is.na(readcodes$eventdate)] <- as.Date("2012-01-01")

min(readcodes$eventdate, na.rm = T)
max(readcodes$eventdate, na.rm = T)

# read summary by age/sex -------------------------------------------------
summ_read_agesex <- function(study = "asthma"){
  if(grepl("macd0015", Sys.info()["nodename"])){
    study_info <- read_csv(file = paste0(datapath, study, "_patient_info.csv"))
    case_control <- read_csv(file = paste0(datapath, study, "_case_control_set.csv"))
    readcodes <- haven::read_dta(paste0(datapath, study, "_read_chapter.dta"))
    
  }else{
    study_info <- read_csv(file = here::here("datafiles",paste0(study, "_patient_info.csv")))
    case_control <- read_csv(file = here::here("datafiles",paste0(study, "_case_control_set.csv")))  
    readcodes <- haven::read_dta(here::here("datafiles", paste0(study,"_read_chapter.dta")))
  }
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
  
  # summary stats -----------------------------------------------------------
  n_summ <- patid_CC %>% 
    group_by(exp) %>%
    summarise(n = n()) %>%
    pivot_wider(names_from = exp, values_from = n) %>%
    mutate(var = "TOTAL", control_pc = NA, case_pc = NA) %>%
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
    mutate(control_pc = (control_n / sum(control_n)),
           case_pc = (case_n / sum(case_n))) %>%
    select(var = agecut, control_n, control_pc , case_n , case_pc )
  agecut_summ
  if(sum(agecut_summ$case_n) != n_summ$case_n){stop("Sum age groups don't match total")}
  
  (t1 <- table(patid_CC$gender, patid_CC$exp))
  (t1p <- prop.table(t1, margin=2))
  sex_summ <- rbind(t1, t1p) 
  sex_summ_df <- as.data.frame(apply(sex_summ, 2, unlist))
  sex_summ_df$gender <- rownames(sex_summ)
  sex_summ_df <- sex_summ_df %>%
    rename(control = `0`, case = `1`) %>%
    mutate(var = c("n","n","pc","pc")) %>%
    pivot_wider(id_cols = gender, names_from = var, values_from = c(case, control)) %>%
    select(var = gender, control_n , control_pc, case_n , case_pc)
  if(sum(sex_summ_df$case_n) != n_summ$case_n){stop("Sum age groups don't match total")}
  
  out1 <- bind_rows(
    n_summ,
    age_summ,
    agecut_summ,
    sex_summ_df
  )
  out1$gender = "All"
  out1$age = NA
  
  # READ chapter ------------------------------------------------------------
  DT <- data.table(readcodes)
  PTD <- data.table(patid_CC)

  ## summarise PATID
  fullPTDcount <- PTD[, list(count = uniqueN(patid)), by=list(exp)]
  
  ## merge Read records with PATID info 
  fullDT <- merge(DT, PTD, by = "patid")
  
  ## get n records per patid per chapter
  fullDT_nobreakdown <- fullDT
    # set key
    fullfirsteventDT <- fullDT_nobreakdown[ fullDT_nobreakdown[, .I[1] , by = list(patid,readchapter)]$V1]
  ## Count number of Read codes by chapter, exposure
  fullreadcollapse <- fullfirsteventDT[, list(sum_read = .N), by=list(exp,readchapter)]
  ## merge in denominator
  fullread <- merge(fullreadcollapse, fullPTDcount, by = c("exp"))
  fullread[,pc_read:=sum_read/count]
  fullread[,gender:="All"]
  fullread[,age:=NA]
  ### Do the same at two age points  
  ## count number of unique Patids with a record
  agePTD <- PTD[,age:=2016-realyob]
  agePTD <- agePTD[age<=23&age>=13 | age<=55&age>=45,] ## filter age = 18 or 50 \pm 5
  agePTD[age<=23, age:=18]
  agePTD[age>=45, age:=50]
  agePTDcount <- agePTD[, list(count = uniqueN(patid)), by=list(exp,gender,age)]
  
  # calculate age
  fullDT <- fullDT[,age:=2016-realyob]
  # filter age = 18 or 50 \pm 5
  fullDT <- fullDT[age<=23&age>=13 | age<=55&age>=45,]
  # replace age == 18 if 18\pm5 or 50 if age == 50\pm5
  fullDT[age<=23, age:=18]
  fullDT[age>=45, age:=50]
  
  # set key
  firsteventDT <- fullDT[ fullDT[, .I[1] , by = list(patid,readchapter)]$V1]
  
  ## Count number of Read codes by chapter, exposure, gender and age
  readcollapse_agesex <- firsteventDT[, list(sum_read = .N), by=list(exp,readchapter,gender,age)]
  
  ## get denominator - total number of patids by group
  #readdenomDT <- fullDT[,.(total = uniqueN(patid)), by=.(exp,gender,age)]
  ## total number of codes by gender age and exp
  #chapter_sum <- fullDT[, .(total = sum(.N)), by=.(exp,gender,age)]
  
  ## merge in denominator by exposure, age and gender
  read_agesex <- merge(readcollapse_agesex, agePTDcount, by = c("exp","gender","age"))
  
  ## calculate total percentage
  read_agesex[,pc_read:=sum_read/count]
  
  ## bit of formatting of fullPTD and chapter_sum so we can bind_rows later
  setnames(agePTDcount, "count", "sum_read")
  agePTDcount[, readchapter:="_AgeCount"]
  agePTDcount[, pc_read:=NA]
  
  setnames(fullPTDcount, "count", "sum_read")
  fullPTDcount[, readchapter:="_FullCount"]
  fullPTDcount[, pc_read:=NA]
  fullPTDcount[,gender:="All"]
  fullPTDcount[,age:=NA]
  
  #setnames(chapter_sum, "total", "sum_read")
  #chapter_sum[, readchapter:="_Total"]
  #chapter_sum[, pc_read:=NA]
  
  DF <- tibble(fullread) %>%
    bind_rows(read_agesex,fullPTDcount, agePTDcount) %>%
    arrange(exp, gender, age, readchapter) %>%
    mutate_at("exp", ~ifelse(.==0, "control", "case")) %>%
    select(-count) %>%
    pivot_wider(names_from = exp, values_from = c(sum_read, pc_read)) 
    #mutate_at(c("total_control", "total_case",
    #            "sum_read_control", "sum_read_case",
    #            "pc_read_control", "pc_read_case"), ~replace_na(., 0))
  
  DF_out <- out1 %>% 
    select(readchapter = var, 
           sum_read_control = control_n, 
           pc_read_control = control_pc, 
           sum_read_case = case_n, 
           pc_read_case = case_pc,
           gender, age) %>% 
    bind_rows(DF) %>%
    select(var = readchapter, 
           gender, age,
           control_n = sum_read_control, control_pc = pc_read_control, 
           case_n = sum_read_case, case_pc = pc_read_case) %>%
    arrange(var, gender, age)
  DF_out 
}

# run table extract -------------------------------------------------------
asthma_tab2 <- summ_read_agesex("asthma")
eczema_tab2 <- summ_read_agesex("eczema")

asthma_out <- asthma_tab2 %>%
  mutate(exposure = "Asthma")
eczema_out <- eczema_tab2 %>%
  mutate(exposure = "Eczema")
DF_out <- bind_rows(
  asthma_out,
  eczema_out
  ) %>%
  pivot_wider(names_from = exposure, 
              id_cols = c(var, gender, age), 
              values_from = c(control_n, control_pc, case_n, case_pc)) %>%
  select(var, gender, age, ends_with("Asthma"), ends_with("Eczema")) %>%
  mutate_if(is.numeric, ~ifelse(.<1, signif(.,2), round(.,2))) %>%
  mutate(asthma_dif = case_pc_Asthma-control_pc_Asthma,
         eczema_dif = case_pc_Eczema-control_pc_Eczema) 

DF_out_all <- DF_out


# AGE and Gender breakdown ------------------------------------------------
DF_out <- DF_out %>%
  filter(!grepl("_",var)) %>%
  filter(!is.na(age))

fig1 <- DF_out %>% 
  select(var, gender, age, control_n_Asthma, control_n_Eczema, 
         case_n_Asthma, case_n_Eczema) %>%
  pivot_longer(names_to = "cohort", cols = -c(var,gender,age)) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig1 <- fig1 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.)) %>%
  mutate(prettyval = prettyNum(value, big.mark = ",", scientific = F))

label <- paste0(unique(fig1$name), collapse = ", ")
write_lines(label, here::here("out/Fig2_caption.txt"))

plot2 <- ggplot(fig1, aes(x = reorder(name, -value), y = value, colour = exp, fill = exp, group = exp)) +
  geom_col(data = filter(fig1, !grepl("_", var)), position = position_dodge(), alpha = 0.2) +
  #geom_text(data = filter(fig1, grepl("_Count", var) & exp == "Case"), aes(x = "U", y = 5e5, label = prettyNum(value, big.mark = ",", scientific = F)), hjust = 0.5) +
  #geom_text(data = filter(fig1, grepl("_Total", var) & exp == "Case"), aes(x = "T", y = 5e5, label = prettyNum(value, big.mark = ",", scientific = F)), hjust = 0.5) +
  #geom_text(data = filter(fig1, grepl("_Count", var) & exp == "Control"), aes(x = "S", y = 5e5, label = prettyNum(value, big.mark = ",", scientific = F)), hjust = 0.5) +
  #geom_text(data = filter(fig1, grepl("_Total", var) & exp == "Control"), aes(x = "R", y = 5e5, label = prettyNum(value, big.mark = ",", scientific = F)), hjust = 0.5) +
  facet_grid(cols = vars(gender, age),
             rows = vars(condition),
            scales = "fixed") +
  labs(x = "Read Chapter", y = "No. of primary care records", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  scale_fill_manual(values = c("Control" = "tomato", "Case" = "darkblue")) +
  scale_colour_manual(values = c("Control" = "tomato", "Case" = "darkblue")) 
plot2
dev.copy(pdf, here::here("out/Fig2.pdf"), width = 10, height = 11)
  dev.off()
  
fig2 <- DF_out %>% 
  select(var, gender, age, control_pc_Asthma, control_pc_Eczema, 
         case_pc_Asthma, case_pc_Eczema) %>%
  pivot_longer(names_to = "cohort", cols = -c(var,gender,age)) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig2 <- fig2 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.)) 

plot2_pc <- ggplot(fig2, aes(x = reorder(name, -value), y = value*100, colour = exp, fill = exp, group = exp)) +
  geom_col(data = filter(fig2, !grepl("_", var)), position = position_dodge(), alpha = 0.2) +
  facet_grid(cols = vars(gender, age),
             rows = vars(condition)) +
  labs(x = "Read Chapter", y = "Percentage of all primary care records by Read chapter", colour = "Exposed", fill = "Exposed") +
  scale_fill_manual(values = c("Control" = "tomato", "Case" = "darkblue")) +
  scale_colour_manual(values = c("Control" = "tomato", "Case" = "darkblue")) +
  coord_flip() 
plot2_pc
dev.copy(pdf, here::here("out/Fig2_pc.pdf"), width = 10, height = 11)
  dev.off()

# Plot chart and table into one object
SummaryTable_age <- DF_out_all %>%
  #filter(grepl("_", var)) %>%
  filter(var == "_AgeCount") %>%
  select(!contains("pc")) %>%
  select(!contains("dif")) %>% 
  pivot_longer(cols = -c(var, gender, age)) %>%
  tidyr::separate(name, into=paste("V",1:3,sep="_")) %>%
  rename(exp = V_1, name = V_3) %>%
  select(-V_2) %>%
  mutate_at("value", ~prettyNum(., big.mark = ",", scientific = F)) %>%
  pivot_wider(id_cols = c(var, name, gender, age, exp), 
              names_from = c(gender, age),
              names_glue = "{gender} ({age})", 
              values_from = value) %>%
  arrange(name, var, exp) %>%
  mutate_at("var", ~str_remove(., "_")) %>%
  mutate_at("var", ~ifelse(.=="Count", "No. patients", "All records")) %>%
  mutate_at("exp", ~str_to_title(.)) %>%
  #mutate_at(vars("name", "var") , ~ifelse(duplicated(.),"",.)) %>%
  select(Condition = name, Variable = var,Exposed = exp,  everything()) 


# Set theme to allow for plotmath expressions
tt <- ttheme_minimal(core = list(fg_params = list(hjust = 0, 
                                                  x = 0.1, 
                                                  fontsize = 9)),
                     colhead=list(fg_params = list(hjust = 0, 
                                                   x = 0.1, 
                                                   fontsize = 10, 
                                                   fontface = "bold",
                                                   parse=TRUE)))

SummaryTable_age[duplicated(SummaryTable_age[, c('Condition', 'Variable')]), 
                 c('Condition', 'Variable')] <- ""
SummaryTable_age[duplicated(SummaryTable_age[,'Condition']), 'Condition'] <- ""
SummaryTable_age
tbl <- tableGrob(SummaryTable_age, rows=NULL, theme=tt)

pdf(here::here("out/Fig2_table.pdf"), width = 10, height = 10)
grid.arrange(plot2, tbl,
             nrow=2,
             as.table=TRUE,
             heights=c(5,1))
dev.off()
pdf(here::here("out/Fig2_table_pc.pdf"), width = 10, height = 10)
grid.arrange(plot2_pc, tbl,
             nrow=2,
             as.table=TRUE,
             heights=c(5,1))
dev.off()

# who is in both? ----------------------------------------------------------
asthma_cases <- asthma_CC %>%
  select(caseid) %>% 
  distinct() %>%
  mutate(cohort = "asthma")
asthma_conts <- asthma_CC %>%
  select(contid) %>% 
  distinct() %>%
  mutate(cohort = "asthma")

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
tab1 <- DF_out_all %>%
  select(!contains("dif")) %>%
  filter(is.na(age)) %>%
  select(-gender, -age)

names(tab1) <- new_names
tab1_sd <- tab1 %>% 
  filter(var %in% c("_FullCount", "age")) %>%
    mutate(
      Ecase = paste0(prettyNum(EcaseN, big.mark = ",", scientific = F), " (", signif(EcasePC,3),")"),
      Econt = paste0(prettyNum(EcontN, big.mark = ",", scientific = F), " (", signif(EcontPC,3),")"),
      Acase = paste0(prettyNum(AcaseN, big.mark = ",", scientific = F), " (", signif(AcasePC,3),")"),
      Acont = paste0(prettyNum(AcontN, big.mark = ",", scientific = F), " (", signif(AcontPC,3),")")
    )
tab1_prop <- tab1 %>%
  filter(!var %in% c("_FullCount","TOTAL","age")) %>%
    mutate(
      Ecase = paste0(prettyNum(EcaseN, big.mark = ",", scientific = F), " (", signif(EcasePC*100,3),")"),
      Econt = paste0(prettyNum(EcontN, big.mark = ",", scientific = F), " (", signif(EcontPC*100,3),")"),
      Acase = paste0(prettyNum(AcaseN, big.mark = ",", scientific = F), " (", signif(AcasePC*100,3),")"),
      Acont = paste0(prettyNum(AcontN, big.mark = ",", scientific = F), " (", signif(AcontPC*100,3),")")
    )  

tab1 <- tab1_sd %>% 
  bind_rows(tab1_prop) %>%
  filter(!var %in% c("W", "V")) %>%
  left_join(names, by = c("var")) %>%
  mutate_at("name", ~ifelse(is.na(.), var, .)) %>%
  select(-var, var = name)

summ_full_case <- summ_full_case %>%
  rename(AcaseN = asthma_n, AcasePC = asthma_pc, 
         EcaseN = eczema_n, EcasePC = eczema_pc)
summ_full_cont <- summ_full_cont %>%
  rename(AcontN = asthma_n, AcontPC = asthma_pc, 
         EcontN = eczema_n, EcontPC = eczema_pc)
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
  mutate(order = c(1, ## total
                   5:10, ## age groups
                   16:21, ## first 6 chapters
                   13, ## female
                   22:27, ## next 6 chapters
                   14, ## male
                   28:34, ## last chapters
                   11, ## NA age group
                   2:4, ## both cohorts 
                   12,15 ## NA rows
                   )) %>%
  arrange(order) %>% 
  select(-order)

write.csv(tab1_out, here::here("out/table1_v2.csv"))

# Read chapter bar charts -------------------------------------------------

theme_set(theme_ali_noFlip)

figure_df <- DF_out_all %>%
  filter(is.na(age),
         !is.na(var),
         !var %in% c("Female", "Male", "_FullCount", "age", "TOTAL"),
         !grepl("[0-9]]", var)) 
fig1 <- figure_df %>%
  select(var, control_n_Asthma, control_n_Eczema, 
         case_n_Asthma, case_n_Eczema) %>%
  pivot_longer(names_to = "cohort", cols = -var) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig1 <- fig1 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.))%>%
  filter(!is.na(name))

plot1_n_full <- ggplot(fig1, aes(x = reorder(name, -value), y = value, colour = exp, fill = exp, group = exp)) +
  geom_col(position = position_dodge(), alpha = 0.2) +
  facet_wrap(~condition) +
  labs(x = "Read Chapter", y = "No. of primary care records", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  scale_fill_manual(values = c("Control" = "tomato", "Case" = "darkblue")) +
  scale_colour_manual(values = c("Control" = "tomato", "Case" = "darkblue")) 
plot1_n_full
dev.copy(pdf, here::here("out/Fig1.pdf"), width = 8, height = 5)
  dev.off()

fig2 <- figure_df %>%
  select(var, control_pc_Asthma, control_pc_Eczema, 
         case_pc_Asthma, case_pc_Eczema) %>%
  pivot_longer(names_to = "cohort", cols = -var) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig2 <- fig2 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.)) %>%
  filter(!is.na(name))

plot1_pc_full <- ggplot(fig2, aes(x = reorder(name, -value), y = value, colour = exp, fill = exp, group = exp)) +
  geom_col(position = position_dodge(), alpha = 0.2) +
  facet_wrap(~condition) +
  labs(x = "Read Chapter", y = "Percentage of all primary care records by Read chapter", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  scale_fill_manual(values = c("Control" = "tomato", "Case" = "darkblue")) +
  scale_colour_manual(values = c("Control" = "tomato", "Case" = "darkblue")) 

plot1_pc_full
dev.copy(pdf, here::here("out/Fig1_pc.pdf"), width = 8, height = 5)
  dev.off()

# Plot chart and table into one object
SummaryTable <- DF_out_all %>%
  filter(var == "_FullCount") %>%
  select(!contains("pc")) %>%
  select(!contains("dif")) %>% 
  select(-gender, -age) %>%
  pivot_longer(cols = -c(var)) %>%
  tidyr::separate(name, into=paste("V",1:3,sep="_")) %>%
  rename(exp = V_1, name = V_3) %>%
  select(-V_2) %>%
  mutate_at("value", ~prettyNum(., big.mark = ",", scientific = F)) %>%
  pivot_wider(id_cols = c(var, name, exp), 
              names_from = c(name),
              values_from = value) %>%
  mutate_at("var", ~"N") %>%
  mutate_at("exp", ~str_to_title(.)) %>%
  select(Variable = var, Exposed = exp,  everything()) 


# Set theme to allow for plotmath expressions
tt <- ttheme_minimal(core = list(fg_params = list(hjust = 0, 
                                                  x = 0.1, 
                                                  fontsize = 9)),
                     colhead=list(fg_params = list(hjust = 0, 
                                                   x = 0.1, 
                                                   fontsize = 10, 
                                                   fontface = "bold",
                                                   parse=TRUE)))

SummaryTable[duplicated(SummaryTable[, c('Variable')]), 
                 c('Variable')] <- ""
SummaryTable
tbl <- tableGrob(SummaryTable, rows=NULL, theme=tt)

pdf(here::here("out/Supp_barchart_full.pdf"), width = 6, height = 6)
grid.arrange(plot1_n_full, tbl,
             nrow=2,
             as.table=TRUE,
             heights=c(5,1))
dev.off()

lay <- rbind(
  c(1,1,1),
  c(1,1,1),
  c(1,1,1),
  c(2,2,2),
  c(2,2,2),
  c(2,2,2),
  c(3,3,3)
  )
pdf(here::here("out/Supp_barchart_full_both.pdf"), width = 12, height = 6)
grid.arrange(plot1_n_full,plot1_pc_full, tbl,
             nrow=2,
             as.table=TRUE,
             #heights=c(5,1),
             layout_matrix = lay)
dev.off()
