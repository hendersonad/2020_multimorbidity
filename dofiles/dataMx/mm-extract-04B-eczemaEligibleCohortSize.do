/*=========================================================================
DO FILE NAME:			ecz-extract-04eczemaEligibleCohort.do

AUTHOR:					ALi Henderson	
						Adapted from Kate
						
VERSION:				v5
DATE VERSION CREATED: 	v5 2018-Jan-24	// edited to amend error in step #4
						v4 2018-Jan-16	// edited to rerun including eczema cases identified from HES
						v3 2017-Nov-30	// edited to add 12 months to eczema Dx for cancer cohort entry
										// to allow 12-month cancer-free interval prior to start of observation
						v2 2017-Nov-27	// edited to add incident flag to Dxonly cohort
						v1 2017-Nov-20
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Aim is to establish start and end of eligible follow up
						for those meeting the eczema definition.
						
						And also cohort entry date, latest of:
								1. crd+365.25
								2. uts date
								3. 18th birthday
								4. study start (02jan1998)
								5. Eczema diagnosis date (+12 months for cancer cohort to avoid reverse causality)
						
MORE INFORMATION:		
	Identify eligible start and end of follow up (identify index date)
	+ drop anyone with less than 12 months of eligible follow up
	(NB: will need to review at a later date to check for cancer free 
		interval before and after index date)
			eczemaExp 	// patids and eligibility dates
						// + cohort entry and exit dates
						// for those with eczema code and
						// 2 Rx codes on separate days
						// + only including those with valid
						// follow-up during study period
	We will have a couple of sensitivity analyses defining the exposed/unexposed 
	cohorts differently, therefore this file also identifies an alternative
	eczema-exposed cohort based on Read code only (i.e. no requirement for 
	eczema therapy codes).
						
DATASETS USED:		eczemaExposed // patients with 1 diagnostic code and 2 therapeutic codes (on separate days) for eczema
					Patient_extract_exca2_linked_1		// year of birth, sex, and start and end of follow-up by person
					Practice_extract_exca2_linked_1	// start and end of follow-up by practice
					results_exca2_linked	// includes dates of first eczema diagnosis code
									
DATASETS CREATED:	eczemaExposed-eligible-`cohort'	// individuals eligible for FU meeting eczema definition
													// where `cohort' is cancer or mortality
													// cancer cohort allows an additional 12 months after eczema diagnosis
													// before study entry in order to avoid reverse causality
					eczemaExposed-eligible-Dxonly-`cohort'	// individuals eligible for FU based on eczema Dx code only
									
DO FILES NEEDED:	exca-paths.do

ADO FILES NEEDED: 	exca.ado

*=========================================================================*/

/*******************************************************************************
>> HOUSEKEEPING
*******************************************************************************/
version 15
clear all
capture log close

* find path file location and run it
mm_extract paths

* create a filename global that can be used throughout the file
global filename "mm-extract-04eczemaEligibleCohort"

* open log file
log using "${pathLogs}/${filename}", text replace







/*******************************************************************************
#1. Prepare patient- and practice-level date data for those meeting the 
	eczema algorithm (and also for those with eczema Dx code only for sens analysis)
*******************************************************************************/
* identify individuals with an eczema diagnosis at any time
use $pathIn/Patient_extract_ecz_extract_1, clear
unique patid // n = 2378207

* merge in practice information
gen pracid=mod(patid, 1000)
merge m:1 pracid using  $pathIn/Practice_extract_ecz_extract_1, nogen //all 130,703 matched

label var lcd "date of last data collection from practice"
label var uts "date practice reached CPRD quality control standards"


l if accept != 1
drop if accept != 1 // 1 obs deleted
* Identify and drop any patients with CPRD unacceptable flag	
assert accept==1 // ALI: assertion is false 

* Add in eczema diagnosis dates (for sensitivity analysis including those
* identified based on eczema diagosis code only)
merge 1:1 patid using ${pathOut}\eczemaExposed, keep(match master) nogen keepusing(eczemadate) // 

/*


    Result                           # of obs.
    -----------------------------------------
    not matched                       590,945
        from master                   590,945  
        from using                          0  

    matched                         1,787,262 


matched  1,788,057 with new prodcodes 
*/

/*
No need to flag individuals meeting main analysis eczema definition and those meeting sensitivity analysis Dx-code-only eczema defintion
As those meeting full eczema definition have non-missing eczema date
*/

* add in index dates (i.e. first eczema diagnostic morbidity code) for Dx only eczema definition
merge 1:1 patid using ${pathIn}/results_ecz_extract, keepusing(indexdate) nogen //Ali: all matched
rename indexdate eczemadateDx
label var eczemadateDx "date of first diagnostic eczema code"


/*******************************************************************************
#2. Identify start of eligible follow-up
*******************************************************************************/
/*
Individuals will be eligible for observation from the latest of:
	1. crd+365.25
	2. uts date
	3. 18th birthday
	4. study start (02jan1998)
	
crd+365.25 >> one year after practice registration date use crd not frd as need to 
guarantee one year of continuous data after registration
Allowing for 12 months follow-up before start of observation to ensure accurate
recording of covariates.

NB: for cancer study will also add another year on to eligible-from-date - in 
	order to limit reverse causality (unlikely to be a problem here, as may not
	be following people from their incident cancer diagnosis - but wise to be
	as clean as possible analysis and death study will not need this period) 
*/

* identify birthdate and 18th birthday
* DOB
gen day_birth=1
replace mob=7 if mob==0
gen dob=mdy(mob, day_birth, realyob)
format dob %td
label var dob DOB

* 18th birthday 
gen happy18th = realyob + 18
replace happy18th=mdy(mob, day_birth, happy18th)
format happy18th %td
label var happy18th "date 18, assumes mid year birthday if mob missing"
drop day_birth // no longer needed

* ensure relevant dates available
drop if crd==. // 6 obs deleted
assert crd!=.	// no missing values
assert uts!=.			// no missing values
assert happy18th!=.		// no missing values

* from: eligible from latest of:


forvalues endYear = 2014/2018{
preserve
cap drop eligibleStart 
cap drop eligibleEnd
	// startdate
	local startdate = mdy(1,1,`endYear')
	local enddate = mdy(12,31,`endYear')
	di in blue %td "`startdate'"
	di in blue %td "`enddate'"
	
gen eligibleStart = max(crd + 365.25, uts, happy18th, `startdate') //ALI - date will ened changing
format eligibleStart %td 
label var eligibleStart "latest of: crd+365.25, uts, happy18th, `startdate'"


/*******************************************************************************
#3. Identify END of eligible follow-up
*******************************************************************************/
/*
Earliest of:
	1. last collection date
	2. transfer outdate
	3. death date
	4. end of study (31dec2006) <-  will be 31Dec2020
*/

gen eligibleEnd=min(lcd, tod, deathdate, `enddate')
format eligibleEnd %d
label var eligibleEnd "earliest of: lcd, tod, deathdate, `enddate'"

summ(eligibleEnd)
summ(eligibleStart)



/*******************************************************************************
#4. Identify individuals with Dx only eczema who have eligible follow-up dates
*******************************************************************************/
/*foreach cohort in multimorb { // ALI: same conditions for both for now. this may change
	display ""
	display "******************************************************************"
	display " `cohort' cohort "
	display "******************************************************************"	
	display ""
	preserve
		//if "`cohort'"=="multimorb" gen entry=max(eligibleStart, eczemadateDx)
		//if "`cohort'"=="Mhealth" gen entry=max(eligibleStart, (eczemadateDx+365.25)) // add a year to eczema diagnosis date for cancer cohort - 12-month cancer-free interval
		gen entry=max(eligibleStart, eczemadateDx)
		lab var entry "latest of: eczemaDx (first code), 18th, study start, start reg)"
		format entry %td	
		drop if entry>=eligibleEnd /*n=460,722*/
		
		gen incid=1 if eczemadateDx>eligibleStart
		recode incid .=0
		tab incid, miss
		label var incid "new onset eczema after eligible for cohort entry"
		
		unique patid
		
		label data "Eczema exposed cohort - defined by Dx only `cohort' study"
		notes: Eczema exposed cohort - defined by Dx only
		notes: Eczema exposed for `cohort' study
		notes: eligible for FU (based on age, eligible FU, study dates)
		notes: ${filename} / TS

		sort patid 
		compress
		save "${pathOut}/eczemaExposed-eligible-Dxonly-`cohort'", replace
	restore

} /*end foreach cohort in cancer mortality*/



*/




/*******************************************************************************
#5. Identify individuals with an eczema diagnosis (based on full algorithm)
	who have eligible follow-up dates
	i.e. must contribute some adult follow-up during the study period 
	(02jan1998 to 31mar2016)
	NB: individuals without valid adult follow-up still MUST be excluded from
		the unexposed pool - therefore need to keep a record of these people
*******************************************************************************/
* drop those with eczema based on diagnosis only (i.e. no requirement for
* 2 x therapy on separate days)
drop if eczemadate==.

foreach cohort in multimorb {
	display ""
	display "******************************************************************"
	display " `cohort' cohort "
	display "******************************************************************"	
	display ""
	//preserve
		//if "`cohort'"=="mortality" 
		gen entry=max(eligibleStart, eczemadate)
		//if "`cohort'"=="mortality" 
		lab var entry "latest of: eczemaDx (latest code/2nd Rx), 18th, study start, start reg)"
/*
		if "`cohort'"=="cancer" gen entry=max(eligibleStart, eczemadate+365.25) // add 12 months for cancer cohort
		if "`cohort'"=="cancer" lab var entry "latest of: eczemaDx (latest code/2nd Rx)+365.25, 18th, study start, start reg)"
*/
		format entry %td

		***DROP patients without any follow-up during study period
		drop if entry>=eligibleEnd 
		unique patid 

		* check that there aren't any people with end of eligibility after start of
		* eligibility
		count if eligibleStart>eligibleEnd // 0


		
		


		/*******************************************************************************
		#6. Flag incident/prevalent cases
		*******************************************************************************/
		* identify incident eczema flag so that in extract06 can identify those who
		* may be eligible for cohort entry as controls before their eczema diagnosis
		* incident eczema new onset after individual becomes eligible for study entry:
		* 	i.e. onset after latest of: 18th birthday, study start and eligible for follow up
		gen incid=1 if eczemadate>eligibleStart
		recode incid .=0
		tab incid /*incident=50%*/
		label var incid "new onset eczema after eligible for cohort entry"


		
		assert entry<eligibleEnd
		unique patid



		/*******************************************************************************
		#7. label and save
		*******************************************************************************/
		label data "Eczema exposed cohort - `cohort' study"
		notes: Eczema exposed cohort - for `cohort' study
		notes: eligible for FU (based on age, eligible FU, study dates)
		notes: ${filename} / TS

		sort patid 
		compress
		save "${pathOut}/eczemaExposed-eligible-`cohort'", replace
		
		/*******************************************************************************
		#7b. exprt patid list and year 
		*******************************************************************************/
		keep patid eligibleStart eligibleEnd 
		gen endDate = `enddate'
		format endDate %td
		gen endYear = year(endDate)
		drop endDate
		save "${pathOut}/Exposed-eligible-`cohort'-`endYear'", replace
	qui count 
	di in red r(N)
	//restore

} /*end foreach cohort in cancer mortality*/
		restore
} // end jj loop for different end dates 

/*
NB: when developing pool of unexposed will need to be aware of the individuals
	excluded here.
	
	Individuals with an eczema diagnosis code but who do not have 2 therapy 
	records will be excluded from the pool of unexposed.
	
	There are also two sensitivity analyses with different control pools.
*/




/* 
2014 -- 536,777
2015 -- 494,582
2016 -- 419,832
2017 -- 375,814
2018 -- 350,138
*/

clear 
use "${pathOut}/Exposed-eligible-multimorb-2014", clear
gen prevStart = eligibleStart
gen prevEnd = eligibleEnd
format prevStart %td
format prevEnd %td

forvalues endYear = 2015/2018{

merge 1:1 patid using "${pathOut}/Exposed-eligible-multimorb-`endYear'", gen(merge1) replace update
	// take master values if not in using
	replace prevStart = eligibleStart if merge1 == 1 
	replace prevEnd = eligibleEnd if merge1 == 1
	// take merge values if not in master
	replace prevStart = eligibleStart if merge1 == 2 
	replace prevEnd = eligibleEnd if merge1 == 2
	// should not be any merge1 == 3 or 4
	assert merge1 != 3 & merge1 != 4
	// use updated eligibleEnd when there was a merge conflict
	replace prevEnd = eligibleEnd if merge1 == 5
	// do not update prevStart if merge conflict. Want earliest prevStart date which is already stored in the variable

	drop merge1
//delete file once merged 
} // end loop over endYear files

gen yearEnd = year(prevEnd)
tab yearEnd

// total of 680,663. About half can be matched in 2018
/*
    yearEnd |      Freq.     Percent        Cum.
------------+-----------------------------------
       2014 |     86,919       12.77       12.77
       2015 |    111,284       16.35       29.12
       2016 |     76,436       11.23       40.35
       2017 |     55,886        8.21       48.56
       2018 |    350,138       51.44      100.00
------------+-----------------------------------
      Total |    680,663      100.00
*/
log close






