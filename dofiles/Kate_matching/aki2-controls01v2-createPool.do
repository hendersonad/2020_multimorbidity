/*=========================================================================
DO FILE NAME:	aki2-controls01-createPool.do

AUTHOR:					KateMansfield		
VERSION:				v2.0
DATE VERSION CREATED:	20-April-2015 edited happy18th var
						09-April-2015 					
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE:
	Identifies a pool of eligible patients from which to select controls.
						
DATASETS USED: 		
	acceptable_pats_from_utspracts_JUL2014.txt	// July 2014 build eligible patients from uts practices
	HES_eligible.dta	// patids of patients eligible for HES linkage (sorted on patid)
									
DO FILES NEEDED:	N/A

DATASETS CREATED:		
		1_DenominatorHESeligible	// all patients in Jan 2014 CPRD build who are eligible for HES linkage
		2_DenominatorHESeligibleAndAtleast18in2012	// all HES eligible patients in Jan 2014 CPRD build who are at least 18 in 2012
		
STAGES
	1. Convert denominator file (for all CPRD patients) to stata format sorted on patid
	2. Merge with file containing eligible patids
	4. Keep only eligible patients
	5. Identify those who are at least 18 at the end of the study period (March 2014)
	6. Keep only those aged 18 and over at the end of the study period. 
						
					
*=========================================================================*/
version 13
clear all
macro drop _all

/*******************************************************************************
>> identify file locations and set any locals
*******************************************************************************/
* cd to location of file containing all file paths
aki2 paths

run aki2-pathsv2.do


/*******************************************************************************
>> insheet practice information look-up
*******************************************************************************/
insheet using "$pathCPRDlookupsSrc/allpractices_JUL2014.txt", clear
label data "practice information for July 2014 CPRD build"
notes: aki2-controls-createPool.do / TS
save $pathCPRDlookupsSaved/allpractices_JUL2014, replace




/*******************************************************************************
#1. Convert the raw denomintor pop text data file to stata format
	and sort on patid ready for merge to identify patients eligible
	for HES linkage.
*******************************************************************************/
insheet using "$pathCPRDlookupsSrc/acceptable_pats_from_utspracts_JUL2014.txt", clear
sort patid

label data "denominator pop for CPRD for acceptable pxs from uts practices"
notes: aki2-controls-createPool.do / TS
save $pathCPRDlookupsSaved/acceptable_pats_from_utspracts_JUL2014, replace


use $pathCPRDlookupsSaved/acceptable_pats_from_utspracts_JUL2014, clear


/*******************************************************************************
#2. Merge with linkage eligibility file to identify patients eligible for HES
	linkage
*******************************************************************************/
merge 1:1 patid using $pathHESstata/linkage_eligibility

/*
    Result                           # of obs.
    -----------------------------------------
    not matched                     6,206,333
        from master                 4,965,094  (_merge==1)
        from using                  1,241,239  (_merge==2)

    matched                         8,554,655  (_merge==3)
    -----------------------------------------
*/

keep if _merge==3
drop _merge

tabulate hes_e, miss
/*
      hes_e |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,149,191       13.43       13.43
          1 |  7,405,464       86.57      100.00
------------+-----------------------------------
      Total |  8,554,655      100.00
*/
keep if hes_e==1  
drop hes_e death_e cr_e minap_e lsoa_e linkdate






/*******************************************************************************
#3. Calculate age in 2015 (end of study period is 2015)
	and drop if age is less than 18 
	since patient will not have reached the age of 18 during the study 
	period and therefore would not be eligible for inclusion in the study
*******************************************************************************/
generate ageIn2015 = 2015 - yob if yob!=.
label var ageIn2015 "ageIn2015: age in 2015"

drop if ageIn2015<=18 // 1,045,489 deleted




/*******************************************************************************
#4. merge in practice information
*******************************************************************************/
merge m:1 pracid using "$pathCPRDlookupsSaved/allpractices_JUL2014" // merge in practice information
drop if _merge==2
drop _merge





/*******************************************************************************
#5. Format dates
*******************************************************************************/
run prog_formatDate.do

prog_formatDate, datevar(frd)
prog_formatDate, datevar(crd)
prog_formatDate, datevar(deathdate)
prog_formatDate, datevar(tod)
prog_formatDate, datevar(lcd)
prog_formatDate, datevar(uts)

order patid frd crd uts deathdate tod lcd










/*******************************************************************************
IDENTIFY IF ELIGIBLE BASED ON STUDY START/END DATES
*******************************************************************************/
/*******************************************************************************
#6. Cohort entry eligibility - eligible for dates
*******************************************************************************/
/*
Eligible for entry from the latest of:
	from.1 one year after practice registration date (crd/frd)
	from.2 date practice reached CPRD quality control standards (uts - from practice file)
	from.3 18th birthday (calculate from realyob = realyob + 18 (set to midyear))
	from.4 start of study = 1st April 1997 // date("4/1/2014", "MDY")

Eligible until earliest of:
	to.1 deathdate
	to.2 transferred out of practice (tod)
	to.3 last collection date from practice (lcd) 
	to.4 end of study = 31st March 2014 // date("3/31/2014", "MDY")
	to.5 ESRD diagnosis // unable to ascertain at this point with current data
*/

* from.1: crd+365 >> one year after practice registration date
* 	chosen to use crd not frd as need to guarantee one year of continuous 
* 	data after registration
assert crd!=.
gen crdPlus1yr = crd + 365
format crdPlus1yr %td

* from.2: uts date
* 	identified in #4 above

* from.3: 18th birthday
gen happy18th = yob + 18
tostring happy18th, replace  // use year in happy18th var to create a birthday - make it mid year since only have yob not dob
replace happy18th = "1/7/" + happy18th // 18th birthday will be mid year 1st July for all
prog_formatDate, datevar(happy18th)	// format as a date

* from: eligible from latest of
assert crdPlus1yr!=. 	// no missing values
assert uts!=.			// no missing values
assert happy18th!=.		// no missing values

gen eligibleFrom = max(crdPlus1yr, uts, happy18th, date("4/1/1997", "MDY"))
format eligibleFrom %td
label var eligibleFrom "eligibleFrom: date patient eligible for cohort entry"

* to:
gen eligibleTo = min(deathdate, tod, lcd, date("3/31/2014", "MDY")) // no need to worry about missing values as these will be interpreted as big numbers
format eligibleTo %td
label var eligibleTo "eligibleTo: date patient stops being eligible for cohort entry"

* check date eligible for entry against study end date
* ensure registration period is within study dates
* eligibleFrom needs to be before study end
* eligibleTo needs to be after study start
* eligibleFrom needs to be before eligibleTo
gen eligibleondates=1
label var eligibleondates "eligibleondates: eligible from date not after study end, eligible to date not before study start"
replace eligibleondates=0 if eligibleFrom > date("3/31/2014", "MDY")
replace eligibleondates=0 if eligibleTo < date("4/1/1997", "MDY")
replace eligibleondates=0 if eligibleFrom > eligibleTo

* drop individuals whose registration period is outside the study period
* i.e. starts being eligible after end of study or 
* stops being eligible before start of study
tab eligibleondates, miss
/*
eligibleon  |
dates 		|      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |  1,520,059       23.90       23.90
          1 |  4,839,916       76.10      100.00
------------+-----------------------------------
      Total |  6,359,975      100.00


*/


drop if eligibleondates==0





/*******************************************************************************
#4. Add notes and save
*******************************************************************************/
label data "patients eligible for control pool"
notes: HES eligible patients at least 18 in 2015 for control pool / TS
notes: registration period is within study period (1/4/1997 to 31/3/2014) / TS
notes: NB: will also need to exclude any that are cases
notes: n=4,839,916
notes: aki2-controls01-createPool.do / TS 

save $pathDataDerived/controls-pool-02, replace

