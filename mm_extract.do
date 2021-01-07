/*=========================================================================
DO FILE NAME:			ecz-master.do

AUTHOR:					Ali Henderson
VERSION:				v1
DATE VERSION CREATED: 	2020-Oct-18
					
DATABASE:				CPRD Jan 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Master file that runs all the project files for 
						cohort study looking at risk of cancer in eczema exposed
						compared to unexposed.
						
MORE INFORMATION:		Both overall cancer risk and risk of specific cancers
									
DO FILES NEEDED:	All files with the exca- prefix.

ADO FILES NEEDED: 	exca.ado

*=========================================================================*/

/*******************************************************************************
>> HOUSEKEEPING
*******************************************************************************/
version 15
clear all
capture log close

* find path file location and run it
adopath + "J:\EHR-working\Ali\2020_multimorbidity"
adopath + "J:\EHR share\ado"


mm_extract paths

* log
log using "${pathLogs}/mm-extract-master", text replace




/*******************************************************************************
********************************************************************************
SECTION A - codelists and data management
********************************************************************************
*******************************************************************************/
* cd to location of data mx do files
cd "${pathPostDofiles}\dataMx"

/*******************************************************************************
#A3. Cohort prep
*******************************************************************************/
//do ecz-extract-processLinkedData // import linked HES/ONS data to Stata and format any date vars
//do ecz-extract-processDeathData // reshape cause of death data so that there is one record per cause (rather than one record/patient)
do mm-extract-01eczema // extract data for everyone with a eczema dx code (in HES/CPRD) who is eligible for HES/ONS linkage
do mm-extract-02eczemaTherapy // extract eczema therapy data (prescriptions and codes for therapy)
do mm-extract-03eczemaExposed // identify those who fulfil the eczema definition (i.e. one dx code, and 2 therapy codes [on separate days])
do mm-extract-04eczemaEligibleCohort 	// identify exposed who are eligible for follow up - identify start and end of eligible follow-up
											// identifies those with diagnosis only eczema
											// and those fulfilling eczema diagnosis + 2 Rx records eczema
											// identifies cohorts for mortality and cancer studies 
											// (cancer study requires an additional 12 months FU after diagnosis before entering cohort)
do mm-extract-05controlPool // identify two pools of potentially unexposed individuals: 
								// 		1. one pool for MAIN analysis and sensitivity analysis 2
								//			include individuals in the control pool until first eczema Dx code.		
								//		2. one pool for sensitivity analysis 1
								//			Censor at the date individuals enter the exposed cohort
								//			i.e. at the point they fulfill the main analysis eczema
								//			defintion (latest of dx or 2nd eczema therapy record) (sens analysis 1)
								//			Individuals with eczema dx but no Rx are included throughout follow-up
								
do mm-extract-06matching 	// match on age, sex and practice to identify unexposed cohorts (for mortality and cancer studies, and each of main, sens1 and sens2 analyses)
								// also exports a list of patids to send to CPRD for HES/ONS data

log close
/*
do exca-extract07-oralCS		// extract therapy data for oral glucocorticoid drugs	
do exca-extract08-systemicRx	// extract therapy data for systemic eczema therapy drugs
do exca-extract09v2-immunosup		// extract data from CPRD and HES for immunosuppression
do exca-extract10v2-DM			// extract morbidity coded data for DM from CPRD and HES	
do exca-extract11-lymphopenia	// extract lymphopenia data from CPRD test records	
do exca-extract12v2-asthma		// extract morbidity coded data for asthma from CPRD and HES		
do exca-extract13v3-cancer		// extract morbidity coded data for cancer from CPRD, HES and ONS
do exca-extract14-harmfulETOH	// extract prescriptions for abstinence maintaining drugs and morbidity coded
								// data suggesting harmful/heavy alcohol intake
								
*/
