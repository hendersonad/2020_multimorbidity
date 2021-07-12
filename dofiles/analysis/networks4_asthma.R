setwd("~/OneDrive - London School of Hygiene and Tropical Medicine/multimorb")
setwd('J:/EHR-Working/Amy/multimorbidity/data')

## Network Analysis AD multimorbidity with real data

.libPaths('H:/R/Rlibs')
pacman::p_load(tidyverse)
pacman::p_load(survival)
pacman::p_load(multcomp)
pacman::p_load(ggplot2)
pacman::p_load(visNetwork)
pacman::p_load(lme4)
pacman::p_load(lmerTest)
pacman::p_load(cluster)
pacman::p_load(factoextra)
pacman::p_load(dendextend)
pacman::p_load(here)
pacman::p_load(igraph)


# Load simplified data

if(grepl("macd0015", Sys.info()["nodename"])){
  datapath <- "/Volumes/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis/"
  load(file=paste0(datapath, "simpdata_asthma.RData"))
  rch <- read_csv(here::here("codelists/read_chapters.csv"))
}else{
  setwd("Z:/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis")
  datapath <- "Z:/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis"
  
  load(here("datafiles","simpdata_asthma.RData"))
}


mipid <- 1028
refde <- "2020-12-12"
refyb <- 1900

# Extract practice id from each patient (original minid = 1028)
dpw <- mutate(dpd, pr=c(pa + mipid - 1) %% 1000)

# Assign the control to the case with less controls
dc1 <- group_by(dcd, ca) %>% mutate(n=n()) %>% ungroup() %>% arrange(co, n) %>% group_by(co) %>% summarise(can=ca[1], nca=n[1])
dpw <- left_join(dpw, dc1, by=c("pa"="co")) %>% mutate(can=ifelse(is.na(can),pa,can))

# backtransform event dates & YOB
drd$ed <- as.Date(refde) - drd$ed * 365.25
dpw$tb <- as.Date(paste0((10*dpw$tb + refyb),"-07-01"))
dpw$td <- dpw$td*10*365.25+as.Date("1900-01-01")
dpw$td[is.na(dpw$td)] <- as.Date("2020-06-30")
dpw$fua <- as.numeric((dpw$td - dpw$tb)/365.25)

# Add first time of event
drw <- group_by(drd, pa, rc) %>% summarise(fi=min(ed)) %>% pivot_wider(id_cols=pa, names_from=rc, values_from=c(fi)) %>% ungroup()
names(drw)[-1] <- paste0('fi_', names(drw)[-1])

# merge pat data with event data
dpw <- left_join(dpw[, c('pa', 'mu', 'ca', 'pr', 'can', 'tb', 'td', 'fua')], drw, by="pa")

# Turn end of followup dates and dates of events into ages 
for(c in grep('fi_', names(dpw))) dpw[,c] <- as.numeric( dpw[,c] - dpw$tb ) /365.25

save(dpw, file=paste0(datapath,"datawide_asthma.RData"))


load(paste0(datapath,"datawide_asthma.RData"))


###############################################################.
###
###  Estimate JACCARD distance with a logistic regression  ####
###

E1 <- "fi_A"
E2 <- "fi_B"
DW <- "dpw"
Z  <- "mu"

jac1 <- function(DW, E1, E2, Z=NULL){
  # DW: Dataset wide format
  # E1: From this event
  # E2: To this event
  #  Z: Character vector of covariate names
  # It is assumed that there is a binary case variable "ca" and a group variable "can"
  t0 <- Sys.time()
  DD <- mutate(get(DW), d=(is.na(get(E1))+is.na(get(E2))), y=(1-d)) %>% 
    filter(d<2) %>% 
    rowwise() %>% 
    mutate(e1a=(min(get(E1),get(E2),na.rm=T)) ) %>% 
    ungroup() %>% 
    mutate(exy5=(fua-e1a-5), age50=(e1a-50)) 
  tcc <- table(DD$y, DD$ca, useNA="ifany")       #Numbers of individuals
  tcs <- table(DD$mu, DD$ca, useNA = 'ifany')    #Numbers of sexes
  ta0 <- as.numeric(summary(DD$fua[DD$ca==F]))               #Age dist at end of followup, controls
  ta1 <- as.numeric(summary(DD$fua[DD$ca==T]))               #Age dist at end of followup, cases
  te0 <- as.numeric(summary(DD$e1a[DD$ca==F]))               #Age dist at first event, controls
  te1 <- as.numeric(summary(DD$e1a[DD$ca==T]))               #Age dist at first event, cases
  tf0 <- as.numeric(summary(DD$exy5[DD$ca==F] + 5))          #followup from 1st event dist, controls
  tf1 <- as.numeric(summary(DD$exy5[DD$ca==T] + 5))          #followup from 1st event dist, cases
  mf <- paste("y ~ ca + age50 + exy5 ")
  zv=NA  # creat zv=Z for output
  if(!is.null(Z)){
    mf <- paste(mf,Z, sep=" + ")
    zv <- Z
  } 
  #print(mf)
  #m1b <- glm(as.formula(mf), data=DD, family=binomial())
  #m1c <- clogit(as.formula(paste(mf,"+ strata(can)")), data=DD)
  m1r <- glmer(as.formula(paste(mf,"+ (1|pr)")), data=DD, nAGQ=0, family=binomial())
  #print(summary(m1r))
  K <- c("(Intercept) = 0","(Intercept) + caTRUE = 0",                       #controls in men age50, cases in men age50
         "(Intercept) + muTRUE = 0","(Intercept) + muTRUE + caTRUE = 0",     #controls in women age50, cases in women age50
         "(Intercept) - 32*age50 = 0","(Intercept) - 32*age50 + caTRUE = 0",     #controls in men age18, cases in men age18
         "(Intercept) + muTRUE - 32*age50 = 0","(Intercept) + muTRUE - 32*age50 + caTRUE = 0")     #controls in women age18, cases in women age18
  lk <- glht(m1r, K)
  lc <- exp(confint(lk)$confint)
  lp <- summary(lk, test=adjusted("Shaffer"))$test$pvalues
  re <- list()
  re <- data.frame(data=DW, f1=E1, f2=E2, Adj=zv,
                   nn=tcc[1,1], An=tcc[1,2], nB=tcc[2,1], AB=tcc[2,2], 
                   sex_m0=tcs[1,1], sex_m1=tcs[1,2], sex_f0=tcs[2,1], sex_f1=tcs[2,2],
                   fage0_min=ta0[1], fage0_q1=ta0[2], fage0_med=ta0[3], fage0_mean=ta0[4], fage0_q3=ta0[5], fage0_max=ta0[6],
                   fage1_min=ta1[1], fage1_q1=ta1[2], fage1_med=ta1[3], fage1_mean=ta1[4], fage1_q3=ta1[5], fage1_max=ta1[6],
                   eage0_min=te0[1], eage0_q1=te0[2], eage0_med=te0[3], eage0_mean=te0[4], eage0_q3=te0[5], eage0_max=te0[6],
                   eage1_min=te1[1], eage1_q1=te1[2], eage1_med=te1[3], eage1_mean=te1[4], eage1_q3=te1[5], eage1_max=te1[6],
                   fu0_min=tf0[1], fu0_q1=tf0[2], fu0_med=tf0[3], fu0_mean=tf0[4], fu0_q3=tf0[5], fu0_max=tf0[6],
                   fu1_min=tf1[1], fu1_q1=tf1[2], fu1_med=tf1[3], fu1_mean=tf1[4], fu1_q3=tf1[5], fu1_max=tf1[6],
                   m0_50=lc[1,1], lm0_50=lc[1,2], um0_50=lc[1,3], pm0_50=lp[1],
                   m1_50=lc[2,1], lm1_50=lc[2,2], um1_50=lc[2,3], pm1_50=lp[2], 
                   w0_50=lc[3,1], lw0_50=lc[3,2], uw0_50=lc[3,3], pw0_50=lp[3],
                   w1_50=lc[4,1], lw1_50=lc[4,2], uw1_50=lc[4,3], pw1_50=lp[4], 
                   m0_18=lc[5,1], lm0_18=lc[5,2], um0_18=lc[5,3], pm0_18=lp[5],
                   m1_18=lc[6,1], lm1_18=lc[6,2], um1_18=lc[6,3], pm1_18=lp[6], 
                   w0_18=lc[7,1], lw0_18=lc[7,2], uw0_18=lc[7,3], pw0_18=lp[7],
                   w1_18=lc[8,1], lw1_18=lc[8,2], uw1_18=lc[8,3], pw1_18=lp[8], 
                   time=difftime(Sys.time(),t0,units="secs") )
  return(re)
}


test <- jac1("dpw", "fi_A", "fi_B", "mu")


###
###  Calculate edges with JAACCARD distance
###

ev <- paste0("fi_",sort(unique(drd$rc))[1:19])
edj <- NULL
t0 <- Sys.time()
for(e1 in ev[-length(ev)]){
  for(e2 in ev[(match(e1,ev)+1):length(ev)]){
    if(is.null(edj)){
      edj <- jac1("dpw", e1, e2, Z="mu")
    }else{
      edj <- rbind(edj, jac1("dpw", e1, e2, Z="mu"))
    } 
    print(paste(e1,e2,"time0:",difftime(Sys.time(),t0,units="mins")))
  }
}

save(edj, file=paste0(datapath, "edges2_jac1_asthma.RData"))


###########################################.
###
###  Hierarchical cluster analysis
###

rch <- read_csv(here::here("codelists/read_chapters.csv"))

#load(here::here("datafiles", "edges2_jac1_asthma.RData"))

# Put probability of 2 events given one
edj <- mutate(edj, 
              rm0_50=m0_50/(1+m0_50), rm1_50=m1_50/(1+m1_50),
              rw0_50=w0_50/(1+w0_50), rw1_50=w1_50/(1+w1_50),
              rm0_18=m0_18/(1+m0_18), rm1_18=m1_18/(1+m1_18),
              rw0_18=w0_18/(1+w0_18), rw1_18=w1_18/(1+w1_18))

plot(0, col='white', xlim=c(0,1), ylim=c(0,1), xlab = "control probability", ylab = "asthma probability")
c=1
for (i in c('m', 'w')) {
  for (j in c(50,18)) {
    points(edj[,paste0('r',i,'0_',j)], edj[,paste0('r',i,'1_',j)], col=c)
    c <- c+1
  }
}
abline(a=0, b=1)

# Read chapter names and put them in edges data
edj <- mutate(edj, e1=paste(substring(f1,4,4),rch$content[match(substring(f1,4,4), rch$chapter)], sep="_"), 
              e2=paste(substring(f2,4,4), rch$content[match(substring(f2,4,4), rch$chapter)], sep="_"))

## create dissimilarity matrix
ddm <- data.frame(e1=unique(c(edj$e1,edj$e2)), e2=unique(c(edj$e1,edj$e2)), 
                  rm0_50=1, rm1_50=1, rw0_50=1, rw1_50=1, rm0_18=1, rm1_18=1, rw0_18=1, rw1_18=1)
ddm <- rbind(edj[,c("e1","e2", "rm0_50","rm1_50", "rw0_50","rw1_50", "rm0_18","rm1_18", "rw0_18","rw1_18")],ddm)

## Covariates
cov <- edj[,c("e1","e2", grep('n|AB|sex|age|fu', names(edj), value = T))]


##
##  Distributions of covariates 
##

# transform to summary variables
# total N
cov$N <- cov$nn + cov$An + cov$nB + cov$AB
# % n in cases & controls
cov$n0 <- (cov$nn + cov$nB)/cov$N
cov$n1 <- (cov$An + cov$AB)/cov$N
# % outcome in cases & controls
cov$y0 <- cov$nB/(cov$nn + cov$nB)
cov$y1 <- cov$An/(cov$An + cov$AB)
# % female in cases & controls
cov$f0 <- cov$sex_f0/(cov$sex_f0 + cov$sex_m0)
cov$f1 <- cov$sex_f1/(cov$sex_f1 + cov$sex_m1)

# continuous covariates

par(mfrow=c(3,1))
# median age at first event for 171 regressions
h1 <- hist(cov$eage1_med, breaks=20, plot=F)
h0 <- hist(cov$eage0_med, breaks=20, plot=F)
plot(h1, col=rgb(0.1,0.1,0.1,0.5), 
     xlim=c(5,65), ylim=range(h1$counts, h0$counts),
     main="", xlab = "Median age (years) at first disease from disease pair")
plot(h0, col=rgb(0.8,0.8,0.8,0.5), add=T)
legend('topleft', c('Asthma', 'matched controls'), fill=c(rgb(0.1, 0.1, 0.1, 0.5), rgb(0.8, 0.8, 0.8, 0.5)))

# median age at end of followup for 171 regressions
h1 <- hist(cov$fage1_med, breaks=20, plot=F)
h0 <- hist(cov$fage0_med, breaks=20, plot=F)
plot(h1, col=rgb(0.1,0.1,0.1,0.5), 
     xlim=c(5,65), ylim=range(h1$counts, h0$counts),
     main="", xlab = "Median age (years) at end of followup")
plot(h0, col=rgb(0.8,0.8,0.8,0.5), add=T)


# median followup time for 171 regressions
h1 <- hist(cov$fu1_med, breaks=20, plot=F)
h0 <- hist(cov$fu0_med, breaks=20, plot=F)
plot(h1, col=rgb(0.1,0.1,0.1,0.5), 
     xlim=range(h1$breaks, h0$breaks), ylim=range(h1$counts, h0$counts),
     main="", xlab = "Median followup time (years)")
plot(h0, col=rgb(0.8,0.8,0.8,0.5), add=T)

title("Histograms: 171 disease pair regressions", outer=T)

# categorical covariates
barplot(cbind(c()), beside=TRUE)



##
##  Clusters 
##
# 
# pdf("dendrograms_asthma.pdf")
# for (k in c(50,18)) {
#   for (j in c('m', 'w')) {
#     for (i in 0:1){
#       md0 <- tapply(c(1-ddm[, paste0('r',j,i,'_',k)]), ddm[,c("e1","e2")], mean)
#       hc0 <- hclust(as.dist(t(md0)))
#       dhc0 <- as.dendrogram(hc0)
#       labels_cex(dhc0) <- 0.8
#       dhc0 <- color_branches(dhc0, h=0.5)
#       tit <- paste0('Age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
#                     ifelse(i==0, 'matched controls', 'asthma'), ' (complete linkage)')
#       
#       par(mar=c(4,2,3,13))
#       plot(dhc0, ylab="", axes=F, horiz=T, xlab="Probability of one condition given the other", 
#            main=tit)
#       text(0,19.5,"Read code chapter:", pos=4, xpd=NA, cex=0.9, font=2)
#       axis(1,at=xp<-seq(0,1,0.1), labels=1-xp, las=1, cex=0.8)
#       abline(v=c(0.5, 0.7), lty=2)
#       
#     }
#   }
# }
# dev.off()
# 
# pdf("dendrograms2_asthma.pdf")
# for (k in c(50,18)) {
#   for (j in c('m', 'w')) {
#     for (i in 0:1){
#       md0 <- tapply(c(1-ddm[, paste0('r',j,i,'_',k)]), ddm[,c("e1","e2")], mean)
#       hc0 <- hclust(as.dist(t(md0)), method = 'ward.D2')
#       dhc0 <- as.dendrogram(hc0)
#       labels_cex(dhc0) <- 0.8
#       dhc0 <- color_branches(dhc0, h=0.5)
#       tit <- paste0('Age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
#                     ifelse(i==0, 'matched controls', 'asthma'), ' (Ward D2 linkage)')
#       
#       par(mar=c(4,2,3,13))
#       plot(dhc0, ylab="", axes=F, horiz=T, xlab="Probability of one condition given the other", 
#            main=tit)
#       text(0,19.5,"Read code chapter:", pos=4, xpd=NA, cex=0.9, font=2)
#       axis(1,at=xp<-seq(0,1,0.1), labels=1-xp, las=1)
#       abline(v=c(0.5, 0.7), lty=2)
#     }
#   }
# }
# dev.off()


###########################################.
###
###  undirected NETWORK analysis
###


ev <- paste0("fi_",sort(unique(drd$rc))[1:19])

nod <- as.data.frame(t(apply(dpw[,ev], 2, function(x) table(is.na(x), dpw$ca))))
names(nod)[1:4] <- c("ye0","no0","ye1","no1")
nod <- mutate(nod, rc=row.names(nod), label=paste(substring(rc,4,4),rch$desc[match(substring(rc,4,4), rch$chapter)], sep="_"), 
              r0=ye0/(no0+ye0), r1=ye1/(no1+ye1), pos=as.numeric(as.factor(rc))) 

summary(nod)

## Network with CONTROLS data  UN-DIRECTED
##
nodes <- nod %>% transmute(id=rc, label, value=r0, x=cos(pos*pi/10), y=sin(pos*pi/10), physics=F)

pdf("networks_asthma.pdf")
for (k in c(50,18)) {
  for (j in c('m', 'w')) {
    for (i in 0:1){
      r <- paste0('r',j,i,'_',k)
      edges <- filter(edj, get(r)>0.3) %>% transmute(from=f1, to=f2, value=get(r), label=round(get(r),2))
      tit <- paste0('Undirected network (practice, follow-up adjusted), ', 
                    'age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
                    ifelse(i==0, 'matched controls', 'asthma'), ' P(A*B)|P(A+B) > 0.3')
      net <- visNetwork(nodes, edges, main=tit) %>% visNodes(shape="ellipse") %>% visIgraphLayout(randomSeed = 1999) %>% visEdges(width="width", smooth =T)
      print(net)
    }
  }
}
dev.off()

## Network with CASES data  UN-DIRECTED
##
nodes <- nod %>% transmute(id=rc, label, value=r1, x=cos(pos*pi/10), y=sin(pos*pi/10), physics=F)
edges <- filter(edj, r1>0.3) %>% transmute(from=f1, to=f2, value=r1, label=round(r1,2))
net1 <- visNetwork(nodes, edges, main="Undirected CASES (age, sex, practice, follow-up adjusted)\n P(A*B)|P(A+B) > 0.3") %>% visNodes(shape="ellipse") %>% visIgraphLayout(randomSeed = 1999) %>% visEdges(width="width", smooth =T)





###############################################################.
###
###  Calculate distance with OR with a logistic regression  ####
###
#  make non directed and directed models 
#

DW <- "dpw"
E1 <- "fi_A"
E2 <- "fi_B"
IT <- "ca"
D <- T

compute_edge2 <- function(DW, E1, E2, D=T, Z=NULL){
  # DW: Dataset wide format
  # E1: From this event
  # E2: To this event
  #  D: Is a directed edge? (T/F)
  # It is assumed that there is a binary case variable "ca" and a group variable "can"
  t0 <- Sys.time()
  DD <- mutate(get(DW), x=as.numeric(!is.na(get(E1))), y=!is.na(get(E2)))
  if(D==T) DD <- mutate(DD, x=ifelse(x==1 & y==1 & get(E1)>get(E2),0,x))
  tcc <- table(DD$x, DD$y, useNA="ifany")
  mf <- paste("y ~ x*ca + strata(can)")
  zv=NA  # creat zv=Z for output
  if(!is.null(Z)){
    mf <- paste("y ~ x*ca",Z,"strata(can)", sep=" + ")
    zv <- Z
  } 
  #print(mf)
  m1c <- clogit(as.formula(mf), data=DD)
  #print(m1c$coefficients)
  K <- c("x = 0","x + x:ca = 0","x:ca = 0")
  lk <- glht(m1c, K)
  lc <- exp(confint(lk)$confint)
  lp <- summary(lk, test=adjusted("Shaffer"))$test$pvalues
  re <- data.frame(data=DW, f1=E1, f2=E2, Adj=zv, Dir=D, int=IT,
                   nn=tcc[1,1], An=tcc[1,2], nB=tcc[2,1], AB=tcc[2,2], 
                   m0=lc[1,1], l0=lc[1,2], u0=lc[1,3], p0=lp[1],
                   m1=lc[2,1], l1=lc[2,2], u1=lc[2,3], p1=lp[2], 
                   mi=lc[3,1], li=lc[3,2], ui=lc[3,3], pi=lp[3], time=difftime(Sys.time(),t0,units="secs") )
  return(re)
}


xx <- transmute(dpw, pa, a=!is.na(fi_A), b=!is.na(fi_B), ab=fi_B>fi_A, ba=fi_A>fi_B)

compute_edge2("dpw", "fi_A", "fi_B")
compute_edge2("dpw", "fi_B", "fi_A")
compute_edge2("dpw", "fi_A", "fi_B", D=f)


###
###  Calculate edges
###

ev <- paste0("fi_",sort(unique(drd$rc))[1:19])
edg <- NULL
t0 <- Sys.time()
for(e1 in ev[-length(ev)]){
  for(e2 in ev[(match(e1,ev)+1):length(ev)]){
    t1 <- Sys.time()
    if(is.null(edg)){
      edg <- compute_edge2("dpw", e1, e2, D=F)
    }else{
      edg <- rbind(edg, compute_edge2("dpw", e1, e2, D=F))
    } 
    edg <- rbind(edg, compute_edge2("dpw", e1, e2))
    edg <- rbind(edg, compute_edge2("dpw", e2, e1))
    print(paste(e1,e2,"time0:",difftime(Sys.time(),t0,units="mins"),"  time1:",difftime(Sys.time(),t1,units="mins")))
  }
}

save(edg, file="results1.RData")


summary(edg)




###############################################################.
###
### Simulations of events and measurements of associations ####
###



# parameters

p1 <- c(0.4, 0.3) # probabilities of having A and B when other not present
p2 <- c(0.6, 0.7) # probabilities of having A and B when other is present
K  <- c(1,3)  # blocks k[1]case:k[2]controls 
N  <- 100000 # number of blocks
S <- N*sum(K)
aA <- c(6,4) # a,b parameters for beta distribution of age of A
aB <- c(6,4) # a,b parameters for beta distribution of age of B
aS <- c(9.5,0.5) # a,b parameters for beta age sampling distribution


plot(x=xp<-seq(0,1,0.01), y=dbeta(xp,aS[1],aS[2]), type="l", ylim=c(0,4))
lines(x=xp<-seq(0,1,0.01), y=dbeta(xp,aA[1],aA[2]), col=2)
lines(x=xp<-seq(0,1,0.01), y=dbeta(xp,aB[1],aB[2]), col=3)

# simulate events:
ds <- data.frame(n=c(1:S)) %>% 
  mutate(aa=100*rbeta(S,aA[1],aA[2]), 
         ab=100*rbeta(S,aB[1],aB[2]),
         A=ifelse(rbinom(S,1,p1[1])==1,aa,NA),
         B=ifelse(rbinom(S,1,p1[2])==1,ab,NA),
         A=ifelse((aa>ab)*!is.na(B)*is.na(A)*rbinom(S,1,p2[1])==1,aa,A),
         B=ifelse((ab>aa)*!is.na(A)*is.na(B)*rbinom(S,1,p2[2])==1,ab,B),
         as=100*rbeta(S,aS[1],aS[2]),
         A=ifelse(aa<=as,A,NA), B=ifelse(ab<=as,B,NA),
         ca=rep(rep(c(1,0),K),N), can=rep(c(1:N), each=sum(K)))


compute_edge2("ds", "A", "B", D=F)
compute_edge2("ds", "A", "B", D=F, Z="as")
compute_edge2("ds", "A", "B", D=T)
compute_edge2("ds", "A", "B", D=T, Z="as")
compute_edge2("ds", "B", "A", D=T)
compute_edge2("ds", "B", "A", D=T, Z="as")


K  <- c(1,3)  # blocks k[1]case:k[2]controls 
N  <- 100000 # number of blocks
S  <- N*sum(K)
P1 <- list(c(0.4,0.3),c(0.4,0.3),c(0.4,0.3)) 
P2 <- list(c(0.4,0.3),c(0.6,0.6),c(0.2,0.2))
AA <- list(c(1,1), c(5,5), c(5,5))
BB <- list(c(1,1), c(5,5), c(7,3))
AS <- list(c(1,1), c(2,8), c(5,5), c(8,2))
EDS <- NULL
t0 <- Sys.time()
for(p in 1:length(P2)){
  p1 <- P1[[p]]
  p2 <- P2[[p]]
  for(e in 1:length(AA)){
    aA <- AA[[e]]
    aB <- BB[[e]]
    for(a in 1:length(AS)){
      t1 <- Sys.time()
      aS <- AS[[a]]
      ds <- data.frame(n=c(1:S)) %>% 
        mutate(aa=100*rbeta(S,aA[1],aA[2]), 
               ab=100*rbeta(S,aB[1],aB[2]),
               A=ifelse(rbinom(S,1,p1[1])==1,aa,NA),
               B=ifelse(rbinom(S,1,p1[2])==1,ab,NA),
               A=ifelse((aa>ab)*!is.na(B)*is.na(A)*rbinom(S,1,p2[1])==1,aa,A),
               B=ifelse((ab>aa)*!is.na(A)*is.na(B)*rbinom(S,1,p2[2])==1,ab,B),
               as=100*rbeta(S,aS[1],aS[2]),
               A=ifelse(aa<=as,A,NA), B=ifelse(ab<=as,B,NA),
               ca=rep(rep(c(1,0),K),N), can=rep(c(1:N), each=sum(K)))
      eds <- compute_edge2("ds", "A", "B", D=F)
      eds <- rbind(eds, compute_edge2("ds", "A", "B", D=F, Z="as"))
      eds <- rbind(eds, compute_edge2("ds", "A", "B"))
      eds <- rbind(eds, compute_edge2("ds", "A", "B", Z="as"))
      eds <- rbind(eds, compute_edge2("ds", "B", "A"))
      eds <- rbind(eds, compute_edge2("ds", "B", "A", Z="as"))
      eds$p2 <- paste(p2,collapse=",")
      eds$aA <- paste(aA,collapse=",")
      eds$aB <- paste(aB,collapse=",")
      eds$aS <- paste(aS,collapse=",")
      if(is.null(EDS)) EDS <- eds else EDS <- rbind(EDS,eds)
      print(paste("time0:",difftime(Sys.time(),t0,units="mins"),"  time1:",difftime(Sys.time(),t1,units="mins")))
    }
  }
}

save(EDS, file="simul.RData")


# Age sampling
as <- list(c(1,1), c(2,8), c(5,5), c(8,2)) # a,b parameters for beta age sampling distribution
plot(0,0, type="n", xlim=c(0,1), ylim=c(0,4), las=1)
for(i in 1:4) lines(x=xp<-seq(0,1,0.01), y=dbeta(xp,as[[i]][1], as[[i]][2]), col=i)




