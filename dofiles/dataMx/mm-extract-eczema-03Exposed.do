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
global filename "mm-extract-03eczemaExposed"

* open log file
log using "${pathLogs}/${filename}", text replace






/*******************************************************************************
#1. Identify all those with any eczema therapy code
	- from prescription data, and Read codes (in Clinical and Referral files)
*******************************************************************************/
/*------------------------------------------------------------------------------
#1.1 From therapy data
------------------------------------------------------------------------------*/
display in red "******************* therapy file number: 1 *******************"
use ${pathOut}/prescriptions-eczemaRx-1, clear
keep patid eventdate
save ${pathOut}/eczemaRx-dates, replace


* loop through and add other therapy files
forvalues n=2/15 {
	display in red "******************* therapy file number: `n' *******************"
	use ${pathOut}/prescriptions-eczemaRx-`n', clear
	keep patid eventdate
	
	* add the file containing the records from the first therapy file
	append using "${pathOut}/eczemaRx-dates"
	
	* save
	compress
	save "${pathOut}/eczemaRx-dates", replace
} /*end forvalues n=2/15*/

* create a marker to flag the source of these records (see label added in #1.2)
gen src=1

* save
compress
save "${pathOut}/eczemaRx-dates", replace
	


	
	
/*------------------------------------------------------------------------------
#1.2 From Clinical/Referral file data
------------------------------------------------------------------------------*/
foreach filetype in Clinical Referral { 
	use ${pathOut}/cprd-`filetype'-eczemaRx, clear
	keep patid eventdate
	
	* add source flag
	if "`filetype'"=="Clinical" {
		gen src=2
	} 
	if "`filetype'"=="Referral" {
		gen src=3
	} 
	
	* add the file containing the records from the therapy records
	append using "${pathOut}/eczemaRx-dates"
	
	* save
	compress
	save "${pathOut}/eczemaRx-dates", replace

} /*end foreach filetype in Clinical Referral*/


* Add notes and labels to the data
label var src "source of therapy record"
label define src 1"Therapy" 2"Clinical" 3"Referral"
label values src src
label data "Dates of records for eczema therapy"
notes: Dates and sources of records for eczema therapy
notes: ${filename} / TS

sort patid eventdate

* save
compress
save "${pathOut}/eczemaRx-dates", replace


unique patid // n= 2,113,877










/*******************************************************************************
#2. Identify people with an eczema morbidity code Dx (Read or ICD-10) 
	and eczema therapy record
*******************************************************************************/
***ECZEMA TREATMENTS 
* identify patients with 2 Rx on seperate days (any time relative to eczema diagnosis)
* (drop patients with zero, 1 Rx or +1 Rx on same day)

* first identify the date of first eczema diagnosis
merge m:1 patid using "$pathIn/results_ecz_extract"



/*
results from second run (including patients identified in HES)
NB: each record now represents either a record for individuals with no 
therapy records (eventdate==. & src==. _merge==2)
or 
each therapy record for an individual _merge==3)

    Result                           # of obs.
    -----------------------------------------
    not matched                       123,662
        from master                         0  (_merge==1)	// everyone with a therapy record has an eczema Read code - not a surprise (this is how this set of patients is defined)
        from using                    123,662  (_merge==2)	// has Dx code but no therapy record

    matched                        19,217,990  (_merge==3)	// has both Dx code and at least one therapy record
    -----------------------------------------
	
	
	ALI version 
	

    Result                           # of obs.
    -----------------------------------------
    not matched                       264,330
        from master                         0  (_merge==1)
        from using                    264,330  (_merge==2)

    matched                        41,800,768  (_merge==3)
    -----------------------------------------
	

*/

// ALI - not working and i don't know why

* drop patients without any eczema treatments
* but first count how many
forvalues x=1/3 {
	display "*** _merge==`x' ***"
	unique patid if _merge==`x'
} // end forvalues x=1/3


/*
*** _merge==1 ***
Number of unique values of patid is  0
Number of records is  0
*** _merge==2 ***
Number of unique values of patid is  123662
Number of records is  123662
*** _merge==3 ***
Number of unique values of patid is  1055788
Number of records is  19217990

ALI (doesn't work with version 16)

*** _merge==1 ***
Number of unique values of patid is  0
Number of records is  0
*** _merge==2 ***
Number of unique values of patid is  264330
Number of records is  264330
*** _merge==3 ***
Number of unique values of patid is  2113877
Number of records is  41800768


*/

keep if _merge==3 // only keep individuals with both eczema Dx and Rx records ALI - (12,439 observations deleted)
drop _merge

unique patid // n=2113877 : n= 2114465 with Julian updated codelist

label var eventdate "date of eczema Rx record"

order patid eventdate src
sort patid eventdate









/*******************************************************************************
#3. Identify those with at least 2 therapy records on 2 separate days
	- definition needs one eczema diagnosis code and 2 codes (prodcode
	or Read code) for eczema therapy on different days
	- only keep the first 2 therapy records per patient
*******************************************************************************/
* only keep one record if there is more than one therapy record on the same day
duplicates drop patid eventdate, force // (1,454,258 observations deleted)
unique patid // n=118,269

* drop patients with therapy records on only one day
bysort patid: gen bigN=_N
summ bigN
drop if bigN==1
drop bigN
unique patid // n= 106,259

* keep first 2 Rx only
sort patid eventdate
by patid: gen littlen=_n
drop if littlen>=3

* each record currently represents an eczema therapy event
* make one record per patient
reshape wide eventdate src, i(patid) j (littlen)
rename eventdate1 eczema_Rx1
rename eventdate2 eczema_Rx2

* label variables
label var indexdate "earliest morbidity code diagnostic of eczema"
label var src1 "source of 1st therapy record"
label var src2 "source of 2nd therapy record"
label var eczema_Rx1 "date of 1st eczema therapy record"
label var eczema_Rx2 "date of 2nd eczema therapy record"

order patid index eczema_Rx1 src1 eczema_Rx2 src2






/*******************************************************************************
#4. Identify date individuals satisfy eczema diagnosis
	i.e. latest of Read/ICD-10 code or second eczema therapy
*******************************************************************************/
* create eczema diagnosis variable
* latest of Read code or second eczema therapy code
gen eczemadate=max(indexdate, eczema_Rx1, eczema_Rx2)
format eczemadate %td
label var eczemadate "latest of date of eczema Dx or second eczema Rx"
assert eczemadate!=. // OK


* label and save
label data "Eczema exposed (morbidity code + 2 Rxs)"
notes: Eczema exposed (morbidity code + 2 Rxs)
notes: NB: not necessarily eligible for FU (based on age, eligible FU, study dates)
notes: ${filename} / TS

sort patid 
compress
save "${pathOut}/eczemaExposed", replace



unique patid // 1787262








log close      
