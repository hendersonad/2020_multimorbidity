/*=========================================================================
DO FILE NAME:	prog_getCodeCPRD

AUTHOR:					Kate Mansfield 
						(inspired by Krishnan Bhaskharan's smoking status prog)	
VERSION:				v1.0
DATE VERSION CREATED:	2015-Nov-26
					
DATABASE:				CPRD July 2014 build
						CPRD-HES version 10: 1/04/1997 to 31/3/2014

DESCRIPTION OF FILE: 
	Identifies clinical records recorded with a codes on a specified codelist
		from a CPRD extract.						
									
DO FILES NEEDED:	aki2-pathsv2.do

HOW TO USE: e.g.
prog_getCodeCPRD, clinicalfile("${pathExtract}/Clinical_extract_ppi") ///
	clinicalfilesnum(16) ///
	codelist("${pathCodelists}/medcodes-DM") /// 
	diagnosis(diabetes) ///
	savefile("${pathOut}/diabetes")
	
*=========================================================================*/


/*******************************************************************************
#1. Define program
*******************************************************************************/
capture program drop prog_getCodeCPRD
program define prog_getCodeCPRD

syntax, clinicalfile(string) clinicalfilesnum(integer) codelist(string) diagnosis(string) ///
	savefile(string)
	
* clinicalfile			// path and name of file containing clinical extract files
* clinicalfilesnum 		// number of clinical files to loop through
* codelist				// string containing path and name of file containing morbidty codes
* diagnosis				// string containing diagnosis name to use for labelling the resulting dataset 
* savefile				// string containing file name of file to save results


noi di
noi di in yellow _dup(15) "*"
noi di in yellow "Identify primary care records for morbidity codes for `diagnosis'"
noi di in yellow _dup(15) "*"


qui{
	/*******************************************************************************
	#2. Identify records for specified diagnosis from first clinical file and save 
		to append subsequent files to.
	*******************************************************************************/
	use "`clinicalfile'_1", clear
	merge m:1 medcode using "`codelist'", nogen keep(match) force
	save "`savefile'", replace

	display in red "*******************clinical file number: 1*******************"

	/*******************************************************************************
	#3. Loop through subsequent (from 2 onwards) separate clinical extract files in 
		turn and append the results to the first extract file saved in #1
	*******************************************************************************/
	if `clinicalfilesnum'>1 {
		forvalues n=2/`clinicalfilesnum' {
			display in red "*******************clinical file number: `n'*******************"

			use "`clinicalfile'_`n'", clear
			merge m:1 medcode using "`codelist'", nogen keep(match) force
			
			* add the file containing records for the specified diagnosis
			* to make one file containing all specified comorbidiy records for the
			* clinical extract specified
			append using "`savefile'"
			
			* save
			compress
			save "`savefile'", replace
		}
	} /*end if `clinicalfilesnum'!=1*/
	
	/*******************************************************************************
	#4. Add notes and labels to the data
	*******************************************************************************/	
	notes: prog_getCodeCPRD.do / TS
	label data "`diagnosis' clinical records data from CPRD"
	compress
	save "`savefile'", replace

}/*end of quietly*/

end


