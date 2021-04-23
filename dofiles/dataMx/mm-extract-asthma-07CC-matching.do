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

run "dofiles\Kate_matching\prog_matching.do"

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
* study					// Name of study will be appended onto "Test*.dta" 



/*******************************************************************************
#1. Run matching program with ***2*** years 
		- starting at 2 rather than 1 becuase had to go for 4 years in pilot
*******************************************************************************/
use "${pathOut}\expANDunexppool-main-multimorb-asthma.dta", clear

rename yob yeardob
rename gender sex
rename exposed case
gen pracid = mod(patid, 1000)

save "${pathOut}\expANDunexppool-main-multimorb-asthma-CCmatch.dta", replace

tab case
/*
      0=potential |
         control; |
        1=exposed |      Freq.     Percent        Cum.
------------------+-----------------------------------
potential control |  3,847,839       88.70       88.70
          exposed |    490,329       11.30      100.00
------------------+-----------------------------------
            Total |  4,338,168      100.00

*/

/*
prog_matching, dataset_path($pathOut\) /// 
	dataset("expANDunexppool-main-multimorb-asthma-CCmatch") ///
	match_sex(1) match_age(1) match_diffage(5) /// 
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(5) nopractices(937) ///
	study("asthma")
*/

prog_matching_asthma, dataset_path($pathOut\) /// 
	dataset("expANDunexppool-main-multimorb-asthma-CCmatch") ///
	match_sex(1) match_age(1) match_diffage(5) /// 
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(5) nopractices(937) ///
	study("asthma")
/*
Time started matching = ??
Time ended matching = 17:15:53

Number of cases with zero potential matches = 175
*/
	
use "${pathOut}/expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches", clear
append using "${pathOut}/expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches_asthma"
bysort caseid:gen n1=_n
bysort caseid:gen N1=_N
tab N1

preserve
collapse (max)N1, by(caseid)
nopeople caseid
noi tab N1
restore
/*

   (max) N1 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |         31        0.01        0.01
          2 |         29        0.01        0.01
          3 |         29        0.01        0.02
          4 |         42        0.01        0.03
          5 |    489,692       99.97      100.00
------------+-----------------------------------
      Total |    489,823      100.00
*/
save "${pathOut}/expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches_combined", replace
//use "${pathOut}/expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches_combined", clear

keep caseid 
duplicates drop caseid , force
rename caseid contid
tempfile cases
save `cases', replace

use "${pathOut}/expANDunexppool-main-multimorb-asthma-CCmatch_selected_matches_combined", clear
keep contid

append using `cases'  

duplicates drop contid, force
count
rename contid patid
save ${MMpathIn}\results_mm_asthma_extract_matched, replace

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

rungprddlg_skinepi, define(0) extract(1) build(July 2020) directory(${MMpathIn}) ///
	studyname(mm_asthma_extract_matched) memorytoassign(2g)


	