/*=========================================================================
DO FILE NAME:			ecz-extract-03eczemaExposed.do

AUTHOR:					Ali Henderson	
						Adapted from Kate  
						
VERSION:				v2
DATE VERSION CREATED: 	v2 2018-Jan-15	// edited to use extract including individuals identified from HES coding
						v1 2017-Nov-15
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Aim is to identify eczema exposed cohort of patients
						Eczema exposed defined using a combination of Read 
						morbidity coding, primary care prescription data, and 
						ICD-10 coding in HES.
						
						Use existing definition based on Read/ICD-10 codes and 
						therapy codes: 
							- at least one eczema diagnosis code 
							and 
							- at least two therapy codes recorded on separate dates.
						
MORE INFORMATION:		
	1. Identify individuals with eczema therapy using:
		- prodcodes in therapy data
		- Read codes for eczema therapy in clinical/referral data
	2. Identify patients with an eczema diagnosis and 2 treatments on
		separate dates
		
	NB: next file deals with eligibility dates
						
DATASETS USED:	cprd-Clinical-eczemaRx
				cprd-Referral-eczemaRx
				prescriptions-exzemaRx-`x' // where `x' is 1to3 
				results_exca2_linked 	// first recorded eczema morbidity code dates
										// from both CPRD and HES
									
DATASETS CREATED:	eczemaRx-dates 	// dates and source of all eczema Rx records
					eczemaExposed	// individuals with an eczema diagnosis and
									// records for 2 treatments on separate dates
									
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
global filename "mm-extract-asthma-03Exposed"

* open log file
log using "${pathLogs}/${filename}", text replace


/*******************************************************************************
#2. Identify people with an asthma morbidity code Dx (Read or ICD-10)
*******************************************************************************/
* first identify the date of first asthma diagnosis
use "$pathIn/results_mm_extract_asthma", clear


desc // 2,146,815 


unique patid // n= 2146815


* label variables
label var indexdate "earliest morbidity code diagnostic of astma"

order patid index 


/*******************************************************************************
#4. Identify date individuals satisfy eczema diagnosis
	i.e. latest of Read/ICD-10 code or second eczema therapy
*******************************************************************************/
* create eczema diagnosis variable
* latest of Read code or second eczema therapy code
gen asthmadate = indexdate
format asthmadate %td
label var asthmadate "latest of date of astma Dx"
assert asthmadate!=. // OK


* label and save
label data "Asthma exposed (morbidity code)"
notes: Asthma exposed (morbidity code)
notes: NB: not necessarily eligible for FU (based on age, eligible FU, study dates)
notes: ${filename} / TS

sort patid 
compress
save "${pathOut}/asthmaExposed", replace
unique patid // 2146815

log close      
