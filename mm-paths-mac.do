/*=========================================================================
DO FILE NAME:			mm-paths.do

AUTHOR:					Ali Henderson
VERSION:				v1
DATE VERSION CREATED: 	2020-Oct-18
						
DESCRIPTION OF FILE:	Global macros for file paths

*=========================================================================*/
* all files except data
*global pathWorking 	"C:/postdoc/eczema_extract"
global pathPosted "/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/"

/*******************************************************************************
# DO FILES
*******************************************************************************/
* posted dofiles
global pathPostDofiles	 	"/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/dofiles"
global pathPrograms			"/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/programs"

/*******************************************************************************
# DATASETS
*******************************************************************************/
global pathOut			"/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/out"				// derived data saved on J:drive
global pathIn			"/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/in"
global MMpathIn			"/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/in"
global pathCodelists 	"/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/codelists" // code lists
global pathLookUps 		"/Volumes/EPHSHARE2/shared/shared/EHR Share/3 Database guidelines and info/GPRD_Gold/Look up files/Lookups_2020_07"
global pathBrowsers		"/Volumes/EPHSHARE2/shared/shared/EHR Share/3 Database guidelines and info/GPRD_Gold/Medical & Product Browsers/2020_07_Browsers"
global pathDenom		"/Volumes/EPHSHARE2/shared/shared/EHR Share/3 Database guidelines and info/GPRD_Gold/Denominator files/JUL2020"
global pathLinkageEligibility "/Volumes/EPHSHARE2/shared/shared/EHR Share/3 Database guidelines and info/CPRD Linkage Source Data Files/Version19/set_19_Source_GOLD"
global pathCPRDflatfiles "/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Harriet/JUL2020/Data/STATA_files"

*global pathHES
*global pathONS

/******************************************************************************* 
# OUTPUT
*******************************************************************************/
* log files
global pathLogs "/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/output/logs"

* results text files
global pathResults "/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity/output/results"



* all linked datasets
global fileIMDpx "${pathLinked}/patient_imd2007_17_108_request3"
global fileIMDprac "${pathLinked}/practice_imd_17_108_request3"
global fileDeath "${pathLinked}/death_patient_17_108_request3"
global fileHESdxEpi "${pathLinked}/hes_diagnosis_epi_17_108_request3"
global fileHESepi "${pathLinked}/hes_episodes_17_108_request3"
global fileHESpx "${pathLinked}/hes_patient_17_108_request3"
global fileHESopcs "${pathLinked}/hes_procedures_epi_17_108_request3"



/*=========================================================================
prog_formatdate
DESCRIPTION:
	Formats a date string "dd/mm/yyyy" in Stata date format

HOW TO USE: e.g.
	prog_formatdate, datevar(nameofdatevar)
*=========================================================================*/
capture program drop prog_formatdate
program define prog_formatdate

syntax, datevar(string)
* datevar	// string containing name of variable to convert to Stata date format

qui{
	gen `datevar'2 = date(`datevar', "DMY")
	format `datevar'2 %td
	drop `datevar'
	rename `datevar'2 `datevar'
}/*end of quietly*/

end



/*=========================================================================
prog_appendFiles.do
DESCRIPTION: 
	Given the stem name of files and the number of files to append >> creates 
	one dataset
									
HOW TO USE: e.g.
prog_appendFiles, filename($pathDataExtract/Clinical_extract_aki2) ///
	filesnum(9) savefile($pathDataExtract/Clinical_extract_aki2_all)
*=========================================================================*/
cap prog drop prog_appendFiles
program define prog_appendFiles

syntax, filename(string) filesnum(string) savefile(string)
	
* filename			// path and stem name of files to append
* filesnum 			// number of files to append
* savefile			// dataset to save appended files

noi di
noi di in yellow _dup(5) "*"
noi di in yellow "Appending files"
noi di in yellow _dup(5) "*"


* Open files and append

qui{
noi display "appending file number 1 of `filesnum'"
use `filename'_1, clear
save `savefile'

if `filesnum'!=1 {
	forvalues n=2/`filesnum' {
		noi display "appending file number `n' of `filesnum'"
		use `filename'_`n', clear
		append using `savefile'
		compress
		save `savefile', replace
	} /*end forvalues n=2/`filesnum'*/
} /*end if `filesnum'!=1*/


}/*end of quietly*/

end



