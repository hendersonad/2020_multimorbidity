/*=========================================================================
DO FILE NAME:			ecz-extract-06matching.do

AUTHOR:					Ali Henderson	
						Adapted from KATE
						
VERSION:				v2
DATE VERSION CREATED: 	2017-Jan-24	// edited to use only one control pool file after edit of extract05
									// also reviewed all code as sanity check
						2017-Nov-23
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Aims to identify 3 x matched cohorts for main and 2x 
						sensitivity analyses.
						
						Main analysis:
							Exposed: main eczema (dx + 2xRx) definition (eczemaExposed-eligible)
							Unexposed: censor at first eczema Dx code (controlpool.dta where cp_main_sens2==1)
						
						Sensitivity 1:
							Exp: main eczmea def (eczemaExposed-eligible)
							Unexp: censor when individuals meet main eczema def (controlpool.dta where cp_sens1==1)
							
						Sensitivity 2:
							Exp: eczema dx code only (eczemaExposed-eligible-Dxonly)
							Unexpo: censor at first eczema Dx code (controlpool.dta where cp_main_sens2==1)
						
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
						
					Variables required for matching 
						patid:          CPRD patient id
						indexdate:      date of "exposure" for exposed patients (missing for 
										potential controls)
										THIS IS OUR COHORT ENTRY DATE - i.e Date patient enters cohort: 
										Incident pats=index date 
										Prevalent pats=max(d(01apr1997), startdate, date18)
										Unexposed patients: max (startdate, d(01apr1997), date18)
						gender:         gender, numerically coded (e.g. 1=male, 2=female)
						startdate:      date of start of CPRD follow-up
										IE: THE (LATEST OF CRD+12 months or UTS date)
						enddate:        date of end of follow-up as a potential control, 
										generally = end of CPRD follow-up, but see 
										"important note" below
						exposed:        indicator: 1 for exposed patients, 0 for potential 
										controls
						yob:            year of birth
					
DATASETS USED:	`cohort' here is either cancer or mortality (difference is in entry dates eczema+365 for cancer, eczema dx date for mortality
				eczemaExposed-eligible-`cohort'	// individuals eligible for FU meeting eczema definition
				eczemaExposed-eligible-Dxonly-`cohort' // eligible people meeting Dx only eczema defintion
				controlpool		// a dataset of individuals eligible for 
								// inclusion in the control pool: acceptable, eligible for linkage
								// 18yrs+ with valid FU during study period
								// no eczema diagnosis before start of eligibility
								// (both dx-only eczema definition and main analysis eczema defintion)	
									
DATASETS CREATED:	expANDunexppool-`analysis'-`cohort' // where `analysis' == main, sens1 or sens2
														// and `cohort' == cancer or mortality (difference in entry dates for exposed)
														// cancer cohort enter at latest of: crd+365.25, uts, study start, 18yrs, eczema dx+365.25
														// mortality cohort enter at latest of: crd+365.25, uts, study start, 18yrs, eczema dx
					getmatchedcohort-`analysis'-`cohort'	// all exp and unexposed matches for each analysis for both mortality and cancer cohorts
					
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
global filename "mm-extract-eczema-06matching"

* open log file
log using "${pathLogs}/${filename}", text replace






/*******************************************************************************
********************************************************************************
#A. PREPARE DATASETS
********************************************************************************
*******************************************************************************/
/*
Need a dataset for each of: main, SA1
With variables described above: patid, index, gender, startdate, enddate, exposed, yob
*/

/*******************************************************************************
Main analysis 
	Exposed: main eczema (dx + 2xRx) definition (eczemaExposed-eligible)
	Unexposed: censor at first eczema Dx code (controlpool.dta where cp_main_sens2==1) ALI -- ?? 
Sensitivity 1:
	Exp: main eczmea def (eczemaExposed-eligible)
	Unexp: censor when individuals meet main eczema def (controlpool.dta where cp_sens1==1)
Sensitivity 2:
	Exp: eczema dx code only (eczemaExposed-eligible-Dxonly)
	Unexpo: censor at first eczema Dx code (controlpool.dta where cp_main_sens2==1)

*******************************************************************************/
foreach cohort in multimorb {
	display ""
	display "*************************************************************"
	display "*** `cohort' cohort ***"
	display "*************************************************************"
	foreach analysis in main {
		display ""
		display "*************************************************************"
		display "*** analysis: `analysis' ***"
		display "*************************************************************"

/*------------------------------------------------------------------------------
		A1. Unexposed
		------------------------------------------------------------------------------*/
		****** #A1.1 	Identify INCIDENT cases with valid unexposed follow-up 
		* so that they can be included in the control pool up until their
		* eczema diagnosis
		
		local cohort = "multimorb"
		local analysis = "main"
		
		if "`analysis'"=="main" use ${pathOut}/eczemaExposed-eligible-`cohort', clear
		if "`analysis'"=="sens1" use ${pathOut}/eczemaExposed-eligible-`cohort', clear
		if "`analysis'"=="sens2" use ${pathOut}/eczemaExposed-eligible-Dxonly-`cohort', clear
	 
		* change date of end of follow up to day before date of eczema diagnosis
		* Dx date will be different depending on diff analyses (main/sens1/sens2)
		/*
		keep if incid==1 // incid==1 if eczema Dx > eligigle start of FU (var created in extract04 #4 and #5)		
	
		if "`analysis'"=="main" replace eligibleEnd=min(eczemadateDx-1, eligibleEnd) 	// censor at first eczema code
		if "`analysis'"=="sens1" replace eligibleEnd=min(eczemadate-1, eligibleEnd)		// censor when individuals meet main eczema def
		if "`analysis'"=="sens2" replace eligibleEnd=min(eczemadateDx-1, eligibleEnd)	// censor at first eczema code
		*/
		* now drop any who are no longer eligible for FU due to eligibleEnd date now reset to after eligibleStart
		drop if eligibleStart>eligibleEnd
		
		* temporarily save the incident eczema cases to be appended on to the 
		* rest of the control pool in a mo' (i.e. at #A1.3)
		keep patid gender dob eligible* matchDate
		tempfile unexposedtime_preDx
		di "Number of cases that contribute time to be potentially selected as control ------------------------------------"
		count 
		save `unexposedtime_preDx', replace

		
		
		****** #A1.2	identify potential controls
		* open file containing ALL potential controls (will include some exposed individuals)
		use ${pathOut}/controlpool, clear
		if "`analysis'"=="main" keep if cp_main_sens2==1 // only keep those eligible for entry in main/sens2 control pool
		if "`analysis'"=="sens1" keep if cp_sens1==1	// only keep those eligible for entry in sens1 control pool
		if "`analysis'"=="sens2" keep if cp_main_sens2==1	// only keep those eligible for entry in main/sens2 control pool
		drop yob crd tod deathdate pracid region lcd uts 
		
		* identify and drop any individuals who are in the exposed cohort from the control pool
		* by merge with eczema cohort and only keeping unmatched records from master dataset (i.e. drop records in exposed dataset only or both exposed and control pool datasets)
		if "`analysis'"=="main" merge 1:1 patid using ${pathOut}/eczemaExposed-eligible-`cohort', keep(master) nogen keepusing(patid) // drop any in main/sens1 exp
		if "`analysis'"=="sens1" merge 1:1 patid using ${pathOut}/eczemaExposed-eligible-`cohort', keep(master) nogen keepusing(patid) // drop any in main/sens1 exp
		if "`analysis'"=="sens2" merge 1:1 patid using ${pathOut}/eczemaExposed-eligible-Dxonly-`cohort', keep(master) nogen keepusing(patid) // drop any in sens2 exp (i.e. diagnosis only)

	
	
	
		******* #A1.3 	add back in any valid pre-diagnosis time for incident eczema cases
		* add in any unexposed time for the individuals in the exposed cohort 
		append using `unexposedtime_preDx'	
		
		****** #A1.4 	create useful variables and flag as unexposed
		* create variables for enddate and indexdate		
		* identify startdate and enddate (variables needed for use in matching algorithm)
		generate startdate=eligibleStart
		format startdate %td

		generate enddate=eligibleEnd
		format enddate %td
		
		* keep useful variables
		keep patid gender dob startdate enddate
		
		* add in matchDate to match exposed data setdrop matchdatde
		gen matchDate = enddate
		format matchDate %td
		
		* identify as unexposed
		generate exposed=0
		label var exposed "0=potential control; 1=exposed"
		label define exp 0"potential control" 1"exposed"
		label values exposed exp
		/*------------------------------------------------------------------------------
		A2. Exposed
		------------------------------------------------------------------------------*/
		* append eczema exposed cases and flag them as exposed
		if "`analysis'"=="main" append using ${pathOut}/eczemaExposed-eligible-`cohort', keep(patid gender dob eligibleStart eligibleEnd entry matchDate)
		if "`analysis'"=="sens1" append using ${pathOut}/eczemaExposed-eligible-`cohort', keep(patid gender dob eligibleStart eligibleEnd entry matchDate)
		if "`analysis'"=="sens2" append using ${pathOut}/eczemaExposed-eligible-Dxonly-`cohort', keep(patid gender dob eligibleStart eligibleEnd entry matchDate)

		* flag exposed cases
		recode exposed .=1
		tab exposed
		
		* set start and end dates appropriately for eczema exposed
		replace startdate=entry if exposed==1
		replace enddate=eligibleEnd if exposed==1
		assert startdate<=enddate 
		
		
		
		
		/*------------------------------------------------------------------------------
		A3. Rename variables to those expected by the matching program
		------------------------------------------------------------------------------*/
		* indexdate var represents date of start of FU
		rename matchDate indexdate // indexdate in this study will be latest of: crd+365, uts, eczema diagnosis, 18th birthday, study start (i.e. what is currently entry date)
				// NB: do not confuse with the var indexdate used in early do files which represented earliest diagnostic code for eczema
		di "Dropping if gender == 3 -----------------------------"
		count if gender == 3
		drop if gender==3
		gen yob=year(dob)

		keep patid indexdate gender startdate enddate exposed yob dob 
		sort patid exposed
		by patid exposed: assert _n==1	// check that individuals only a occur a max of once as exposed and once as unexposed
		
		label define sex 2"female" 1"male"
		label values gender sex
		
		/*------------------------------------------------------------------------------
		A4. Check variables are complete and save
		------------------------------------------------------------------------------*/
		sum gender
		sum patid
		sum indexdate
		sum start
			local startdate_mu r(mean)
			di "Average start date ------------------------------------"
			display %td `startdate_mu'
		sum enddate
			local enddate_mu r(mean)
			di "Average end date ------------------------------------"
			di %td `enddate_mu'
		sum yob
		
		tab exposed
		label data "`cohort' cohort: exp + potential unexp for `analysis' analysis" 
		notes: `cohort' cohort: exp + potential unexp for `analysis' analysis
		notes: notes: ${filename} / TS
		compress
		save ${pathOut}/expANDunexppool-`analysis'-`cohort', replace

	} /*end foreach analysis in main sens1 sens2*/

} /*end foreach cohort in cancer mortality*/








/*******************************************************************************
********************************************************************************
#B. MATCHING
********************************************************************************
*******************************************************************************/

/*------------------------------------------------------------------------------
B1. IDENTIFY AGE WINDOW FOR MATCHING
		Loop through getting matches allowing different age window to get 
		an idea of reasonable window for age matching
------------------------------------------------------------------------------*/

use ${pathOut}/expANDunexppool-main-multimorb, clear 

forvalues years=5(5)15 {
	display ""
	display "**********************************************************"
	display "allowing `years'years between exposed and unexposed match"
	display "**********************************************************"
	display ""
	use $pathOut/expANDunexppool-main-multimorb, clear
	sample 1, by(exposed)
	tab exposed, miss
	set seed 3367
	getmatchedcohort, practice gender yob yobwindow(`years') followup ctrlsperexp(5) savedir($pathOut) dontcheck cprddb("gold")
} /* end forvalues years=5(5)15 */


/*------------------------------------------------------------------------------
B2. Match
------------------------------------------------------------------------------*/
foreach cohort in multimorb {
	display ""
	display "*************************************************************"
	display "*** `cohort' cohort ***"
	display "*************************************************************"
	foreach analysis in main {
		display ""
		display "*************************************************************"
		display "*** analysis: `analysis' ***"
		display "*************************************************************"

		use ${pathOut}/expANDunexppool-`analysis'-`cohort', clear
		tab exposed, miss
		
		set seed 3367
		getmatchedcohort, practice gender yob yobwindow(5) followup ctrlsperexp(5) savedir($pathOut) dontcheck cprddb("gold")
		
		* save results to file with appropriate suffix
		* first open dataset created by matching algorithm
		use ${pathOut}/getmatchedcohort.dta, clear
		
		* identify number of matches per exposed patient
		bysort set: gen bign=_N
		tab bign
		
		* label and save
		label data "`cohort' cohort - `analysis' analysis" 
		notes: `cohort' cohort - `analysis' analysis
		notes: NB: there will be duplicate patids in this file if px exp+unexp
		notes: ${filename} / TS
		compress
		
		save ${pathOut}/getmatchedcohort-`analysis'-`cohort', replace /*all exposed and unexp: includes duplicates*/
		
		erase ${pathOut}/getmatchedcohort.dta // clean up file created by getmatchedcohort program
	} /*end foreach analysis in main sens1 sens2*/
} /*end foreach cohort in cancer mortality*/



/*------------------------------------------------------------------------------
B3. Review age and sex distribution of eczema exposed with no match vs those with
	a match 
	for MAIN ANALYSIS for both cancer and mortality cohorts
------------------------------------------------------------------------------*/
foreach cohort in multimorb {
	display ""
	display "*************************************************************"
	display "*** `cohort' cohort ***"
	display "*************************************************************"
	
	* open exposed and unexposed pool file and only keep exposed
	use ${pathOut}/expANDunexppool-main-`cohort', clear
	keep if exposed==1
	
	* identify those with matches
	merge 1:1 patid exposed using ${pathOut}/getmatchedcohort-main-`cohort'
	keep if exposed==1
	
	* look at those with matches versus those without matches
	display ""
	display "*************************************************************"
	display "unmatched"
	display "*************************************************************"
	count if _merge==1
	tab yob if _merge==1
	tab gender if _merge==1
	
	display ""
	display "*************************************************************"
	display "matched"
	display "*************************************************************"
	count if _merge==3
	tab yob if _merge==3
	tab gender if _merge==3
	
	tab gender _merge if _merge != 2, col

} /*end foreach cohort in cancer mortality*/

/*******************************************************************************
********************************************************************************
#C. Get data for all cohorts
	1. Identify patids for all patients (exposed and unexposed) from both cohorts 
	(and for all 3 analyses)
	2. Export a list of patids to send to CPRD to request HES and ONS data
	3. Extract CPRD data for all individuals 
********************************************************************************
*******************************************************************************/
/*------------------------------------------------------------------------------
C1. Get list of patients
------------------------------------------------------------------------------*/
use ${pathOut}\getmatchedcohort-main-multimorb, clear
tab exposed
/* No Sensitivity Analysis for now
foreach analysis in sens1 {
	append using ${pathOut}\getmatchedcohort-`analysis'-multimorb
} /*end foreach analysis in main sens1 sens2*/
*/
* just keep list of individual patients only
keep patid
duplicates drop

* save in the appropriate directory for extraction tool to find
* i.e. in the same directory where I want datasets to be saved following
* extraction using CPRDFast tool
label data "patids for all cohorts (multimorb) and all analyses"
notes: patids for all cohorts (multimorb) and all analyses
notes: ${filename} / TS
compress
save ${MMpathIn}/results_ecz_extract3, replace

count
/*
/*------------------------------------------------------------------------------
C2. Export a list of patids to send to CPRD to request HES and ONS data
------------------------------------------------------------------------------*/
/*
linked data request form states:
Please complete the form below and email this together with your list of patient 
ids, including each patient’s linkage eligibility flag/s (e.g. hes_e=1) 
in text file format (.txt) to the kc@cprd.com. 
*/
merge 1:1 patid using "${pathLinkageEligibility}/linkage_eligibility", nogen keep(match) keepusing(hes_e death_e lsoa_e)

notes: patids for all cohorts (multimorb) and all analyses
notes: patids to send with request for linked data
notes: ${filename} / TS
compress
save "${pathOut}\patids_request_linked_data", replace

* export a tab delimited text file
export delimited using "${pathOut}\patids_request_linked_data.txt", delimiter(tab) replace
*/







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
	studyname(ecz_extract3) memorytoassign(5g)


//  obs:       282,816


/*

     name:  <unnamed>
       log:  J:\EHR-Working\Helena\log\ 2020 10 30_172042_lsh1510922_extractti
> mings_ecz_extract3.smcl
  log type:  smcl
 opened on:  30 Oct 2020, 17:20:42
------------------------------------------------------------------------------
      name:  <unnamed>
       log:  Z:\GPRD_GOLD\Ali\2020_eczema_extract\in/timings.log
  log type:  text
 opened on:  30 Oct 2020, 17:20:42
Time of starting =                          14:25:38
Time of finishing =                         17:20:42
 

*********************************************************************
Time finished extracting Additional =       14:33:21
Time finished extracting Clinical =         14:54:53
Time finished extracting Consultation =     15:14:07
Time finished extracting Patient =          15:21:37
Time finished extracting Referral =         15:24:56
Time finished extracting Test =             15:48:24
Time finished extracting Therapy =          16:48:10
Time finished extracting Immunisation =     15:18:48
 

*********************************************************************
Time finished appending Additional =        16:48:53
Time finished appending Clinical =          16:51:26
Time finished appending Consultation =      16:54:22
Time finished appending Patient =           16:54:34
Time finished appending Referral =          16:54:42
Time finished appending Test =              16:57:28
Time finished appending Therapy =           17:03:03
Time finished appending Immunisation =      16:54:31

Time finished erasing files =               17:20:41

Time finished creating practice file =      17:20:42
      name:  <unnamed>
       log:  Z:\GPRD_GOLD\Ali\2020_eczema_extract\in/timings.log
  log type:  text
 closed on:  30 Oct 2020, 17:20:42
------------------------------------------------------------------------------
      name:  <unnamed>
       log:  J:\EHR-Working\Helena\log\ 2020 10 30_172042_lsh1510922_extractti
> mings_ecz_extract3.smcl
  log type:  smcl
 closed on:  30 Oct 2020, 17:20:42
------------------------------------------------------------------------------


*/






