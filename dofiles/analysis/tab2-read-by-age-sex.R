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

names <- read_csv(here("datafiles/chapter_names.csv"))
readcodes <- haven::read_dta(here::here("datafiles", paste0(study,"_read_chapter.dta")))


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
  
  # READ chapter ------------------------------------------------------------
  DT <- data.table(readcodes)
  PTD <- data.table(patid_CC)
  ## count number of unique Patids with a record
  fullPTD <- PTD[,age:=2016-realyob]
  fullPTD <- fullPTD[age<=23&age>=13 | age<=55&age>=45,] ## filter age = 18 or 50 \pm 5
  fullPTD[age<=23, age:=18]
  fullPTD[age>=45, age:=50]
  fullPTDcount <- fullPTD[, list(count = uniqueN(patid)), by=list(exp,gender,age)]

  ## merge Read records with PATID info 
  fullDT <- merge(DT, PTD, by = "patid")
  # calculate age
  fullDT <- fullDT[,age:=2016-realyob]
  # filter age = 18 or 50 \pm 5
  fullDT <- fullDT[age<=23&age>=13 | age<=55&age>=45,]
  # replace age == 18 if 18\pm5 or 50 if age == 50\pm5
  fullDT[age<=23, age:=18]
  fullDT[age>=45, age:=50]
  
  ## Count number of Read codes by chapter, exposure, gender and age
  readcollapse_agesex <- fullDT[, list(sum_read = .N), by=list(exp, readchapter,gender,age)]
  ## total number of codes by gender age and exp
  chapter_sum <- readcollapse_agesex[,.(total = sum(sum_read)), by=.(exp,gender,age)]
  ## merge in chapter totals by exposure, age and gender
  read_agesex <- merge(readcollapse_agesex, chapter_sum, by = c("exp","gender","age"))
  ## calculate total percentage
  read_agesex[,pc_read:=sum_read/total]
  
  ## bit of formatting of fullPTD and chapter_sum so we can bind_rows later
  setnames(fullPTDcount, "count", "sum_read")
  fullPTDcount[, readchapter:="_Count"]
  fullPTDcount[, pc_read:=NA]
  
  setnames(chapter_sum, "total", "sum_read")
  chapter_sum[, readchapter:="_Total"]
  chapter_sum[, pc_read:=NA]
  
  DF <- tibble(read_agesex) %>%
    bind_rows(fullPTDcount, chapter_sum) %>%
    arrange(exp, gender, age, readchapter) %>%
    mutate_at("exp", ~ifelse(.==0, "control", "case")) %>%
    select(-total) %>%
    pivot_wider(names_from = exp, values_from = c(sum_read, pc_read)) 
    #mutate_at(c("total_control", "total_case",
    #            "sum_read_control", "sum_read_case",
    #            "pc_read_control", "pc_read_case"), ~replace_na(., 0))
  
  DF_out <- DF %>%
    select(var = readchapter, 
           gender, age,
           control_n = sum_read_control, control_pc = pc_read_control, 
           case_n = sum_read_case, case_pc = pc_read_case) %>%
    arrange(var, gender, age)
  DF_out 
}
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
DF_out <- DF_out %>%
  filter(!grepl("_",var))

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


plot2 <- ggplot(fig1, aes(x = name, y = value, colour = exp, fill = exp, group = exp)) +
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
  theme_bw() +
  theme(legend.position = "top",
        strip.background = element_blank(), 
        axis.text.y = element_text(hjust = 1, angle = 0),
        axis.text.x = element_text(hjust = 1, angle = 65))
plot2
dev.copy(pdf, here::here("out/Fig2.pdf"), width = 10, height = 11)
  dev.off()
  

SummaryTable <- DF_out %>%
  filter(grepl("_", var)) %>%
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

SummaryTable[duplicated(SummaryTable[, c('Condition', 'Variable')]), 
   c('Condition', 'Variable')] <- ""
SummaryTable[duplicated(SummaryTable[,'Condition']), 'Condition'] <- ""
SummaryTable
tbl <- tableGrob(SummaryTable, rows=NULL, theme=tt)

fig2 <- DF_out %>% 
  select(var, gender, age, control_pc_Asthma, control_pc_Eczema, 
         case_pc_Asthma, case_pc_Eczema) %>%
  pivot_longer(names_to = "cohort", cols = -c(var,gender,age)) %>%
  separate(col = cohort, into = c("exp", "n", "condition"), sep = "_")

fig2 <- fig2 %>%
  left_join(names, by = "var") %>%
  mutate_at(c("exp", "condition"), ~stringr::str_to_title(.)) 

plot2_pc <- ggplot(fig2, aes(x = name, y = value*100, colour = exp, fill = exp, group = exp)) +
  geom_col(data = filter(fig2, !grepl("_", var)), position = position_dodge(), alpha = 0.2) +
  facet_grid(cols = vars(gender, age),
             rows = vars(condition)) +
  labs(x = "Read Chapter", y = "Percentage of all primary care records by Read chapter", colour = "Exposed", fill = "Exposed") +
  coord_flip() +
  theme_bw() +
  theme(legend.position = "top",
        strip.background = element_blank(), 
        axis.text.y = element_text(hjust = 1, angle = 0),
        axis.text.x = element_text(hjust = 1, angle = 65))
plot2_pc
dev.copy(pdf, here::here("out/Fig2_pc.pdf"), width = 10, height = 11)
  dev.off()

# Plot chart and table into one object
pdf(here::here("out/Fig2_table.pdf"), width = 10, height = 12)
grid.arrange(plot2, tbl,
             nrow=2,
             as.table=TRUE,
             heights=c(4,1))
dev.off()
pdf(here::here("out/Fig2_table_pc.pdf"), width = 10, height = 12)
grid.arrange(plot2_pc, tbl,
             nrow=2,
             as.table=TRUE,
             heights=c(4,1))
dev.off()
  