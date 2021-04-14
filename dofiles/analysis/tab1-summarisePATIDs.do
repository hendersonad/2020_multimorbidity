// Table 1 

use "Z:\GPRD_GOLD\Ali\2020_multimorbidity\out\expANDunexppool-main-multimorb-eczema-CCmatch_selected_matches.dta", clear


// CASES
keep caseid
rename  caseid patid
duplicates drop patid, force
merge 1:1 patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\Patient_extract_mm_eczema_extract_matched_1.dta"

keep if _merge == 3

//age
gen age = 2016 - realyob
summ age
cap drop agecut
egen agecut = cut(age), at(0,5,10,18,30,60,80,200) label
tab agecut

//sex
tab gender, m

// 'comorbidities'
keep patid age gender
merge 1:m patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\eczema_READ.dta"
keep if _merge==3
tab readchapter, m


// CONTROLS
clear
use "Z:\GPRD_GOLD\Ali\2020_multimorbidity\out\expANDunexppool-main-multimorb-eczema-CCmatch_selected_matches.dta", clear

keep contid
rename  contid patid
duplicates drop patid, force
merge 1:1 patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\Patient_extract_mm_eczema_extract_matched_1.dta"

keep if _merge == 3

//age
gen age = 2016 - realyob
summ age
cap drop agecut
egen agecut = cut(age), at(0,5,10,18,30,60,80,200) label
tab agecut

//sex
tab gender, m

// 'comorbidities'
keep patid age gender
merge 1:m patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\eczema_READ.dta"
keep if _merge==3
tab readchapter


*ASTHMA

// Table 1 
clear
use "Z:\GPRD_GOLD\Ali\2020_multimorbidity\out\expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches.dta", clear



// CASES
keep caseid
rename  caseid patid
duplicates drop patid, force
merge 1:1 patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\Patient_extract_mm_asthma_extract_matched_1.dta"

keep if _merge == 3

//age
gen age = 2016 - realyob
summ age
cap drop agecut
egen agecut = cut(age), at(0,5,10,18,30,60,80,200) label
tab agecut

//sex
tab gender, m

// 'comorbidities'
keep patid age gender
merge 1:m patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\asthma_READ.dta"
keep if _merge==3
tab readchapter, m


// CONTROLS
clear
use "Z:\GPRD_GOLD\Ali\2020_multimorbidity\out\expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches.dta", clear

keep contid
rename  contid patid
duplicates drop patid, force
merge 1:1 patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\Patient_extract_mm_asthma_extract_matched_1.dta"

keep if _merge == 3

//age
gen age = 2016 - realyob
summ age
cap drop agecut
egen agecut = cut(age), at(0,5,10,18,30,60,80,200) label
tab agecut

//sex
tab gender, m

// 'comorbidities'
keep patid age gender
merge 1:m patid using "Z:\GPRD_GOLD\Ali\2020_multimorbidity\in\asthma_READ.dta"
keep if _merge==3
tab readchapter
