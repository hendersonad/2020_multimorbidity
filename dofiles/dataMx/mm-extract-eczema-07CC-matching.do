/*=========================================================================
DO FILE NAME:	aki2-controls03v2-matching.do

AUTHOR:					KM 		
VERSION:				v2.0
DATE VERSION CREATED:	v2 20-April-2015 - edited for new case eligibility
						v1 16-April-2015 					
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE:
	Runs matching program.
	Two sections to program:
		1. Identifies number of cases without potential matches so that parameters
			can be reset before running rest of program.
		2. Extracts controls.
	
INSTRUCTIONS FOR USE:
	Dataset must contain cases and all potential controls, with the following variables:
		patid
		pracid
		sex
		yeardob
		indexdate (cases only)
		startdate
		enddate
		case (1=case 0=non-case)
	
	Change locals to requirements
	
WHEN RUN FOR aki1:
	* allowing 1yr diff in ages > 699 with zero matches
	* allowing 2yrs diff in ages > 140 with zero matches
	* allowing 3yrs diff in ages > 60 with zero matches
	* allowing 4yrs diff in ages > 37 with zero matches >> go with 37 and drop unmatched cases
		
DATASETS USED: 		
	$pathDataDerived/matching
									
DO FILES NEEDED:	aki2-pathsv2.do
					prog_matching.do

DATASETS CREATED:
	`dataset_path'/`dataset'_sorted
	`dataset_path'/`dataset'_allpotentialmatches
	`dataset_path'/`dataset'_cases_with_no_matches
	
	
*=========================================================================*/

version 15
clear all
macro drop _all

/*******************************************************************************
>> identify file locations and set any locals
*******************************************************************************/
* cd to location of file containing all file paths
adopath + "J:\EHR-working\Ali\2020_multimorbidity"
adopath + "J:\EHR share\ado"

mm_extract paths

run "programs\prog_matching.do"

/*
syntax, dataset_path(string) dataset(string) ///
	match_sex(integer) match_age(integer) match_diffage(integer) //
	match_regperiod(integer) ///
	control_minpriorreg(integer) control_minfup(integer) ///
	nocontrols(integer) nopractices(integer) 
*/
* dataset_path			// paths of case/control pool file and path to save output
* dataset				// name of dataset containing all potential controls and eligible cases
* match_sex  			// 0=no, 1=yes
* match_age  			// 0=no, 1=yes
* match_diffage 		// Years difference - This must be entered
* match_regperiod		// 0=no, 1=yes
* control_minpriorreg 	// Days controls must be registered prior to index date of case
* control_minfup 0 		// Days controls must be registered after index date of case
* nocontrols			// number of controls to match to every case
* nopractices 	 		// Maximum practice ID number




/*******************************************************************************
#1. Run matching program with ***2*** years 
		- starting at 2 rather than 1 becuase had to go for 4 years in pilot
*******************************************************************************/
use "${pathOut}\expANDunexppool-main-multimorb-eczema.dta", clear

rename yob yeardob
rename gender sex
rename exposed case
gen pracid = mod(patid, 1000)
t
save "${pathOut}\expANDunexppool-main-multimorb-eczema-CCmatch.dta", replace
/*
tab case

      0=potential |
         control; |
        1=exposed |      Freq.     Percent        Cum.
------------------+-----------------------------------
potential control |  3,739,688       88.57       88.57
          exposed |    482,460       11.43      100.00
------------------+-----------------------------------
            Total |  4,222,148      100.00
*/

prog_matching, dataset_path($pathOut\) /// 
	dataset("expANDunexppool-main-multimorb-eczema-CCmatch") ///
	match_sex(1) match_age(1) match_diffage(5) /// 
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(5) nopractices(937) // 937 practices JUL2020 build 

/*
Time started matching = 11:18:12
Time ended matching = 12:25:51
Number of cases with zero potential matches = 112
*/

use "expANDunexppool-main-multimorb-eczema-CCmatch_selected_matches", clear

keep caseid 
duplicates drop caseid , force
rename caseid contid
tempfile cases
save `cases', replace

use "expANDunexppool-main-multimorb-eczema-CCmatch_selected_matches", clear
keep contid

append using `cases'  

duplicates drop contid, force
desc
rename contid patid
save ${MMpathIn}\results_mm_eczema_extract_matched, replace

/*------------------------------------------------------------------------------
C3. Extract CPRD data for everyone from all cohorts (x2):
	- multimorb studies
	- main, sens1 analyses
------------------------------------------------------------------------------*/
/*
log will stop running because of timings log for extract, so stop running 
explicitely now
*/

cap log close

rungprddlg, define(0) extract(1) build(July 2020) directory(${MMpathIn}) ///
	studyname(mm_eczema_extract_matched) memorytoassign(5g)


	
	
	

