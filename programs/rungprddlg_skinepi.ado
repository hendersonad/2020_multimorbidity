/*=========================================================================

AUTHOR:					Krishnan 
DATE: 					16th March 2012
VERSION:				STATA 11
DO FILE NAME:			rungprddlg.ado

STATUS:					In progress

	TO DO 
	*****
	****need to make sure all use/save are in quotes in case spaces in path (in H programs)
	****uncomment out the macro tidy up
	****define, extract, process to ado files, and replace the displays with calls to those files
	****if we put these in j share, then instruct people to adopath + would save distributing

GPRD VERSION(S) USED:	For use with GOLD flat file downloads

DATASETS USED: 			GPRD GOLD flat file download (Z:\ drive)
									        				
ADO FILES NEEDED:		define, extract, plus gprd.dlg

DATASETS CREATED:		patient list/full extract/processed files (as specified by user)

DESCRIPTION OF FILE:	PROCESS DIALOG BOX INPUTS AND RUN DEFINE/EXTRACT PROGRAMS AS NECESSARY 

=========================================================================*/

program define rungprddlg_skinepi

version 11

		syntax , directory(string) studyname(string) memorytoassign(string) build(string) ///
		[ define(integer -1) extract(integer -1) ///
		ssta(string) send(string) gend(string) ///
		minagetype(string) minage(integer -1) maxagetype(string) maxage(integer -1) ///
		priorregtype(string) priorreg(integer -1) fuptype(string) fup(integer -1) ///
 		inc1filename(string) inc1codevar(string) inc1R1(integer -1) inc1R2(integer -1) ///
		inc1searchclin(integer -1) inc1searchimm(integer -1) inc1searchref(integer -1) inc1searchtest(integer -1) ///
		inc1inreg(integer -1) inc1crittype(string) ///
		inc1addsecond(integer -1) ///
		inc2filename(string) inc2codevar(string) inc2R1(integer -1) inc2R2(integer -1) ///
		inc2searchclin(integer -1) inc2searchimm(integer -1) inc2searchref(integer -1) inc2searchtest(integer -1) ///
		inc2inreg(integer -1) inc2crittype(string) ///
		inc2combinelogic(string) dontwarn ]
			

set more off

qui{

			
		*Clear global macro list
		foreach gmac in gprdfiles studyname studystartdate studyenddate gender minage maxage ///
			priorreg followup inc1codelist inc1search inc1inregperiod inc1conditiontiming ///
			inc2codelist inc2search inc2inregperiod inc2conditiontiming inc2combine gprd_memavail {
		global `gmac'
		}
			
			
		*Directory: remove the last slash if they added it
		if substr("`directory'", length("`directory'"), 1)=="\"|substr("`directory'", length("`directory'"), 1)=="/" local directory = substr("`directory'", 1, length("`directory'")-1)
		
if "`dontwarn'"==""{
		*Warn then set memory
		noi di
		noi di in green "***********************************************"
		noi di in green "Warning, current data in memory will be erased!"
		noi di in green "***********************************************"
		noi di 
		noi di "Press y (then return) to confirm or anything else to quit" _request(keyentry)
		if "$keyentry"!="y" error 1
		}


		clear
		set memory `memorytoassign'
		if substr("`memorytoassign'", length("`memorytoassign'"),1)=="g" local mem_mult=1073741824
		if substr("`memorytoassign'", length("`memorytoassign'"),1)=="m" local mem_mult=1048576
		global gprd_memavail = 0.85*(real(substr("`memorytoassign'", 1, length("`memorytoassign'")-1))*`mem_mult')/1073741824

		
		*******************************************************
		*ERROR CHECKING FOR DEFINE, AND SET UP CODELISTS AS SINGLE VAR FILES WITH STANDARD VARNAMES
		*******************************************************
		cap cd z:
		if _rc==170{
		noi di in red "Cannot access the Z:\ drive - are you logged into it?"
		exit _rc
		}
		
		*Check directory exists and if not (for define only) offer to create it 
		cap cd "`directory'"
		if _rc==170 & `define'==1{
		noi di in green "The directory you specified does not exist: create it? Enter y to confirm, anything else to quit" _request(keyentry)
		if "$keyentry"!="y" error 1
		if "$keyentry"=="y" {
			parse "`directory'", p(\/)
			cap assert substr("`directory'",2,1)==":"
			local colon_err=_rc
			cap assert strpos("`directory'", "/")>0|strpos("`directory'", "\")>0
			if _rc==9|`colon_err'==9{
				noi di in red "File path invalid, it must be of the form driveletter:/directory/subdirectory etc"
				exit 198
				} /*of if file path error*/
			local sofar `1'
			cd `1'
			local i=3
			while `i' !=-1 {
			local sofar `sofar'/``i''
			if "``i''"!="" {
				cap cd "`sofar'"
				if _rc==170 mkdir "`sofar'"
				local i=`i'+2
				}/*of if a further subdir exists*/ 
			if "``i''"=="" local i = -1
			}/*of while loop to make directories*/
			} /*of if keyentry==y*/
		} /*of if directory error and define==1 */
		
		if _rc==170 & `define'!=1{
		noi di in red "The directory you specified does not exist"
		exit _rc
		}
		
		if `define'==1{
		*Report an error if study start/end not given
		cap assert d(`ssta')!=. & d(`send')!=.
		if _rc!=0{
			noi di in red "Valid study start and end dates must be given"
			noi di in red "For no restriction simply enter very early and late dates (e.g. 01jan1900 to 31dec2100)"
			error 198
			}
				
		*Report an error if min age, max age, prior reg, fup  menu indicate restriction but no yrs/mths filled in
		cap assert ("`minagetype'"=="No restriction") + ("`minage'"!="-1") == 1 
		local ageerror = _rc
		cap assert ("`maxagetype'"=="No restriction") + ("`maxage'"!="-1") == 1 
		local ageerror = max(_rc, `ageerror')
		if `ageerror'!=0 { 
			noi di in red "You specified an age restriction without giving the ages or vice versa"
			error 198
			}
		cap assert ("`priorregtype'"=="No restriction") + ("`priorreg'"!="-1") == 1 
		local regfuperror = _rc
		cap assert ("`fuptype'"=="No restriction") + ("`fup'"!="-1") == 1 
		local regfuperror = max(_rc, `regfuperror')
		if `regfuperror'!=0 { 
			noi di in red "You specified a prior registration of follow-up restriction without giving the months or vice versa"
			error 198
			}
			
		*Report an error if inclusion criteria 1 codelist/varname not given
		cap assert "`inc1filename'"!="" & "`inc1codevar'"!=""
		if _rc!=0{
			noi di in red "You must give a codelist file and specify the code variable for inclusion criteria 1"
			error 198
			}
			
		*Report an error if no files to search for inclusion criteria 1 
		if `inc1R1'==1 cap assert `inc1searchclin'+`inc1searchimm'+`inc1searchtest'+`inc1searchref'>=1
		if _rc!=0{
			noi di in red "No files specified to search in inclusion criteria 1!"
			error 198
		}
		
		use "`inc1filename'", clear
		keep `inc1codevar'
		destring `inc1codevar', replace
		if `inc1R1'==1 {
		cap rename `inc1codevar' medcode
			if _rc!=0 & _rc!=110{
			exit _rc
			}
		}
		if `inc1R2'==1 {
		cap rename `inc1codevar' prodcode
			if _rc!=0 & _rc!=110{
			exit _rc
			}
		}
		save "`directory'/_INC1CODES", replace
		global inc1filenameORIGINAL "`inc1filename'"
		local inc1filename `directory'/_INC1CODES.dta				
		
		if `inc1addsecond'==1{
			*Report an error if inclusion 2 ticked but no codelist given  
			cap assert "`inc2filename'"!="" & "`inc2codevar'"!=""
			if _rc!=0{
				noi di in red "You requested a second inclusion criteria but didn't provide a codelist or specify the code variable"
				error 198
				}
			
			*Report an error if inclusion 2 ticked but no files to search 
			if `inc2R1'==1 cap assert `inc2searchclin'+`inc2searchimm'+`inc2searchtest'+`inc2searchref'>=1
			if _rc!=0{
				noi di in red "No files specified to search in inclusion criteria 2!"
				error 198
				}
		use "`inc2filename'", clear
		keep `inc2codevar'
		destring `inc2codevar', replace
		if `inc2R1'==1 {
		cap rename `inc2codevar' medcode
			if _rc!=0 & _rc!=110{
			exit _rc
			}
		}
		if `inc2R2'==1 {
		cap rename `inc2codevar' prodcode
			if _rc!=0 & _rc!=110{
			exit _rc
			}
		}
		save "`directory'/_INC2CODES", replace
		global inc2filenameORIGINAL "`inc2filename'"
		local inc2filename `directory'/_INC2CODES.dta		
		}		/*of if second inc*/
		
		}		/*of if define*/
		
		if `define'==0 & `extract'==1{
		*Check the results file is as expected
		cap use `directory'/results_`studyname', clear
		if _rc==601{
		noi di in red "Cannot find the expected patient list file from the Define:
		noi di in red "`directory'\results_`studyname'.dta"
		noi di in red "...should be in the specified directory"
		exit 198
		}
		/*cap d patid 
		if _rc==111{
		noi di in red "Cannot find patid variable in the results_`studyname'.dta file"
		exit 198		
		}*/
		}
		
		*******************************************************
		
		**********************************************************
		*SET UP ALL THE GLOBALS TO FEED INTO DEFINE CODE
		**********************************************************

************************************************************************************************

*Add a new macro to this list for each build we get - the n should be the MAXIMUM PRACTICE ID (not necessarily = the actual number of practices)
		global npracticesJAN2012 = 642
		global npracticesJUL2012 = 647
		global npracticesJAN2013 = 663
		global npracticesAUG2013 = 681
		global npracticesJAN2014 = 684
		global npracticesJUL2014 = 688
		global npracticesJAN2015 = 688
		global npracticesJUL2015 = 694
		global npracticesJAN2016 = 696
		global npracticesJUL2016 = 707
		global npracticesJAN2017 = 720
		global npracticesJUL2017 = 725
		global npracticesJAN2018 = 734
		global npracticesJUL2018 = 745
		global npracticesJAN2019 = 769
		global npracticesJUL2019 = 836
		global npracticesJAN2020 = 897
		global npracticesJUL2020 = 937
		global npracticesJAN2021 = 962

************************************************************************************************		
************************************************************************************************

		
		global gprdbuild = upper(substr("`build'", 1, 3)) + substr("`build'", strpos("`build'"," ")+1, 4) 
		*Note the above just turns e.g. January 2012 into JAN2012
		global path_STATA "Z:\GPRD_GOLD\Harriet/$gprdbuild\Data\STATA_files"
				
		global gprdfiles `directory'
		global studyname `studyname'
		global studystartdate `ssta'
		global studyenddate `send'
		*gender
		global gender
		if "`gend'" == "Male & Female" global gender MF
		if "`gend'" == "Male only" global gender M
		if "`gend'" == "Female only" global gender F
		*age restrictions
		if `minage'==-1 global minage
		if "`minagetype'"!=="At index date (specify age in box in whole years)" global minage `minage' atindexdate
		if "`minagetype'"!=="At study start (specify age in box in whole years)" global minage `minage' atstudystart
		
		if `maxage'==-1 global maxage
		if "`maxagetype'"!=="At index date (specify age in box in whole years)" global maxage `maxage' atindexdate
		if "`maxagetype'"!=="At study start (specify age in box in whole years)" global maxage `maxage' atstudystart
		
		*reg/fup restrictions
		if `priorreg'==-1 global priorreg
		if "`priorregtype'"!=="At index date (specify months in box in whole months)" global priorreg `priorreg' atindexdate
		if "`priorregtype'"!=="At study start (specify months in box in whole months)" global priorreg `priorreg' atstudystart

		if `fup'==-1 global followup
		if "`fuptype'"!=="From index date (specify months in box in whole months)" global followup `fup' atindexdate
		if "`fuptype'"!=="From study start (specify months in box in whole months)" global followup `fup' atstudystart
				
		*inclusion 1
		global inc1codelist
		global inc1search
		global inc1inregperiod
		global inc1conditiontiming
		
		global inc1codelist "`inc1filename'"
		if `inc1searchclin'==1 global inc1search $inc1search clinical
		if `inc1searchimm'==1 global inc1search $inc1search immunisation
		if `inc1searchref'==1 global inc1search $inc1search referral
		if `inc1searchtest'==1 global inc1search $inc1search test
		if `inc1R2'==1 global inc1search therapy
		if `inc1inreg'==1 global inc1inregperiod yes
		if `inc1inreg'==0 global inc1inregperiod no
		if "`inc1crittype'"=="Any in study period" global inc1conditiontiming 	anyinstudyperiod
		if "`inc1crittype'"=="First ever in study period" global inc1conditiontiming firsteverinstudyperiod
		if "`inc1crittype'"=="Any before study end" global inc1conditiontiming 	anybeforestudyend
		
		*inclusion 2
		global inc2codelist
		global inc2search
		global inc2inregperiod
		global inc2conditiontiming
		global inc2combine 
		if `inc1addsecond'==1{
		global inc2codelist "`inc2filename'"
		if `inc2searchclin'==1 global inc2search $inc2search clinical
		if `inc2searchimm'==1 global inc2search $inc2search immunisation
		if `inc2searchref'==1 global inc2search $inc2search referral
		if `inc2searchtest'==1 global inc2search $inc2search test
		if `inc2R2'==1 global inc2search therapy
		if `inc2inreg'==1 global inc2inregperiod yes
		if `inc2inreg'==0 global inc2inregperiod no
		if "`inc2crittype'"=="Any in study period" global inc2conditiontiming 	anyinstudyperiod
		if "`inc2crittype'"=="First ever in study period" global inc2conditiontiming firsteverinstudyperiod
		if "`inc2crittype'"=="Any before study end" global inc2conditiontiming 	anybeforestudyend
		global inc2combine `inc2combinelogic'
		}
		
		*Run define if required 
		if `define'==1{
		noi dib "Running define tool", ul
		noi rungprddefine_skinepi
		}

		*Run extract if required
		if `extract'==1{
		noi dib "Running extract tool", ul
		noi rungprdextract_skinepi
		}
		
		***tidy up global macros and temp codelist files

		cap erase "$inc1codelist"
		cap erase "$inc2codelist"
		
		foreach gmac in gprdfiles studyname studystartdate studyenddate gender minage maxage ///
			priorreg followup inc1codelist inc1search inc1inregperiod inc1conditiontiming ///
			inc2codelist inc2search inc2inregperiod inc2conditiontiming inc2combine gprd_memavail{
				global `gmac'
		}
		

}/*end of quietly*/

	end
