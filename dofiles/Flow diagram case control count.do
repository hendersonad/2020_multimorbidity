version 15
clear all
capture log close

* find path file location and run it
mm_extract paths


// eligible participants 
use ${pathIn}/results_mm_extract_asthma.dta, clear
unique patid // asthma =  2142854
use ${pathIn}/results_mm_extract_eczema.dta, clear
unique patid // eczema =  2378207

// removed for age 
