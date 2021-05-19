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
	version 15
	
	syntax, computer(string)

	if "`computer'" == "mac"{
		* location of path file
		local locationPathFile "/Users/lsh1510922/Documents/Postdoc/2020_multimorbidity"
		cd "`locationPathFile'"		
		run "mm-paths-mac.do"
	}
	if "`computer'" == "windows"{
		local locationPathFile "JC:\Users\lsh1510922\Documents\2020_multimorbidity"
		cd "`locationPathFile'"		
		run mm-paths.do
	}

end
	

	
	
