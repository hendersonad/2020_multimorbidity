/*=========================================================================
DO FILE NAME:			ecz-extract-01eczema.do

AUTHOR:					Kate Mansfield	
						Adapted from HF CVD eczema study code: 
							1_identify_all_eczema_patients
						
VERSION:				v2
DATE VERSION CREATED: 	v2 2018-Jan-08	// edited to add in individuals identified from HES 
						v1 2017-Nov-08
					
DATABASE:				CPRD July 2017 build
						HES version 14
	
DESCRIPTION OF FILE:	Aim is to identify eczema exposed patients
						Eczema exposed defined using a combination of Read 
						morbidity coding, primary care prescription data, and 
						ICD-10 coding in HES.
						This file identifies and extracts data for ALL individuals
						with a primary care morbidity code for eczema.
						
MORE INFORMATION:	
	Runs as follows:
		1. Uses CPRD Fast tool (define) to identify patients with a Read code for 
			eczema.
		2. Combines these patients with individuals with a ICD-10 record for eczema
			in HES (identified as having an eczema code ever in HES by CPRD).
		3. Extract data for all those with either a primary or secondary care 
			morbidity code for eczema.
	I note	from one of Harriet's files that all the individuals she IDd 
	from HES records also had a CPRD record for eczema.
	However, I also note that she only included as potential cases those with
	an eczema code recorded in the primary diagnostic position.
	This is not appropriate for this study - need to ID anyone who has ever had
	a morbidity code for eczema recorded at any time in either HES or CPRD.
					
DATASETS USED:		medcodes-eczemaDx		// medcode list for eczema - NB: used 
											// code list from HF, but checked to make sure OK
											// by searching in Read code browser
DATASETS CREATED: 	CPRD extract files 	// ecxa1 (all those with an eczema code)
										// exca2_linked (eczema ICD/Read code and eligible for HES linkage)
					patients	// dataset of patids and dates for patients
								// who are eligible for linkage who have a 
								// CPRD/HES record for eczema
					
					All_patids_allcodes // insheet of patids and first Dx dates of individuals 
										// with eczema Dx in HES ever from CPRD
									
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
global filename "exca-extract01v2-eczema"

* open log file - no need as fast tool will create log files
log using "${pathLogs}/${filename}", text replace

/*******************************************************************************
#1. Identify list of patients with Read code for eczema
	using CPRD Fast define tool
*******************************************************************************/
/* run in first version of this file exca-extract01v2-eczema no need to run again */

/*
rungprddlg, define(1) extract(0) build(July 2017) ///
	directory(${pathIn}) studyname(ecz_extract) memorytoassign(8g) /// where to save output, what to call it and file size
	ssta(01jan2006) send(01jan2007) /// testing - 1 year only
	gend(Male & Female) minagetype(No restriction) maxagetype(No restriction) /// no sex/age restriction
	priorregtype(No restriction) fuptype(No restriction) /// no min prior registration or length of follow up
	inc1filename(${pathCodelists}/medcodes-eczemaDx) inc1codevar(medcode) /// file and variable containing code list (eczemaDx has approx 10 codes)
	inc1R1(1) inc1R2(0) /// medcodes (not prodcodes)
	inc1searchclin(1) inc1searchtest(1) inc1searchimm(1) inc1searchref(1) /// search clinical, test, immunisation and referral files for codes
	inc1inreg(0) inc1crittype(Any in study period) /// no need for event to be in registration period, looking for any record during study period
	inc1addsecond(0) // do not include a second inclusion criterion
*/


rungprddlg, define(1) extract(0) build(July 2020) ///
	directory(${pathIn}) ///
	studyname(mm_extract_eczema) memorytoassign(8g) ///
	ssta(01jan1900) send(01jan2100) gend(Male & Female) ///
	minagetype(No restriction) maxagetype(No restriction) ///
	priorregtype(No restriction) fuptype(No restriction) ///
	inc1filename(J:\EHR-Working\Ali\eczema_extract\posted\codelists\medcodes-eczemaDx) ///
	inc1codevar(medcode) inc1R1(1) inc1R2(0) inc1searchclin(1) ///
	inc1searchtest(1) inc1searchimm(1) inc1searchref(1) inc1inreg(0) ///
	inc1crittype(Any in study period) inc1addsecond(0)

	
	
	
/*
/*******************************************************************************
#2.  Add in patients identified from HES 
	(provided by CPRD)
*******************************************************************************/
* insheet text file from CPRD including patids and date of first eczema Dx
* in HES of individuals with a ICD-10 eczema code ever
insheet using ${pathIn}/All_patids_allcodes.txt, clear // Provided by CPRD?? 44,701 rows of data
prog_formatdate, datevar(epistart)

label data "patids of pxs with eczema ICD-10 code ever"
notes: patids of pxs with eczema ICD-10 code ever
notes: $filename / TS
compress

save ${pathIn}/All_patids_allcodes, replace

* merge with individuals identified with an eczema code recorded in CPRD
merge 1:1 patid using ${pathIn}/results_ecz_extract

/*

    Result                           # of obs.
    -----------------------------------------
    not matched                       193,655
        from master                    40,895  (_merge==1)
        from using                    152,760  (_merge==2)

    matched                             3,806  (_merge==3)
    -----------------------------------------
	
	
	Full cohort - multimorbidity
	    not matched                     1,144,607
        from master                    26,332  (_merge==1)
        from using                  1,118,275  (_merge==2)

    matched                            18,369  (_merge==3)

*/

* identify if there is anyone with earliest HES date before earliest CPRD date
* for interest not necessary for any other reason
gen HESbeforeCPRD=1 if epistart<indexdate & _merge==3 // 1,157,082 missing values generated
tab HESbeforeCPRD if _merge==3, miss 
	
/*
HESbeforeCP |
         RD |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      3,794       14.04       14.04 // n=3,794 with both HES and CPRD code for eczema where HES code before CPRD code
          . |     23,238       85.96      100.00
------------+-----------------------------------
      Total |     27,032      100.00
	  
	 
Ecz_extract version

HESbeforeCP |
         RD |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      5,894       32.09       32.09
          . |     12,475       67.91      100.00
------------+-----------------------------------
      Total |      3,806      100.00

*/
	
drop _merge HESbeforeCPRD

* label vars
label var epistart "NULL 2020 -  date of earliest ICD-10 record"
label var indexdate "NULL 2020 - date of earliest CPRD record"


	

	
	
/*******************************************************************************
#3. Restrict to those eligible for HES/ONS linkage
	and have CPRD accepatble flag==1
	
	2020 edit 1 - don't do this bit for multimorbidity and eczema cluster cohorts. Don't need HES linkage 
*******************************************************************************/
* merge in linkage eligibility data

// ALI: not sure where linkage_eligibility comes from? Code before this? 
merge 1:1 patid using "${pathLinkageEligibility}/linkage_eligibility", gen(matchLinkage) 
// ALI:  610,749 of 1.1mil matched only
drop if matchLinkage == 2 //remove if only in linkage eligibility 

* merge in registration data
merge 1:1 patid using "${pathDenom}\allpatients_JUL2020.dta", gen(matchMaster) 
// ALI: 1.1mil matched. 16 not
drop if matchMaster == 2 // remove if only in denom file (20mil)

* keep eligible patients only - ALI not anymore! 
count if hes_e==1 & death_e==1
// ALI: 610 obs of 1.15 mil are eligible 

* format dates
foreach date in frd crd tod deathdate linkdate {
	prog_formatdate, datevar(`date')
} /*end foreach date in frd crd tod deathdate linkdate*/

* save
sort patid
label data "linked patients with CPRD/HES eczema record"
notes: linked patients with CPRD/HES eczema record
notes: ${filename} / TS
compress

save ${pathOut}/patients, replace

* also save a smaller copy with just patid and indexdate in order to 
* extract data
* update indexdate to be earliest morbidity code recorded
egen indexdate_new=rowmin(epistart indexdate)
format indexdate_new %td
drop indexdate
rename indexdate_new indexdate
label var indexdate "earliest HES/CPRD eczema morbidity code"

keep patid indexdate
save ${pathIn}/results_ecz_extract_linked, replace

cap log close // CPRD data extract will create it's own log file

/*******************************************************************************
#4.	Extract CPRD data
*******************************************************************************/
*/


rungprddlg, define(0) extract(1) build(July 2020) directory(${pathIn}) ///
	studyname(mm_extract_eczema) memorytoassign(4g)


/*
Total number of patients with data extracted:
1. using CPRD morbidity coding only 				1,161,781 	(exca2)
2. using both CPRD and HES eczema morbidity coding	1,179,450	(exca2_linked)

*/











