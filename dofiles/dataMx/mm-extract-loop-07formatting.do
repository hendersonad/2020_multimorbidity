/*=========================================================================
DO FILE NAME:			mm-extract-07formatting.do

AUTHOR:					Ali Henderson	
						
VERSION:				v1
DATE VERSION CREATED: 	2021-Jan
					
DATABASE:				CPRD July 2020 build
	
DESCRIPTION OF FILE:	Aims to compile the extracted data and convert
						all the medcodes into Read code chapters for the 
						eczema and asthma cohorts
					
*=========================================================================*/

//ssc install filelist 

/*******************************************************************************
>> HOUSEKEEPING
*******************************************************************************/
version 15
clear all
capture log close

* find path file location and run it
mm_extract paths

* create a filename global that can be used throughout the file
global filename "mm-extract-eczema-07readchapter"

* open log file
log using "${pathLogs}/${filename}", text replace


/*******************************************************************************
>> choose study type
*******************************************************************************/
local study "asthma"

cd ${pathIn}

cap mkdir `study'studyCohort_readchapters
// clear everything in this directory 
cd `study'Cohort_readchapters
local list : dir . files "save*"
foreach f of local list {
	erase `f'
}
cd ../

filelist, dir(.) pattern("*.dta")
keep if regexm(filename, "`study'_extract3")
list filename

drop if regexm(filename, "Additional")
drop if regexm(filename, "Patient_")
drop if regexm(filename, "Practice_")
drop if regexm(filename, "results_`study'_extract3")
save "${pathPostDofiles}\dataMx\myFileList.dta", replace

local obs = _N
di `obs'
forvalues i = 1/`obs' {
	//di `i'
	use "${pathPostDofiles}\dataMx\myFileList.dta" in `i' , clear	
	local f = filename
	use "`f'", clear 
	//di "`f'
	cap keep patid eventdate medcode
	cap confirm var medcode 
	if !_rc {
		qui {
		merge m:1 medcode using "${pathBrowsers}\medical.dta", gen(merge) keep(3) keepusing(readcode readterm)
		cap drop keep1
		gen keep1 =1 if regexm(substr(readcode, 1, 1), "[A-Y]") 
		cap drop drop1
		gen drop1 = 1 if regexm(readterm, "Drug not available|Personal history of|Normal delivery in a completely normal case| in remission|(\?i)full remission")
		replace keep1 = 1 if regexm(readterm, "Acute alcoholic intoxication in remission, in alcoholism")
	
		drop readterm
		keep if keep1 == 1 
		drop if drop1 == 1
		gen readchapter = substr(readcode, 1, 1)
		keep patid eventdate medcode readchapter 
		
		tempfile save`i'
		qui save "`study'Cohort_readchapters\save`i'"
		}
	}
}

clear
forvalues i = 1/`obs' {
	di `i'
	cap append using "`study'Cohort_readchapters\save`i'"
}
save `study'_test.dta, replace

cd `study'Cohort_readchapters
local list : dir . files "save*"
foreach f of local list {
	erase `f'
}
cd ../

