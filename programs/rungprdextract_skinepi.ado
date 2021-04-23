*****************************EXTRACT****************************************

/*=========================================================================

AUTHOR:					Harriet & Krishnan
DATE: 					19th March 2012
VERSION:				STATA 11
DO FILE NAME:			rungprdextract.ado

STATUS:					In progress

GPRD VERSION(S) USED:	For use with GOLD flat file downloads

DATASETS USED: 			GPRD GOLD flat file download (Z:\ drive)
									
						        				

DO FILES NEEDED:		gprd.dlg, rungprddlg.ado (for user interface) dib.ado

DATASETS CREATED:		full set of GPRD extract files in your chosen directory

DESCRIPTION OF FILE:	EXTRACT TOOL

MORE INFORMATION:		This will process a patient list from previously run "Define", extract all GPRD data, and sort out dates/labels

=========================================================================*/

program define rungprdextract_skinepi

version 11
***************************************************************************
*   Number of practices in GPRD - UPDATE AT EACH 6monthly FLAT FILE UPDATE
local practot = ${npractices$gprdbuild}
*local practot = $npracticesJAN2012

*Sort orders for final files
local Additionalsort "patid adid enttype"
local Clinicalsort "patid eventdate medcode sysdate"
local Consultationsort "patid eventdate consid constype sysdate"
local Immunisationsort "patid eventdate medcode sysdate "
local Patientsort "patid" 
local Practicesort "pracid region lcd uts"
local Referralsort "patid eventdate sysdate "
local Staffsort "staffid "
local Testsort "patid eventdate medcode sysdate "
local Therapysort "patid eventdate prodcode issueseq sysdate "
***************************************************************************


qui{
clear
set more off

local timestart=c(current_time)


/********************************************************************************************
*1. Extract full patient data for patients in the defined patient list, practice by practice
*    ... and while doing so, process each file to label and convert dates etc...
********************************************************************************************/

noi dib "Extracting from `practot' practices:", stars

//local files Additional Clinical Consultation Immunisation Patient Referral Test Therapy 
local files Test 

foreach file of local files {
	noi dib "`file'"
	foreach i of numlist 1/`practot' {
		noi di "`i' " _cont
		clear
		cap use "$path_STATA/`file'`i'", clear
		if _rc!=0 & _rc!=601 exit _rc
		if _rc==0{ /*i.e. if practice number exists*/
			qui merge m:1 patid using "$gprdfiles/results_$studyname", keep(match) keepusing(patid) nogen
			if _N>0 save "$gprdfiles/`file'`i'", replace /*i.e. save a file for the practice if any patients matched in the merge*/
		}/*end of if _rc==0 */
	} /*end of loop for practices*/
local time_finishExt_`file' = c(current_time)
} /*end of loop for file types*/


/*************************************************************************************************
*2. Combine (append) by-practice files into smaller number of files (governed by memory available)
*************************************************************************************************/

noi dib "Appending practices:", stars


//local files Additional Clinical Consultation Immunisation Patient Referral Test Therapy 
local files  Clinical Consultation Immunisation Patient Referral Test 
foreach file of local files {
noi dib "`file'"

local startfile = 1
local splitnum = 1
local filenum = 1

while `filenum' <= `practot' {
	
	local memoryused = 0
	
	local fileexists=0
	while `fileexists'==0 & `filenum'<=`practot'{
	di `filenum', _continue
	cap use "$gprdfiles/`file'`filenum'", clear
	if _rc!=0 & _rc!=601 exit _rc
	if _rc==0 local fileexists=1
	local filenum = `filenum'+1
	}
	
	while `memoryused' < $gprd_memavail & `filenum'<=`practot'{
			cap append using "$gprdfiles/`file'`filenum'"
			if _rc!=0 & _rc!=601 exit _rc
			qui d
			local memoryused = ((r(width)+2*4)*_N)/1073741824
			local filenum = `filenum' + 1
			}	/*keeps going round unless been through all practices OR memory getting tight*/	
	
	if `fileexists'==1{
	sort ``file'sort'
	save "$gprdfiles/`file'_extract_${studyname}_`splitnum'", replace
	}
	
	local splitnum = `splitnum' + 1

} /*keeps going round until been through all practices*/
local time_finishAppend_`file' = c(current_time)
} /*end of loop for file type*/


*Erase by-practice files

noi dib "Appended practice files created; erasing individual extract practice files:", stars
//local files Additional Clinical Consultation Patient Referral Test Therapy Immunisation 
local files  Clinical Consultation Immunisation Patient Referral Test 
foreach file of local files {
noi dib "`file'"
forvalues i=1/`practot'  {
		cap erase "$gprdfiles/`file'`i'.dta"
		if _rc!=0 & _rc!=601 exit _rc
			}	
}

local time_finishErasing = c(current_time)
*******************************************************************************
*3. Produce a practice file for included practices only 
*******************************************************************************

*Practice File
noi dib "Generating a Practice.dta file with practice info for practices included in final dataset...", stars
use "$gprdfiles/results_$studyname" , clear
gen pracid=mod(patid,1000)
cap qui merge m:1 pracid using "$path_STATA/Practice", keep(match) nogen
if _rc!=0 qui merge m:1 pracid using "$path_STATA/Practice", keep(match) nogen
collapse (max) patid, by(pracid lcd uts region)
drop patid
save "$gprdfiles/Practice_extract_${studyname}_1", replace

} /*end of quietly*/

*CHECK N IN PATIENT FILE AGAINST N IN DEFINE FILE (because Ian had a random problem with these not matching once)
use "$gprdfiles/Patient_extract_${studyname}_1", clear
qui cou
local npatient = r(N)
use "$gprdfiles/results_$studyname", clear
qui cou
local ndefine = r(N)
cap assert `ndefine'==`npatient'
if _rc!=0{
cap confirm file "$gprdfiles/Patient_extract_${studyname}_2", clear
if _rc!=0{ /*i.e. in the unlikely event that the Patient file has been split (which would explain the difference), the following error will not show*/
	noi di in red _dup(30) "*"
	noi di in red "WARNING: Possible error - N in patient file not equal to N in define file"
	noi di in red "Please leave this Stata window open and contact Krishnan/Harriet"
	noi di in red _dup(30) "*"
}
}


local time_finishPracticefile = c(current_time)

cap log close
log using "$gprdfiles/timings", replace t
local col=45
noi di "Time of starting = " _col(`col') "`timestart'"
noi di "Time of finishing = " _col(`col') "`time_finishPracticefile'"
noi dib "", ul
//foreach file in Additional Clinical Consultation Patient Referral Test Therapy Immunisation{
foreach file in Clinical Consultation Immunisation Patient Referral Test{
noi di "Time finished extracting `file' = " _col(`col') "`time_finishExt_`file''"
}
noi dib "", ul
//foreach file in Additional Clinical Consultation Patient Referral Test Therapy Immunisation{
foreach file in Clinical Consultation Immunisation Patient Referral Test{
noi di "Time finished appending `file' = " _col(`col') "`time_finishAppend_`file''"
}
noi di 
noi di "Time finished erasing files = " _col(`col') "`time_finishErasing'"
noi di
noi di "Time finished creating practice file = " _col(`col') "`time_finishPracticefile'"
log close

*AUDIT TRAIL
local date:display %td_CCYY_NN_DD date(c(current_date), "DMY")
local time = subinstr(c(current_time), ":", "", 5)
*Save patid list:
use "$gprdfiles/results_$studyname", clear
*save "J:\EHR-Working\CPRDFaSTAudit\\`date'`time'_`c(username)'_patid_list_$studyname", replace
save "J:\EHR-Working\Helena\log\\`date'_`time'_`c(username)'_patid_list_$studyname", replace

**Save summary of timings: this provides location of the study files
cap log close
qui file open file6 using "timings.log", read
*log using "J:\EHR-Working\CPRDFaSTAudit\\`date'`time'_`c(username)'_extracttimings_$studyname", replace
log using "J:\EHR-Working\Helena\log\\`date'_`time'_`c(username)'_extracttimings_$studyname", replace
qui file read file6 line
qui while r(eof)==0 {
	noi display "`line'"
	file read file6 line
}

log close	



end 

