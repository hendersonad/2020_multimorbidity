/*=========================================================================
DO FILE NAME:	prog_getSmokingStatus
					(KB file: pr_getsmokingstatus.do)

AUTHOR:					Krishnan Bhaskharan - edited by KateMansfield		
VERSION:				v1
DATE VERSION CREATED:	2018-Feb-08
					
DATABASE:				CPRD July 2017 build
						CPRD-HES version 14

DESCRIPTION OF FILE: 
	Adds smoking status to a file containing patid and index date						
									
DO FILES NEEDED:	aki2-pathsv2.do
ADO FILES NEEDED: 	aki2.ado

HOW TO USE: e.g.
prog_getSmokingStatus, indexdatefile($pathDataDerived/cases-eligible) ///
	clinicalfile($pathDataExtract/Clinical_extract_aki2_all) ///
	additionalfile($pathDataExtract/Additional_extract_aki2_all) ///
	smokingcodelist($pathCodelistsPosted/medcodes-smoking-aki2) ///
	smokingstatusvar(smokstatus) ///
	index(indexdate) ///
	savefile ($pathDataDerived/cases-smokingstatus)
	
	

*=========================================================================*/


/*******************************************************************************
#1. Define program
*******************************************************************************/
cap prog drop prog_getSmokingStatus
program define prog_getSmokingStatus

syntax, clinicalfile(string) ///
	clinicalfilesnum(integer) ///
	additionalfile(string) ///
	additionalfilesnum(integer)	/// 
	smokingcodelist(string) smokingstatusvar(string) ///
	savefile(string)
	
* clinicalfile			// path and name of file containing clinical extract files
* clinicalfilesnum		// number of clinical extract files
* additionalfile		// path and name of file containing additional extract files
* additionalfilesnum	// number of additional files
* smokingcodelist		// string containing path and name of file containing smoking codes
* smokingstatusvar		// the name of the variable containing smoking status in the smoking code list
* savefile				// the path and name of the file to save the dataset created to



qui{



/*******************************************************************************
#2. PICK UP SMOKING INFO FROM ADDITIONAL FILE, for later
*******************************************************************************/
* declare tempfile
tempfile additionalsmokingdata

* loop through additional files 
* keep enttype 4 data only
forvalues n=1/`additionalfilesnum' {
	use `additionalfile'_`n', clear
	noi di	"addtional file `n'"
	
	keep if enttype==4
	rename data1 status
	rename data2 cigsperday
	drop data*
	keep patid adid status 
	drop if status==.|status==0
	recode status 1=1 2=0 3=2 /*to match the smokstatus variable in clinical codelist*/
	label define statuslab 0 No 1 Yes 2 Ex
	label values status statuslab
	
	if `n'==1 save `additionalsmokingdata'
	if `n'>1 {
		append using `additionalsmokingdata'
		save `additionalsmokingdata', replace
	} /* end if*/
} /*end loop through additional files*/





/*******************************************************************************
#3. GET SMOKING STATUS FROM CODES, AND SUPPLEMENT WITH INFO FROM ADDITIONAL 
	RETRIEVED ABOVE
*******************************************************************************/
* declare tempfile
tempfile clinicalsmokingdata

* first from the first clinical file
forvalues n=1/`clinicalfilesnum' {
	use `clinicalfile'_`n', clear
	noi di	"clinical file `n'"

	keep patid eventdate medcode adid
	
	* identify records for smoking codes by merging with codelist
	* only keep records for codes on the codelist
	merge m:1 medcode using "`smokingcodelist'", keepusing(`smokingstatusvar') keep(match master)
	noi di _cont "."
	drop medcode
	rename _merge smokingdatamatched // create a var to identify those with smoking status available
	
	* merge in data from additional file (from #2 above)
	* merged on adid + patid vars
	* will use status variable in this file to update missing smoking status
	* from clinical data
	replace adid = -_n if adid==0 /*this is just to avoid the "patid adid do not uniquely identify observations in the master data" error which is caused by all the adid=0s */
	merge 1:1 patid adid using `additionalsmokingdata', keep(match master)
	noi di _cont "."
	drop adid

	* update the flag that identifies whether an individual has smoking status 
	* available from either additional data or based on clinical coding
	replace smokingdatamatched=3 if _merge==3 
	drop _merge

	* use the additional data to update the smoking status variable if it is missing
	replace `smokingstatusvar'=status if `smokingstatusvar'==.
	drop status // status var from additional dataset no longer needed
	
	* now get rid of those with no smoking data available
	keep if smokingdatamatched==3 // only keep records where smoking status data is available
	drop smokingdatamatched
	
	* save or append+save if not first go through the loop
	if `n'==1 save `clinicalsmokingdata'
	if `n'>1 {
		append using `clinicalsmokingdata'
		save `clinicalsmokingdata', replace
	} /* end if*/
} /*end forvalues n=1/`clinicalfilesnum'*/







/*******************************************************************************
#4. SAVE DATASET
*******************************************************************************/
sort patid eventdate
compress
label data "smoking status"
notes: smoking status

save `savefile', replace



}/*end of quietly*/









end










/*
remove this code from this file as there are multiple different index dates 
in this study - therefore need to run this bit of code multiple times for each
index date.
Will run the code above to extract 

/*******************************************************************************
#4. ASSIGN STATUS BASED ON ALGORITHM
*******************************************************************************/
*Algorithm:
*Take the nearest status in the period -1y to +1month from index if available (best)
*if not, then take nearest in the period +1month to +1y after index if available(second best)*
*if not, then take any nearest before -1y from index if available (third best)
*if not, then take nearest after +1y from index (least best)

gen _distance = eventdate-`index'
gen priority = 1 if _distance>=-365 & _distance<=30
replace priority = 2 if _distance>30 & _distance<=365
replace priority = 3 if _distance<-365
replace priority = 4 if _distance>365 & _distance<.
gen _absdistance = abs(_distance)
gen _nonspecific = (`smokingstatusvar'==12)

sort patid priority _absdistance _nonspecific

*Patients nearest status is non-smoker, but have history of smoking, recode to ex-smoker.
by patid: gen b4=1 if eventdate<=eventdate[1]
drop if b4==.
by patid: egen ever_smok=sum(`smokingstatusvar') 
by patid: replace `smokingstatusvar' = 2 if ever_smok>0 & `smokingstatusvar'==0

gsort patid -eventdate _nonspecific
by patid: replace `smokingstatusvar' = `smokingstatusvar'[1] 
drop smokingdatamatched _nonspecific  
by patid: keep if _n==1

label define priority 1"1 [-365, +30]" 2"2 [+30, +365]" 3"3 [-inf, -365]" 4"4 [+365, +inf]"
label values priority priority
label var priority "distance of status from index"

drop b4 ever_smok _absdistance _distance






/*******************************************************************************
#5. ADD NOTES AND SAVE
*******************************************************************************/
label data "nearest smoking status to index date"
notes: prog_getSmokingStatus.do / TS
notes: nearest smoking status to index date
notes: smoking status (from either clinical codes, or additional file)
notes: based on nearest status to index date in the range:
notes: (BEST) [-365, +30] from index
notes: (2ND BEST) (+30, +365] from index
notes: (3RD BEST) (-inf,-30) from index
notes: (4TH BEST) (+365, +inf) from index


*/



