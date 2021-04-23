clear
adopath + C:/Users/lsh1510922/Documents/2020_multimorbidity
mm_extract paths
global pathAnalysis "Z:\GPRD_GOLD\Ali\2020_multimorbidity\analysis"

local S = "eczema"

di  "`S'"
// `study'_patient_info.csv
use "${pathIn}/Patient_extract_mm_`S'_extract_matched_1.dta", clear
keep patid gender realyob crd tod

merge 1:m patid using "${pathIn}/`S'_READ.dta"
bysort patid: gen event_no = _n
keep if event_no == 1

save ${pathAnalysis}/temp_firstevents.dta, replace


use "${pathOut}/expANDunexppool-main-multimorb-`S'-CCmatch_selected_matches.dta", clear
rename caseid patid
duplicates drop  patid, force

merge 1:1 patid using ${pathAnalysis}/temp_firstevents.dta, gen(cases)

save ${pathAnalysis}/temp_firstevents2.dta, replace

use "${pathOut}/expANDunexppool-main-multimorb-`S'-CCmatch_selected_matches.dta", clear
rename contid patid
duplicates drop  patid, force

merge 1:1 patid using ${pathAnalysis}/temp_firstevents2.dta, gen(conts)

gen exposed = contid == .
drop caseid contid _merge cases conts

gen dob = mdy(07,01,realyob)
format dob %td
cap drop age_at_first_event
gen age_at_first_event = (eventdate-dob)/365.25
tab exposed
summ age_at_first_event
hist age_at_first_event

bysort exposed: summ age_at_first_event
hist age_at_first_event, by(exposed)


hist age_at_first_event if readchapter != "Q", by(readchapter)
