/*=========================================================================
DO FILE NAME:	prog_getCodeHES

AUTHOR:					Kate Mansfield 
						(inspired by Krishnan Bhaskharan's smoking status prog)	
VERSION:				v1.0
DATE VERSION CREATED:	2015-Mar-12
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 14

DESCRIPTION OF FILE: 
	Identifies HES records recorded with a codes on a specified icd10 codelist.
	
HOW TO USE: e.g.
prog_getCodeHES, extractfile("${pathExtract}/HES/ppi-HES_diagnosis_epi") ///
		codelist("${pathCodelists}\icd10codes-ESRD") ///
		morbidity("ESRD") ///
		savefile("${pathOut}/ESRD-HES")

*=========================================================================*/


/*******************************************************************************
#1. Define program
*******************************************************************************/
capture program drop prog_getCodeHES
program define prog_getCodeHES

syntax, extractfile(string) codelist(string) morbidity(string) savefile(string)
	
* extractfile			// path and name of file containing HES extract file
* codelist				// string containing path and name of file containing morbidty codes
* morbidity				// string containing disease name to use for labelling the resulting dataset 
* savefile				// string containing name of file to save

noi di
noi di in yellow _dup(15) "*"
noi di in yellow "Identify secondary care records for icd-10 codes for `morbidity'"
noi di in yellow _dup(15) "*"


/*
local extractfile "${pathExtract}/HES/ppi-HES_diagnosis_epi"
local codelist "${pathCodelists}\icd10codes-GIbleed"
local morbidity "bleed"
local savefile "${pathOut}/GIbleed-HES"
*/

qui{
	/*******************************************************************************
	#2. Identify records for specified comorbidity from first clinical file and save 
		to append subsequent files to.
	*******************************************************************************/
	use "`extractfile'", clear
	merge m:1 icdcode using "`codelist'", nogen keep(match) force

	/*******************************************************************************
	#3. Add notes and labels to the data
	*******************************************************************************/
	notes drop _all
	notes: prog_getCodeHES.do / TS
	label data "`morbidity' records data from HES"
	save "`savefile'", replace


}/*end of quietly*/

end


