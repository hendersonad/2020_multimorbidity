/*=========================================================================
DO FILE NAME:	prog_matching

AUTHOR:					Tim Collier - original author 		
VERSION:				v1.0
DATE VERSION CREATED:	16-April-2015 					
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE:
	REVISED 18/08/2014: Program previosuly had practice as an optional matching factor, however 
		the program automatically matches on practice.

	REVISED 12/07/2013: Program amended to allow controls to be selected more than once.

	This do file matches on practice, sex, age and registration period (controls must be active at time of case). 
	Controls can also be excluded if don't meet minimum registration time prior/after indexdate.
	- extra things to match on: calender time (think covered by registration period)
	
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
		
DATASETS USED: 		
	$pathDataDerived/matching
									
DO FILES NEEDED:	aki2-pathsv2.do

DATASETS CREATED:
	`dataset_path'/`dataset'_sorted
	`dataset_path'/`dataset'_allpotentialmatches
	`dataset_path'/`dataset'_cases_with_no_matches

Eg of how to run:
prog_matching, dataset_path($pathDataDerived) dataset(matching) ///
	match_sex(1) match_age(1) match_diffage(2) ///
	match_regperiod(1) ///
	control_minpriorreg(0) control_minfup(0) ///
	nocontrols(10) nopractices(685) 
	
*=========================================================================*/


/*******************************************************************************
#>> Define program
*******************************************************************************/
cap prog drop prog_matching
program define prog_matching

syntax, dataset_path(string) dataset(string) ///
	match_sex(integer) match_age(integer) match_diffage(integer) match_regperiod(integer) ///
	control_minpriorreg(integer) control_minfup(integer) ///
	nocontrols(integer) nopractices(integer) 
	
* dataset_path			// paths of case/control pool file and path to save output
* dataset				// name of dataset containing all potential controls and eligible cases
* match_sex  			// 0=no, 1=yes
* match_age  			// 0=no, 1=yes
* match_diffage 		// Years difference - This must be entered
* match_regperiod		// 0=no, 1=yes
* control_minpriorreg 	// Days controls must be registered prior to index date of case
* control_minfup 0 		// Days controls must be registered after index date of case
* nocontrols			// number of controls to match to every case
* nopractices 	 		// Maximum practice ID number to check through






/*******************************************************************************
************************************************************
#1. Identify num of cases without potential matches
************************************************************
*******************************************************************************/
qui {
		noi di in green "***********************************************"
		noi di in green "Warning, current data in memory will be erased!"
		noi di in green "***********************************************"
		noi di 
		noi di "Press y (then return) to confirm or anything else to quit" _request(keyentry)
		if "$keyentry"!="y" error 1
		clear

clear
set mem 5g
set more off
cd "`dataset_path'"

noi dib "Match cases to ALL potential controls", stars

use "`dataset'", clear


* SORT DATA SET SO THAT CASES COME FIRST
gsort - case pracid sex
*keep if inrange(pracid, 1,663)
save "`dataset'_sorted" , replace

use "`dataset'_sorted", clear
levelsof pracid, local(praclist)

* Check time taken
local timestart=c(current_time)

foreach a in `praclist' {
	qui use "`dataset'_sorted", clear
	qui keep if pracid==`a'
	noi di "`a' " _cont


* COUNT NUMBER OF CASES AND OBSERVATIONS 
* AND CREATE MACROS FOR THE TWO LOOPS

qui count if case==1 
local N1=r(N)

* SET UP POSTFILE 
capture postclose temp2
postfile temp2  long id1 long id0 year1 year0 sex1 sex0 pracid1 pracid0 indexdate start stop using test`a'  , replace

* FIRST LOOP GOES THROUGH EACH CASE IN TURN


cap forvalues i=1/`N1' {

* PUT RELEVANT INFORMATION FOR EACH CASE IN SCALAR

	scalar year1=yeardob[`i']
	scalar sex1=sex[`i']
	scalar pracid1=pracid[`i']
	scalar id1=patid[`i']
	scalar d_index=indexdate[`i']

	
	qui preserve
	* Drop non-matching patients
	
	if `match_sex'==1 {
	qui keep if sex==sex1 
	}
	qui keep if pracid==pracid1
	if `match_regperiod'==1 {
	qui keep if (startdate+`control_minpriorreg')<d_index
	qui keep if (enddate-`control_minfup')>d_index
	}
	if `match_age'==1  {
	qui keep if abs(yeardob-year1)<`match_diffage' 
	}
	
* SECOND LOOP GOES THROUGH EACH CONTROL IN TURN 
* CHECKING FOR MATCHES

	qui count if case==1
	local N2=r(N)+1
	qui count
	local N3=r(N)

	forvalues j=`N2'/`N3' {

			scalar year0=yeardob[`j']
			scalar id0=patid[`j']
			scalar sex0=sex[`j']
			scalar pracid0=pracid[`j']
			scalar d_start=startdate[`j']
			scalar d_end=enddate[`j']
	
		* CHECK FOR MATCHES
		* IF MATCHES FOUND SEND DATA TO TEMPFILE
		post temp2 (id1) (id0) (year1) (year0) (sex1) (sex0) (pracid1) (pracid0) (d_index) (d_start) (d_end) 
		}
	qui restore
	}
}

* AT END OF PROGRAM CLOSE TEMPFILE AND CREATE DATA SET
postclose temp2 

local timeend=c(current_time)
noi disp
noi disp "Time started matching = `timestart'"
noi disp "Time ended matching = `timeend'"

use "`dataset'_sorted", clear

levelsof pracid, local(praclist)

use test1 , clear
forvalues i=2/`nopractices'  {
		cap append using test`i'
			}		
save "`dataset'_allpotentialmatches", replace

forvalues i=1/`nopractices'  {
		cap erase test`i'.dta
			}		

********************************************************
*Saves a dataset with ids which don't get any matches
********************************************************
preserve
use "`dataset'_sorted", clear
keep if case==1
rename patid id1
merge 1:m id1 using "`dataset'_allpotentialmatches"
keep if _merge==1 
nopeople id1
local total=r(N)
noi disp "Number of cases with zero potential matches = `total'"
save "`dataset'_cases_with_no_matches", replace
keep  id1 sex startdate enddate indexdate pracid yeardob case
rename id1 patid
restore

		********************************************************************
		
		noi di in green "***********************************************"
		noi di in green "Warning, are you happy with the potential matches file?"
		noi di in green "***********************************************"
		noi di 
		noi di "Press y (then return) to confirm or anything else to quit" _request(keyentry)
		if "$keyentry"!="y" error 1
		clear

		
		************************************************************
	
	
	
	
	

/*******************************************************************************
************************************************************
#2. Extract matches
************************************************************
*******************************************************************************/		
		
		

********************************************************/
* Load data containing cases and all possible controls
********************************************************
use "`dataset'_allpotentialmatches", clear

* Next few commands order the dataset by increasing availability
* of controls to give priority to those with fewest possible matches,
	bysort id1:gen n1=_n
	bysort id1:gen N1=_N
	sort N1 id1 n1
	qui gen x1=(n1==1)	
	qui gen caseset=sum(x1)

* Create variable for difference in age between cases and controls
* Following program will randomly select controls but gives preference
* to controls who are closest in age
	gen agediff=abs(year1-year0)
* Reduce dataset to minimum number of variables required
	keep id1 id0 caseset pracid1 agediff

	save "`dataset'_allpotentialmatches_1", replace


	
********************************************************
* Next section selects up to `nocontrols' controls per case
* There are three loops
* (i) Loop through each practice
* (ii) Loop through each case in current practice
* (iii) Loop `nocontrols' times through EACH CASE

********************************************************

noi dib "Selects up to `nocontrols' controls per case", stars

use "`dataset'_allpotentialmatches_1" , clear

local timestart=c(current_time)
set more off

* Important: setting the "random" seed allows you to reproduce results exactly
set seed 543210

* Set up temporary postfile for patid numbers for cases and controls
postfile temp6 long caseid long contid  using `dataset'_selected_matches, replace

* create local macro containing list of practice ids
qui levelsof pracid1 , local(pid)  


foreach p of local pid  {    // Loop 1 thru each practice
* Need to reload complete data at beginning of each loop as we
* drop observations of all practices other than current
qui use "`dataset'_allpotentialmatches_1" , clear
qui keep if pracid1==`p'

noi disp _dup(70) _char(151)
noi disp "Selecting controls from practice id `p'" 
noi disp _dup(70) _char(151)

qui levelsof caseset , local(sets)

foreach i of local sets {  // Loop 2 through each case
	qui preserve
	qui keep if caseset==`i'
	
forvalues j=1/`nocontrols' {  // Loop 3 - select up to 10 controls

	if _N>0  { /*i.e if there is an eligible control*/
		gen u=uniform()
		sort agediff u
		local id1=id1[1]
		local id0=id0[1]
		qui drop if id0==`id0' /*drops controls already selected for that case*/
		post temp6 (`id1') (`id0')
		drop u
		} 
	 	if `j'==`nocontrols' restore
		noi di "." _cont
	}  // end Loop 3	
	}  // end Loop 2 
	nowandthen `timestart'
	}  // end Loop 1 (practices)

postclose temp6

local timeend=c(current_time)
noi disp
noi disp "Time started selecting controls:  `timestart'"
noi disp "Time finshed selecting controls:  `timeend'"
noi disp
nowandthen `timestart'

erase "`dataset'_allpotentialmatches_1.dta" 
erase "`dataset'_sorted.dta" 

*Summarise number of matches per case
use `dataset'_selected_matches, clear
bysort caseid:gen n1=_n
bysort caseid:gen N1=_N
tab N1

preserve
collapse (max)N1, by(caseid)
nopeople caseid
noi tab N1
restore

} //end quietly


end
