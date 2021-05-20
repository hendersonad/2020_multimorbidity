/*=========================================================================
DO FILE NAME:			ecz-extract-02eczemaTherapy.do

AUTHOR:					Ali Henderson	
						Adapted from HF CVD eczema study code: 
							1_identify_all_eczema_patients
						
VERSION:				v1
DATE VERSION CREATED: 	v1 2020-10-28
					
DATABASE:				CPRD July 2020 build
						HES version ??
	
DESCRIPTION OF FILE:	Extract eczema therapy data from both clinical and
						therapy files
						
MORE INFORMATION:	Will use these data to establish whether individuals are
					eczema cases in a subsequent do file.
					To be an eczema case individuals must have a morbidity code
					for eczema and two therapy codes (recorded as Read or Therapy
					code) recorded on two separate days.
	
DATASETS USED:		medcodes-eczemaRx		// medcode list for eczema therapies
					prodcodes-eczemaRx		// prodcode list for eczema treatment 
					`file'_extract_exca2_linked_`x' 	// extract files
												// where `file' is Clinical or Therapy
												// and will also look in Referral
												// but not Test and Immunisation

DATASETS CREATED: 	common_dosages	// common dosages file for July 2017 build
					packtype		// packtype file for July 2017 build
					cprd-Clinical-eczemaRx // records for eczema therapy from Clinical extract file
					cprd-Referral-eczemaRx // records for eczema therapy from Referral extract file
					prescriptions-exzemaRx-`x'	// records for prescriptions for eczema treatments
												// where `x' is 1 to 3 (corresponding to 3 Therapy extract files)
																
DO FILES NEEDED:	exca-paths.do
					prog_identifyTherapy.do // goes through therapy extract files and extracts prescriptions given a 
											// prodcode list - creates a file per therapy extract file
					prog_getCodeCPRD	// goes through cprd extract files and extracts records
										// given a medcode list - creates only one file

ADO FILES NEEDED: 	exca.ado

*=========================================================================*/

/*******************************************************************************
>> HOUSEKEEPING
*******************************************************************************/
version 15
clear all
capture log close

* find path file location and run it
mm_extract , computer(mac) 

* create a filename global that can be used throughout the file
global filename "ecz-extract-02eczemaTherapy"

* run program file that will be used to identify prescriptions from the 
* therapy extract and consultations from clinical extract file
cd "$pathPrograms"
run prog_identifyTherapy.do
run prog_getCodeCPRD

* open log file - no need as fast tool will create log files
log using "${pathLogs}/${filename}", text replace





/*******************************************************************************
1. Import common dosages and packtype look up files to stata format
*******************************************************************************/
* COMMON DOSAGES
insheet using "${pathLookUps}/common_dosages.txt", clear
// (11 vars, 73,068 obs)

* label variables
label var dosageid "id allowing freetext for events with textid<100,000 to be retrieved"
label var dosage_text "textual dose associated with the therapy textid"
label var daily_dose "Numerical equivalent of text dose given in a per day format"
label var dose_number "Amount in each dose"
label var dose_unit "Unit of each dose"
label var dose_frequency "How often a dose is taken in a day"
label var dose_interval "Num days dose is over eg 1 every 2 weeks=14, 4/day = 0.25"
label var choice_of_dose "Indicates if there is a choice the user can make re:how much to take"
label var dose_max_average "2=dose averaged, 1=max taken, 0=otherwise"
label var change_dose "If option btwn 2 parts of dose available, indicates the part used"
label var dose_duration "If specified, the num days the prescription is for"

* label data and save
label data "common dosages look up file from July 2020 CPRD build"
notes: $filename / TS
notes: July 2020 lookups
compress

save "${pathOut}/common_dosages", replace


* PACKTYPE
insheet using "${pathLookUps}/packtype.txt", clear
// (2 vars, 87,233 obs)

* label variables
label var packtype "Coded value assoc with pack size/type"
label var packtype_desc "Pack size or type of the prescribed product"

* label data and save
label data "packtype look up file from July 2020 CPRD build"
notes: $filename / TS
notes: July 2020 lookups
compress

save "${pathOut}/packtype", replace


/*******************************************************************************
#2. Identify eczema treatment from Therapy files
*******************d************************************************************/
prog_identifyTherapy, ///
	therapyfile("${pathIn}/Therapy_extract_ecz_extract") /// path and file name (minus _filenum) of extract file
	codelist("${pathCodelists}/prodcodes-eczemaRx") ///	path and file name for prodcode list - some 1527 codes in this one
	filenum(15) ///	number of extract files
	dofilename($filename) /// name of this do file to include in the saved file notes
	savefile("${pathOut}/prescriptions-eczemaRx")	// name of file to save eczema therapy prescription data to

	
	

/*******************************************************************************
#3. Identify eczema treatment from Clinical and Referral files
*******************************************************************************/

// lookiong for eczema phtootherapy that might be in clinical/referral 

// might be missing a bunch of phototherapy currently 


foreach filetype in Clinical Referral {
	if "`filetype'"=="Clinical" {
		local nfiles=1   // update nfiles
	}
	if "`filetype'"=="Referral" {
		local nfiles=1 // update nfiles  -- usually only one 
	} 
	prog_getCodeCPRD, clinicalfile("${pathIn}/`filetype'_extract_ecz_extract") ///
		clinicalfilesnum(`nfiles') ///
		codelist("${pathCodelists}/medcodes-eczemaRx") /// 
		diagnosis(eczemaRx) ///
		savefile("${pathOut}/cprd-`filetype'-eczemaRx")
} /*end foreach file in Clinical Referral*/

log close
