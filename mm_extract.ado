/*=========================================================================
ADO FILE NAME:			mm_extract.ado

AUTHOR:					Ali Henderson		
VERSION:				v1
DATE VERSION CREATED: 	2017-Oct-12
			2018-Jan-04 // edited to update file paths for change to 2018 project directory
						
DESCRIPTION OF FILE:	ado file to change directory

*=========================================================================*/


*! version 1.0 \ kate mansfield 2015-07-22
capture program drop mm_extract
program define mm_extract	
	* location of path file
	local locationPathFile "J:\EHR-Working\Ali\2020_multimorbidity"
	version 15
	args dir
	if "`dir'"=="work" {
		cd "`pathWorking'"
	}
	else if "`dir'"=="post" {
		cd "`pathPosted'"
	}
	else if "`dir'"=="paths" {
		cd "`locationPathFile'"
		run mm-paths.do
	}
	else if "`dir'"==""	{	//list current working directory
		cd
	}
	else {
		display as error "Working directory `dir' is unknown."
	}
end
	

	
	