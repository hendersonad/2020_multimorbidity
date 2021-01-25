#AUTHOR:					Julian Matthewman	
#DATE CREATED: 	14/12/2020
#DATABASE:				CPRD July 2020 build
#DESCRIPTION OF FILE:	Aim: Identify first events corresponding to each readcode chapter per participant
#DATASETS USED:		clinical, immunisation, referral and test files: contain events
#                 exposure file: to identify sets
#                 medical product browser: to identify readcodes from medcodes
#DATASETS CREATED: 	dataset containing first events per readcode chapter per participant
#
#DRAFT TEXT FOR MANUSCRIPT: For each participant, the first event corresponding to each readcode chapter was identified from CPRD data on treatments, referrals, immunisations and tests in primary care. Readcode chapters A-U are organised based on system (e.g.: cardiovascular) or cause (e.g.: congential).


library(tidyverse) #To use the dplyr (for data wrangling) and strigr (to do string searches) packages
library(haven) #To read Stata .dta files

data_dir <- ("J:/EHR-Working/Julian/2020_multimorbidity")
  browser_dir <- "//EPHSHARE2/EPHSHARE2/EPHSHARE/EHR Share/3 Database guidelines and info/GPRD_Gold/Medical & Product Browsers/2020_07_Browsers/medical.dta"

# Import ------------------------------------------------------------------
#Import dummy datasets
clinical <- read_dta(paste0(data_dir, "Clinical_extract_ecz_extract3_1.dta"))
immunisation <- read_dta(paste0(data_dir, "Immunisation_extract_ecz_extract3_1.dta"))
referral <- read_dta(paste0(data_dir, "Referral_extract_ecz_extract3_1.dta"))
test <- read_dta(paste0(data_dir, "Test_extract_ecz_extract3_1.dta"))
dummy_exposure <- read.csv("dummy_exposure.txt")

#Combine patient data
patient <- rbind(clinical, immunisation, referral, test) %>% #Combine all the datasets with patids
  mutate(dummy_patid=as.numeric(dummy_patid)) %>% #Change patid to numeric (so there aren't any conflict when joining with non-Stata data)
  left_join(dummy_exposure, by = c("dummy_patid"="patid")) #Join with the exposure and set data


# Filter Browser -----------------------------------------------------------


#Import medical browser
medical <- read_dta("K:/EHR Share/3 Database guidelines and info/GPRD_Gold/Medical & Product Browsers/2020_07_Browsers/medical.dta")
medical <- medical[c("medcode", "readcode", "readterm")] #keep only needed variables


#Filter out unwanted codes
medical_filtered <- medical %>%
  filter(str_starts(readcode, "[A-Y]"), #Only keep codes that start with a letter, discard chapter Z as only non-diagnosis codes
         !str_detect(readterm, "Drug not available|Personal history of|Normal delivery in a completely normal case| in remission|(?i)full remission") #filter out negation codes 
           | readterm == "Acute alcoholic intoxication in remission, in alcoholism") %>% #Keep these
  mutate(chapter=str_sub(readcode, end = 1)) %>% #make new variable called chapter which contains only the first letter of the readcode
  arrange(readcode)

#I filtered the readterms by obvious negation codes (e.g.: remission) and skimmed through the readterms to identify any further negation codes
#Should births/deliveries be in here?
#Keep (decided in multimorbidity group meeting 14/12): Acute alcoholic intoxication in remission, in alcoholism


# Join with patient data -----------------------------------------------------------------


patient <- left_join(patient, medical_filtered) %>% #Join readcodes from the updated browser by medcode
  arrange(eventdate) %>% #Sort by eventdate
  group_by(dummy_patid) %>% #Group by patient
  filter(!duplicated(chapter), #Get rid of duplicated readcode chapters (by patient)
         !is.na(readcode)) %>% #keep only those where there is a readcode present
  ungroup() %>%
  arrange(dummy_patid)

write_csv(patient, "dummy_events.csv")




