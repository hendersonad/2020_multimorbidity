/*=========================================================================
DO FILE NAME:			prog_identifyTherapy

AUTHOR:					Kate Mansfield		
VERSION:				v2
DATE VERSION CREATED: 	v2 2017-Aug-07	// edited to change name of variable databasebuild to build (to match Jan 2017 CPRD build naming)
						v1 2016-Jul-13

DATASETS USED: 	therapy extract files for given codelists for exposure drugs			
							
DESCRIPTION OF FILE:	
	goes through therapy extract files and extracts prescriptions given a 
	prodcode list - creates a file per therapy extract file 
		
*=========================================================================*/

/*******************************************************************************
#>> Define program
*******************************************************************************/
cap prog drop prog_identifyTherapy
program define prog_identifyTherapy

syntax, therapyfile(string) codelist(string) filenum(integer) ///
	dofilename(string) savefile(string)
	
* therapyfile 	// path and file name of therapy extract file
* codelist		// path and file name of prodcodelist
* filenum		// number of therapy extract files to loop through
* dofilename	// name of do-file calling the program
* savefile		// file prefix to save results



* Loop through each therapy extract file merge with prodcode dataset and save
forvalues x=1/`filenum' {
	display in red "****************File number: `x'****************"


	/******************************************************************************* 
	#1. Open therapy extract and merge with codelist to id records
	*******************************************************************************/			
	use `therapyfile'_`x', clear
	sort prodcode
	merge m:1 prodcode using "`codelist'", nogen keep(match) force // only keep matching records

	// manual bodge (Ali) merge m:1 prodcode using $pathCodelists/prodcodes-eczemaRx.dta, nogen keep(match) force // only keep matching records


	* drop unecessary vars
	drop consid staffid //bnfcode bnfhead 
	
	
	
	/******************************************************************************* 
	#2 Merge in common dosages file
	*******************************************************************************/	
	/*
	no longer need to do this as textid is a number in this build
	generate textid_Num = real(textid)	// first need to convert textid var to numeric
	recast long textid_Num				// covert new textid var to the same datatype as in lookUp file (i.e. using file in merge)
	drop textid							// drop old var
	rename textid_Num textid			// rename new textid
	*/
	merge m:1 dosageid using $pathOut/common_dosages, nogen keep(match master) force // delete records that are in using dataset but not master ie _merge==2
	
	
	
	/******************************************************************************* 
	#3 Merge in packtype info
	*******************************************************************************/
	merge m:1 packtype using $pathOut/packtype, nogen keep(match master) force // delete records that are in using dataset but not master ie _merge==2


	/******************************************************************************* 
	#4 Label the data
	*******************************************************************************/
	label var patid "patid: unique CPRD patient identifier"
	label var eventdate "eventdate: date associated with the event, as entered by the GP"
	label var sysdate	"sysdate: Date event entered into Vision"
	label var prodcode	"prodcode: CPRD unique code for the treatment selected"
	label var qty	"qty: Total quantity for prescribed product"
	*label var ndd	"ndd: Numeric daily dose prescribed. Derived using CPRD algorithm on common dosage strings (textid<100,000)"
	label var numdays	"numdays: Num treatment days prescribed for specific therapy event"
	label var numpacks	"numpacks: Num individual product packs prescribed for specific therapy event"
	label var packtype	"packtype: Pack size or type of the prescribed product"
	label var issueseq	"issueseq: Indicates whether the event assoc with repeat schedule. 0=not repeat prescription"
	label var dosageid "textid: links to freetext in common dosages lookup file if < 100,00"


	/******************************************************************************* 
	#4 Save the file
	*******************************************************************************/		
	label data "therapy data"
	notes: prog_identifyTherapy \ TS
	notes: additional data from common dosages and packtype file merged in
	notes: `dofilename' \ TS
	compress
	save `savefile'-`x', replace
}



end
