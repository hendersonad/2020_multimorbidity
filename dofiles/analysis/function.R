
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
