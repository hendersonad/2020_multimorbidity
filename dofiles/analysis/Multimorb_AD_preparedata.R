# Prepare CPRD extract (19/04/2021) for multimorbidity analysis
# Code adapted from David Prieto-Merino
# Amy Mulick, LSHTM
# Begin 19 April 2021


rm(list=ls())
setwd("Z:/GPRD_GOLD/Ali/2020_multimorbidity/analysis")

dcc <- read.csv(file="eczema_case_control_set.csv", stringsAsFactors = F)
dpi <- read.csv(file="eczema_patient_info.csv", stringsAsFactors = F)
drc <- read.csv(file="eczema_read_chapter.csv", colClasses = c("integer", "character", "NULL", "character"))

## how much data after covid pandemic?
drc$date2 <- lubridate::parse_date_time(drc$eventdate, orders = "dbY")
table(drc$date2 > as.Date("2020-04-01"))

sum(dcc$caseid==dcc$contid)
length(unique(dcc$caseid))
length(unique(dcc$contid))
length(unique(drc$patid))

# In the dcc there are 2,171,741 rows associated but actually only 1,333,281 different control ids and 434,422 case ids. 
# In dpi there are 1,767,703 patients
# In drc there are 1,699,392 patients with 54,222,168 events



## Prepare data for analyis

# get case for each control

# Get IDs of events and cases
ide <- unique(dcc$caseid)  # ID of eczema pat
idc <- unique(dcc$contid)  # ID of control pat
idc <- idc[!(idc %in% ide)]


# simplifed patient data
dpd <- dpi[, c("patid", "gender", "realyob", "tod")] # changed deathdate to tod 21 April 2021
names(dpd) <- c("pa","mu","tb","td")
mipid <- min(dpi$patid)  # minimum patient ID
dpd$pa <- dpd$pa - mipid + 1  # Recode patient ID
dpd$mu <- grepl("Female", dpd$mu)
dpd$tb <- (dpd$tb - 1900)/10
dpd$td <- as.numeric(as.Date(dpd$td, "%d%b%Y") - as.Date("1900-01-01"))/(10*365.25)
dpd$ca <- dpd$pa %in% (ide - mipid +1)

# Simplify case-control data
dcd <- dcc[dcc$contid %in% idc,]
names(dcd) <- c("ca","co")
dcd$ca <- dcd$ca - mipid + 1
dcd$co <- dcd$co - mipid + 1

# Simplify events data
drd <- drc
names(drd) <- c("pa","ed","rc")
drd$pa <- drd$pa - mipid + 1
drd$ed <- as.numeric(as.Date("2020-12-12") - as.Date(drd$ed, "%d%b%Y"))/365.25


## Save simplified data
save(dpd, dcd, drd, file="simpdata.RData")





## Prepare data in wide format

# put events in wide format
drw <- aggregate(ed ~ pa + rc, data=drd, min)
drw$ed <- round(drw$ed, 3)
drw <- reshape(drw, direction = "wide", idvar = "pa", timevar = "rc")
drw <- drw[,-22] # remove event W

dw <- merge(dpd, drw, by="pa", all.x=T, all.y=F)




length(unique(dcc$caseid))


dj10 <- read.csv(file="eczema_patient_info_joined.csv", nrows = 10)

djo <- read.csv(file="eczema_patient_info_joined.csv", nrows = 1000000, colClasses = c("integer", "NULL", "character", "integer", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "integer", "character", "NULL", "character"))

