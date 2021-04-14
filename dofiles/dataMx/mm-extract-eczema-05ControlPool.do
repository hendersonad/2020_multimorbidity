/*=========================================================================
DO FILE NAME:			ecz-extract-05controlPool.do

AUTHOR:					Ali Henderson	
						Adapted from KATE
							3_DOB_gender_all_patients
							4_define_comparison_cohort
						
VERSION:				v4
DATE VERSION CREATED: 	v4 2015-jan-24	// edited to rerun after checks
										// only need one control pool for main/sens2 and one for sens1
										// no need to have one for each mortal/ca cohort as diagnosis date
										// remains the same regardless of which cohort
										// only thing that changes between cancer and mortality
										// cohorts is that entry date for cancer cohort
										// includes eczema Dx +365 instead of just eczema Dx
						v3 2018-Jan-16	// edited to rerun including eczema cases identified from HES
						v2 2017-Nov-30 	// edited to use two different exposed cohorts
										// cancer cohort additionally requires 12 months after eczema
										// diagnosis before individuals enter cohort
						v1 2017-Nov-23
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	The aim of this file is to identify those eligible for
						inclusion in the pool used to identify the unexposed 
						matched cohort.
						Unexposed patients must be 
						- active in CPRD when the case is diagnosed with eczema 
						- with at least one year of follow-up. 
						- no history of eczema when matched, however can go on to develop eczema
						- for cancer study only: no history of cancer (will look for this later)
						
MORE INFORMATION:	1. Main analysis  
						Patients with an eczema diagnosis will be included in 
						the control pool up until their eczema diagnosis (Read code
						for eczema), even if they don’t go on to meet the full
						eczema definition (of diagnosis and two treatments).  
					2. Sensitivity Analysis 1
						Patients with an eczema diagnosis but without two further 
						treatments are included in the control pool for the 
						entire duration of their follow-up. 
						Patients in the exposed cohort (diagnosis and 2 treatments) 
						are included as unexposed, up until their cohort 
						entry (i.e latest of their diagnosis and 2 treatments). 
						The exposed patients are the same as the main 
						analysis above.
					3. Sensitivity Analysis 2
						Exposed patients are eczema diagnosis only 
						(without the treatment criteria), and these patients are 
						eligible to be controls, up until their eczema diagnosis.
						
					Therefore, need 2 separate control pools:
					1. Censor at first diagnostic code for eczema (even if don't
						go on to fulfill full eczema defintion) (main and sens analysis 2)
					2. Censor at the date individuals enter the exposed cohort
						i.e. at the point they fulfill the main analysis eczema
						defintion (latest of dx or 2nd eczema therapy record) (sens analysis 1)
					
DATASETS USED:		allpatients_JUL2017		// age, sex, crd, deathdate for all patients July 2017 build
					allpractices_JUL2017	// uts, lcd for all practices July 2017 build
					eczemaExposed-eligible-mortality	// individuals eligible for FU meeting eczema definition
											// provides date individuals Dx'd with eczema based on eczema algorithm
					eczemaExposed-eligible-Dxonly-mortality	// individuals eligible for FU based on eczema Dx code only
											// provides date of first eczema morbidity code
									
DATASETS CREATED:	controlpool	// a dataset of individuals eligible for 
								// inclusion in the control pool: acceptable, eligible for linkage
								// 18yrs+ with valid FU during study period
								// no eczema diagnosis before start of eligibility
								// (both dx-only eczema definition and main analysis eczema defintion)
									
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
global filename "mm-extract-eczema-05controlPool"

* open log file
log using "${pathLogs}/${filename}", text replace

/*******************************************************************************
#1. Prep age and sex data for all patients in CPRD 
	>> so that we are able to identify those who will actually contribute
	eligible person time during the study period
	>> also add in eczema diagnosis dates - so that we know when to censor based
	on eczema diagnosis
*******************************************************************************/
* open patient details file
use "${pathCPRDflatfiles}/allpatients_JUL2020", clear
gen pracid=mod(patid, 1000)

* merge in practice information
merge m:1 pracid using "${pathCPRDflatfiles}/allpractices_JUL2020", nogen keep(match)

* generate date of birth
gen day_birth=1
replace mob=7 if mob==0
gen dob=mdy(mob, day_birth, yob)
format dob % td
label var dob DOB

* add in eczema diagnosis dates so that any censoring dates are available
merge 1:1 patid using "${pathOut}/eczemaExposed-eligible-Dxonly-multimorb", keepusing(eczemadateDx) nogen


/*******************************************************************************
#3. Identify start of eligible follow up, latest of:
		- crd +365
		- uts
		- 18th birthday
		- study start
*******************************************************************************/
* identify start of eligibility 
* 18th birthday 
gen happy18th = yob + 18
replace happy18th=mdy(mob, day_birth, happy18th)
format happy18th %td
label var happy18th "date 18, assumes mid year birthday if mob missing"
drop day_birth // no longer needed

* ensure relevant dates available
*assert crd!=.	// 16 contradictions
cap drop if crd==.	// 16 observations deleted
assert uts!=.			// no missing values
assert happy18th!=.		// no missing values

* from: eligible from latest of:
gen eligibleStart = max(crd + 365.25, uts, happy18th, d(02jan2016)) 
format eligibleStart %td 
label var eligibleStart "latest of: crd+365.25, uts, happy18th, d(02jan2016)"

/*******************************************************************************
#4. Identify end of eligible follow up, latest of:
		- crd +365
		- uts
		- 18th birthday
		- study start
*******************************************************************************/
/*
Earliest of:
	1. last collection date
	2. transfer outdate
	3. death date
	4. end of study (31mar2016)
*/
gen eligibleEnd=min(lcd, tod, deathdate, d(31dec2018))
format eligibleEnd %td
label var eligibleEnd "earliest of: lcd, tod, deathdate, d(31dec2014)"


/*******************************************************************************
#5. Only keep people contributing eligible person time during study period
*******************************************************************************/
drop if eligibleStart>=eligibleEnd //(14,723,556 observations deleted)
unique patid // n=6977923

*Drop UNACCEPTABLE PATIENTS
drop if accept==0 // (1,550,780 observations deleted)

unique patid // 5427143

/*******************************************************************************
#6. Flag control pool for MAIN analysis (and sensitivity analysis 2)
*******************************************************************************/
/*
Main analysis and sens. 2 include individuals in the control pool with mno 
eczema Dx code.

We need to exclude those with an eczema code and no therapy codes from the 
pool used to identify the unexposed cohort – this is a question of the 
sensitivity of the algorithm, we want to be sure that those included in the 
exposed cohort truly have eczema and those in the pool of potential unexposed 
definitely do not have eczema.
*/

gen cp_main=1 if eczemadateDx==.
label var cp_main "eligible for main control pool"

tab cp_main, miss

/*
    cp_main |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |  3,252,667       84.53       84.53
          . |    595,282       15.47      100.00
------------+-----------------------------------
      Total |  3,847,949      100.00

*/
/*******************************************************************************
#8. Tidy up and save
*******************************************************************************/
* drop anyone who isn't eligible for either control pool
drop if cp_main==. 

drop mob marital famnum frd regstat reggap internal toreason  accept
	
label data "a CPRD pop. with eligible FU + no eczema Dx " 
notes: a CPRD pop. with eligible FU + no eczema Dx 
notes: notes: ${filename} / TS

sort patid 
compress
save "${pathOut}/controlpool_eczema", replace

log close










