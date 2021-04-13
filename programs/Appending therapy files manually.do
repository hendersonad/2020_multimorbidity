local mem_mult=1073741824 // for GBs

global gprd_memavail = 0.85*(6*`mem_mult')/1073741824

local practot = 937
local startfile = 1
local splitnum = 1
local filenum = 1

while `filenum' <= `practot' {
	di `filenum' , _cont
	local memoryused = 0
	
	local fileexists=0
	
	while `fileexists'==0 & `filenum'<=`practot'{
		cap use "Z:/GPRD_GOLD/Ali/2020_multimorbidity/in/Therapy`filenum'", clear
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
	//sort ``file'sort' 
	sort patid eventdate prodcode issueseq sysdate
	save "Z:/GPRD_GOLD/Ali/2020_multimorbidity/in/Therapy_extract_mm_eczema_extract_matched_`splitnum'", replace
	}
	
	local splitnum = `splitnum' + 1

} /*keeps going round until been through all practices*/
/*end of loop for file type*/
