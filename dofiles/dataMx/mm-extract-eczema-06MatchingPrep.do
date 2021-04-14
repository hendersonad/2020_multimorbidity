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



local condition = "eczema"


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
		// NO longer valid since case-control design. A diagnosis at any time excludes from control
		
		
		****** #A1.2	identify potential controls
		* open file containing ALL potential controls (will include some exposed individuals)
		use ${pathOut}/controlpool_eczema, clear
		if "`analysis'"=="main" keep if cp_main==1 // only keep those eligible for entry in main/sens2 control pool
		drop yob crd tod deathdate pracid region lcd uts 
		
		* identify and drop any individuals who are in the exposed cohort from the control pool
		* by merge with eczema cohort and only keeping unmatched records from master dataset (i.e. drop records in exposed dataset only or both exposed and control pool datasets)
		if "`analysis'"=="main" merge 1:1 patid using ${pathOut}/eczemaExposed-eligible-`cohort', keep(master) nogen keepusing(patid) // drop any in main/sens1 exp

	
	
	
		******* #A1.3 	add back in any valid pre-diagnosis time for incident eczema cases
		* add in any unexposed time for the individuals in the exposed cohort 
// NO longer valid since case-control design. A diagnosis at any time excludes from control		
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
		save ${pathOut}/expANDunexppool-`analysis'-`cohort'-`condition', replace

	} /*end foreach analysis in main sens1 sens2*/

} /*end foreach cohort in cancer mortality*/






/* STOP HERE AND MOVE TO CC-MATCHING ALGORITHM (TIM COLLIER CODE '07CC-MATCHING')
