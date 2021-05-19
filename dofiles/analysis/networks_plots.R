## networks plotting 
install.packages("pacman")
pacman::p_load(igraph)
pacman::p_load(dendextend)
pacman::p_load(readr)
pacman::p_load(dplyr)
pacman::p_load(tidyr)
pacman::p_load(here)
pacman::p_load(viridis)
pacman::p_load(RColorBrewer)
pacman::p_load(devtools)
#devtools::install_github("thomasp85/scico")
library(scico)
#devtools::install_github("EmilHvitfeldt/paletteer")
library(paletteer)
pacman::p_load(wesanderson)

source(here("programs/bespoke_colour_branches.R")) 
colgrid <- rgb(0.4,0.4,0.4,0.1)
# load data  --------------------------------------------------------------
datapath <- "/Volumes/DATA/sec-file-b-volumea/EPH/EHR group/GPRD_GOLD/Ali/2020_multimorbidity/analysis/"

if(grepl("macd0015", Sys.info()["nodename"])){
  load(paste0(datapath,"edges2_jac1_asthma.RData"))
  edj_asthma <- edj
  load(paste0(datapath,"edges2_jac1.RData"))
  edj_eczema <- edj
  
  rch <- read_csv(here("codelists/chapter_names.csv"))
  
  
  refde <- "2020-12-12"
  load(paste0(datapath,"simpdata_asthma.RData"))
  drd$ed <- as.Date(refde) - drd$ed * 365.25
  drd_asthma <- drd
  load(paste0(datapath,"simpdata.RData"))
  drd$ed <- as.Date(refde) - drd$ed * 365.25
  drd_eczema <- drd
  
  load(paste0(datapath,"datawide_asthma.RData"))
  dpw_asthma <- dpw
  load(paste0(datapath,"datawide.RData"))
  dpw_eczema <- dpw
}else{
  load(here("datafiles/edges2_jac1_asthma.RData"))
  edj_asthma <- edj
  load(here("datafiles/edges2_jac1.RData"))
  edj_eczema <- edj
  
  rch <- read_csv(here("codelists/read_chapters.csv"))
  
  
  refde <- "2020-12-12"
  load(here("datafiles","simpdata_asthma.RData"))
  drd$ed <- as.Date(refde) - drd$ed * 365.25
  drd_asthma <- drd
  load(here("datafiles","simpdata.RData"))
  drd$ed <- as.Date(refde) - drd$ed * 365.25
  drd_eczema <- drd
  
  load(here("datafiles/datawide_asthma.RData"))
  dpw_asthma <- dpw
  load(here("datafiles/datawide.RData"))
  dpw_eczema <- dpw
}

# data formatting ---------------------------------------------------------
format_edges <- function(data_in){
  # Put probability of 2 events given one
  edj <- mutate(data_in, 
                rm0_50=m0_50/(1+m0_50), rm1_50=m1_50/(1+m1_50),
                rw0_50=w0_50/(1+w0_50), rw1_50=w1_50/(1+w1_50),
                rm0_18=m0_18/(1+m0_18), rm1_18=m1_18/(1+m1_18),
                rw0_18=w0_18/(1+w0_18), rw1_18=w1_18/(1+w1_18))
  
  # Read chapter names and put them in edges data
  edj <- mutate(edj, 
                e1 = rch$name[match(substring(f1,4,4), rch$var)],
                e2 = rch$name[match(substring(f2,4,4), rch$var)]
  )
                #e1=paste(substring(f1,4,4),rch$name[match(substring(f1,4,4), rch$var)], sep=": "), 
                #e2=paste(substring(f2,4,4), rch$name[match(substring(f2,4,4), rch$var)], sep=": "))
  
  data_out <- edj
  data_out
}

# Dendrogram plot ---------------------------------------------------------

#par(mar=c(4,2,3,13))
dendo_plot <- function(data_in, k = 50, j = "m", i = 0, shortnames = FALSE){
  edj2 <- format_edges(data_in)
  
  ## create dissimilarity matrix
  ddm <- data.frame(e1=unique(c(edj2$e1,edj2$e2)), e2=unique(c(edj2$e1,edj2$e2)), 
                    rm0_50=1, rm1_50=1, rw0_50=1, rw1_50=1, rm0_18=1, rm1_18=1, rw0_18=1, rw1_18=1)
  ddm <- rbind(edj2[,c("e1","e2", "rm0_50","rm1_50", "rw0_50","rw1_50", "rm0_18","rm1_18", "rw0_18","rw1_18")],ddm)

  md0 <- tapply(c(1-ddm[, paste0('r',j,i,'_',k)]), ddm[,c("e1","e2")], mean)
  hc0 <- hclust(as.dist(t(md0)))
  dhc0 <- as.dendrogram(hc0)
  labels_cex(dhc0) <- 1.4

  if(i==0){
    #ali_colours <- function(n){viridis(n, alpha = 1, begin = 0.2, end = 0.8, option = "inferno")}
    #ali_colours <- function(n){scico(n, palette = "lajolla",alpha = 1, begin = 0.3, end = 0.7)}
    ali_colours <- function(n){colorRampPalette(RColorBrewer::brewer.pal("RdYlBu", n = 8))(n)}
    #RdYlBu <- c("#74ADD1" ,"#ABD9E9" ,"#E0F3F8" ,"#FEE090" ,"#FDAE61","#F46D43")
    #ali_colours <- function(n){colorRampPalette(RdYlBu)(n)}
    #ali_colours <- function(n){colorRampPalette(wesanderson::wes_palette("Zissou1", 5, type = "discrete"))(n)}
    line_col <- wesanderson::wes_palette("Zissou1", 1, type = "discrete")
    line_col <- "tomato"
    dhc0 <- ali_branch(dhc0, h=0.7, col=ali_colours, groupLabels = T)
  }else{
    #ali_colours <- function(n){viridis(n, alpha = 1, begin = 0.2, end = 0.8, option = "mako")}
    #ali_colours <- function(n){scico(n, palette = "lapaz",alpha = 1, begin = 0.3, end = 0.7)}
    #PiYG <- c("#DE77AE", "#F1B6DA", "#FDE0EF" ,"#E6F5D0", "#B8E186" ,"#7FBC41")
    #ali_colours <- function(n){colorRampPalette(PiYG)(n)}
    ali_colours <- function(n){colorRampPalette(rev(RColorBrewer::brewer.pal("RdYlBu", n = 8)))(n)}
    #ali_colours <- function(n){colorRampPalette(RColorBrewer::brewer.pal("PiYG", n = 8))(n)}
    #ali_colours <- function(n){colorRampPalette(wesanderson::wes_palette("Darjeeling2", 5, type = "discrete"))(n)}
    line_col <- wesanderson::wes_palette("Darjeeling2", 1, type = "discrete")
    line_col <- "darkblue"
    dhc0 <- ali_branch(dhc0, h=0.7, col=ali_colours, groupLabels = T)
  }  
  
  tit <- paste0('Age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
                ifelse(i==0, 'matched controls', 'asthma'), ' (complete linkage)')
  
  if(shortnames == TRUE){labels(dhc0) <- substr(labels(dhc0),1,1)}
  short_labs <- substr(labels(dhc0),1,1)
  old_labs <- labels(dhc0)
  #labels_colors(dhc0) <- 1
  
  #labels_colors(dhc0)[grepl("M:", labels(dhc0))] <- 2
  #labels_colors(dhc0)[grepl("H:", labels(dhc0))] <- 2
  
  dhc0 %>%
    hang.dendrogram(hang = 0.1) %>% 
    plot(ylab="", axes=F, horiz=T, xlab="",main="")  
    
    if(shortnames == FALSE){mtext(side = 1, "Probability of one condition given the other", cex=1.3, font=1, padj=3, adj =0)}
  axis(1,at=xp<-seq(0,1,0.1), labels=1-xp, las=1, cex=0.8)
  abline(v=c(0.7), lty=2, col=line_col, lwd = 2 )
  grid(NULL, NA, lty = 1, col = colgrid) 
}

## test
dendo_plot(data_in = edj_eczema, k = 18, j = "m", i = 0)
dendo_plot(data_in = edj_asthma, k = 18, j = "m", i = 0)
dendo_plot(data_in = edj_asthma, k = 18, j = "m", i = 1)
dendo_plot(data_in = edj_asthma, k = 50, j = "m", i = 1)

# network plots -----------------------------------------------------------
ntwk_nodes <- function(cohort = "asthma"){
  if(cohort=="asthma"){
    drd <- drd_asthma
    dpw <- dpw_asthma
  }else{
    drd <- drd_eczema
    dpw <- dpw_eczema
  }

  ev <- paste0("fi_",sort(unique(drd$rc))[1:19])

  nod <- as.data.frame(t(apply(dpw[,ev], 2, function(x) table(is.na(x), dpw$ca))))
  names(nod)[1:4] <- c("ye0","no0","ye1","no1")
  nod <- mutate(nod, rc=row.names(nod), label=paste(substring(rc,4,4),rch$name[match(substring(rc,4,4), rch$name)], sep="_"), 
              r0=ye0/(no0+ye0), r1=ye1/(no1+ye1), pos=as.numeric(as.factor(rc))) 

  ## Network with CONTROLS data  UN-DIRECTED
  nodes <- nod %>% transmute(id=rc, label, value=r0, x=cos(pos*pi/10), y=sin(pos*pi/10), physics=F)
  nodes
}

nodes_eczema <- ntwk_nodes("eczema")
nodes_asthma <- ntwk_nodes("asthma")

ntwk_plot <- function(cohort = "asthma", k = 50, j = "m", i = 1){
    if(cohort == "eczema"){
      edj <- format_edges(edj_eczema)
      nodes <- nodes_eczema
    }else{
      edj <- format_edges(edj_asthma)
      nodes <- nodes_asthma
    }
      r <- paste0('r',j,i,'_',k)
      edges <- filter(edj, get(r)>0.3) %>% 
        transmute(from=f1, to=f2, value=get(r), label=round(get(r),2)) %>%
        rename(weight = value)
      tit <- paste0('Undirected network (practice, follow-up adjusted), ', 
                    'age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
                    ifelse(i==0, 'matched controls', 'asthma'), ' P(A*B)|P(A+B) > 0.3')
      net <- graph_from_data_frame(d = edges, vertices = nodes, directed = F)
      
      temp_names <- V(net)$label
      V(net)$label <- substr(temp_names,1,1)
      E(net)$width <- (E(net)$weight)*5
      E(net)$label <- NA
      
      col <- ifelse(i == 1, 
                    rgb(0,0,139, maxColorValue = 255),    #darkblue
                    rgb(255,60,71, maxColorValue = 255))  #tomato
      colA <- ifelse(i == 1, 
                     rgb(0,0,139, maxColorValue = 255, alpha = 120), 
                     rgb(255,60,71, maxColorValue = 255, alpha = 120))
      
      label_plot <- paste0("Connections: ", length(E(net)$width),"\n")
      label_plot2 <- edges %>% 
        arrange(-weight) %>% 
        slice(1) %>%
        mutate(lab2 = paste0(substr(from,4,4)," - ",substr(to,4,4),": ", label, "\n")) %>% 
        pull(lab2)
      label_plot2 <- paste0(label_plot2,collapse = " ")
      label_plot2 <- paste0("Max prob: ", label_plot2)
      
      label_plot3 <- paste0(label_plot, label_plot2)
      plot(net, vertex.color = rgb(0,0,0, alpha = 0.1), 
           vertex.label.color = col,
           edge.color = colA,
           vertex.shape = "circle",
           vertex.frame.color = rgb(0,0,0, alpha = 0.5),
           vertex.label.font = 2,
           edge.curved=.1)
      mtext(side=1, label_plot3, font=1, cex = 0.7, adj=0, padj=1)
      #mtext(side=1, label_plot, font=1, cex = 0.7, adj=0, padj=1)
      #mtext(side=1, label_plot2, font=1, cex = 0.7, adj=1, padj=1)
      #net <- visNetwork(nodes, edges, main=tit) %>% visNodes(shape="ellipse") %>% visIgraphLayout(randomSeed = 1999) %>% visEdges(width="width", smooth =T)
      #print(net)
}
ntwk_plot(cohort = "asthma", k = 50, j = "w", i = 0)
ntwk_plot(cohort = "asthma", k = 50, j = "w", i = 1)


# combine plots  ----------------------------------------------------------
plot_together <- function(cohort = "eczema", k = 50, j = "m"){
  tit <- paste0('Undirected network (practice, follow-up adjusted)')
  tit2 <- paste0('Age ', k, ', ', ifelse(j=='m','men', 'women'), ': ', 
                cohort)
  
par(mfrow = c(2,2))
par(mar=c(4,4,3,18))
  if(cohort == "eczema"){
    edj_plot = edj_eczema
  }else{
    edj_plot = edj_asthma
  }
dendo_plot(data_in = edj_plot, i = 1, k = k, j = j)
  mtext(side = 3, tit2, adj = 0, font = 2, cex = 1.3, padj = -1.8)
  mtext(side = 3, "A", adj = 0, font = 2)
dendo_plot(data_in = edj_plot, i = 0, k = k, j = j)
  mtext(side = 3, "Matched controls", adj = 0, font = 2, cex = 1.3, padj = -1.8)
  mtext(side = 3, "B", adj = 0, font = 2)
par(mar = (c(0,0,1,0)))
ntwk_plot(cohort = cohort, i = 1, k = k, j = j)
  mtext(side = 3, "C", adj = 0.1, font = 2)
ntwk_plot(cohort = cohort, i = 0, k = k, j = j)
  mtext(side = 3, "D", adj = 0.1, font = 2)
}


## ECZEMA
# 18 y.o. women
pdf(here::here("out/fig3_E_18w.pdf"), 13, 13)
  plot_together(cohort = "eczema", k = 18, j = "w")
dev.off()
# 18 y.o. men
pdf(here::here("out/fig3_E_18m.pdf"), 13, 13)
  plot_together(cohort = "eczema", k = 18, j = "m")
dev.off()
# 50 y.o. women
pdf(here::here("out/fig3_E_50w.pdf"), 13, 13)
  plot_together(cohort = "eczema", k = 50, j = "w")
dev.off()
# 50 y.o. men
pdf(here::here("out/fig3_E_50m.pdf"), 13, 13)
  plot_together(cohort = "eczema", k = 50, j = "m")
dev.off()

## ASTHMA
# 18 y.o. women
pdf(here::here("out/fig3_A_18w.pdf"), 13, 13)
  plot_together(cohort = "asthma", k = 18, j = "w")
dev.off()
# 18 y.o. men
pdf(here::here("out/fig3_A_18m.pdf"), 13, 13)
  plot_together(cohort = "asthma", k = 18, j = "m")
dev.off()
# 50 y.o. women
pdf(here::here("out/fig3_A_50w.pdf"), 13, 13)
  plot_together(cohort = "asthma", k = 50, j = "w")
dev.off()
# 50 y.o. men
pdf(here::here("out/fig3_A_50m.pdf"), 13, 13)
  plot_together(cohort = "asthma", k = 50, j = "m")
dev.off()


# all dendrograms ---------------------------------------------------------
plot_all_dendo <- function(ii = 0, cc = "eczema", l = 1){
  short <- T
  #if(l!=1){par(mar=c(2,2,1.5,2)+0.5)}else{par(mar=c(4,2,1.5,2)+0.5)}
  par(mar=c(4,2,2,2)-0.5)
  
  if(cc == "eczema"){
    edj_plot = edj_eczema
  }else{
    edj_plot = edj_asthma
  }
  pp <- 2.5
  dendo_plot(data_in = edj_plot, i = ii, k = 18, j = "m", shortnames = short)
    mtext(side = 1, "P(A|B)", cex=1, font=1, padj=pp, adj=1)
  if(ii==1){
    mtext(side = 3, paste0(LETTERS[l],": Age 18, men ", cc), adj = 0, font = 2)
    #if(l==1100){mtext(side = 1, "Probability of one condition given the other", cex=1, font=1, padj=3, adj =0)}
  }else{
    mtext(side = 3, paste0(LETTERS[l], ": matched controls ", cc,")"), adj = 0, font = 2)
  }
  dendo_plot(data_in = edj_plot, i = ii, k = 18, j = "w", shortnames = short)
    mtext(side = 1, "P(A|B)", cex=1, font=1, padj=pp, adj=1)
  if(ii==1){
    mtext(side = 3, paste0(LETTERS[l+1],": Age 18, women ", cc), adj = 0, font = 2)
  }else{
    mtext(side = 3, paste0(LETTERS[l+1], ": matched controls ", cc,")"), adj = 0, font = 2)
  }
  dendo_plot(data_in = edj_plot, i = ii, k = 50, j = "m", shortnames = short)
    mtext(side = 1, "P(A|B)", cex=1, font=1, padj=pp, adj=1)
  if(ii==1){
    mtext(side = 3, paste0(LETTERS[l+2],": Age 50, men ", cc), adj = 0, font = 2)
  }else{
    mtext(side = 3, paste0(LETTERS[l+2], ": matched controls ", cc,")"), adj = 0, font = 2)
  }
  dendo_plot(data_in = edj_plot, i = ii, k = 50, j = "w", shortnames = short)
    mtext(side = 1, "P(A|B)", cex=1, font=1, padj=pp, adj=1)
  if(ii==1){
    mtext(side = 3, paste0(LETTERS[l+3],": Age 50, women ", cc), adj = 0, font = 2)
  }else{
    mtext(side = 3, paste0(LETTERS[l+3], ": matched controls (", cc,")"), adj = 0, font = 2)
  }
}
pdf(here::here("out/fig5_dendo_all.pdf"), 14, 14)
par(mfcol = c(4,4))
  plot_all_dendo(ii = 1, cc = "eczema")
  plot_all_dendo(ii = 0, cc = "eczema",5)
  plot_all_dendo(ii = 1, cc = "asthma",10)
  plot_all_dendo(ii = 0, cc = "asthma",14)
dev.off()

# pdf(here::here("out/fig2_eczema.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_eczema, i = 1, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 1, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, women", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 1, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 1, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, women", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_eczemacontrols.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_eczema, i = 0, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, women", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, women", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_asthma.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_asthma, i = 1, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 1, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, women", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 1, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 1, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, women", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_asthmacontrols.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_asthma, i = 0, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, women", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, women", adj = 0, font = 2)
# dev.off()

#################################################
## do 4 plots differently (Eczema men, women, Asthma men, women)

# pdf(here::here("out/fig2_ecz_men.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_eczema, i = 1, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men with eczema", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 18, j = "m")
#     mtext(side = 3, "B: Age 18, matched controls", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 1, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men with eczema", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 50, j = "m")
#     mtext(side = 3, "D: Age 50, matched controls", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_ecz_women.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_eczema, i = 1, k = 18, j = "w")
#     mtext(side = 3, "A: Age 18, women with eczema", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, matched controls", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 1, k = 50, j = "w")
#     mtext(side = 3, "C: Age 50, women with eczema", adj = 0, font = 2)
#   dendo_plot(data_in = edj_eczema, i = 0, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, matched controls", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_ast_men.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_asthma, i = 1, k = 18, j = "m")
#     mtext(side = 3, "A: Age 18, men with asthma", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 18, j = "m")
#     mtext(side = 3, "B: Age 18, matched controls", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 1, k = 50, j = "m")
#     mtext(side = 3, "C: Age 50, men with asthma", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 50, j = "m")
#     mtext(side = 3, "D: Age 50, matched controls", adj = 0, font = 2)
# dev.off()
# 
# pdf(here::here("out/fig2_ast_women.pdf"), 13, 13)
# par(mar=c(4,2,3,5))
# par(mfrow = c(2,2))
#   dendo_plot(data_in = edj_asthma, i = 1, k = 18, j = "w")
#     mtext(side = 3, "A: Age 18, women with asthma", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 18, j = "w")
#     mtext(side = 3, "B: Age 18, matched controls", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 1, k = 50, j = "w")
#     mtext(side = 3, "C: Age 50, women with asthma", adj = 0, font = 2)
#   dendo_plot(data_in = edj_asthma, i = 0, k = 50, j = "w")
#     mtext(side = 3, "D: Age 50, matched controls", adj = 0, font = 2)
# dev.off()


# all networks ------------------------------------------------------------
plot_all_ntwks <- function(ii = 0, cc = "eczema", l = 1){
  par(mar = (c(3,0.5,3,0)+0.25))
  ntwk_plot(cohort = cc, i = ii, k = 18, j = "m")
    if(ii==1){
      mtext(side = 3, paste0(LETTERS[l],": Age 18, men ", cc), adj = 0, font = 2)
    }else{
      mtext(side = 3, paste0(LETTERS[l]), adj = 0, font = 2)
    }
  ntwk_plot(cohort = cc, i = ii, k = 18, j = "w")
    if(ii==1){
      mtext(side = 3, paste0(LETTERS[l+1],": Age 18, women ", cc), adj = 0, font = 2)
    }else{
      mtext(side = 3, paste0(LETTERS[l+1]), adj = 0, font = 2)
    }
  ntwk_plot(cohort = cc, i = ii, k = 50, j = "m")
    if(ii==1){
      mtext(side = 3, paste0(LETTERS[l+2],": Age 50, men ", cc), adj = 0, font = 2)
    }else{
      mtext(side = 3, paste0(LETTERS[l+2]), adj = 0, font = 2)
    }
  ntwk_plot(cohort = cc, i = ii, k = 50, j = "w")
    if(ii==1){
      mtext(side = 3, paste0(LETTERS[l+3],": Age 50, women ", cc), adj = 0, font = 2)
    }else{
      mtext(side = 3, paste0(LETTERS[l+3]), adj = 0, font = 2)
    }
}
pdf(here::here("out/fig4_ntwk_eczema_full.pdf"), 10, 10)
  par(mfcol = c(4,2))
  plot_all_ntwks(ii = 1, cc = "eczema")
  plot_all_ntwks(ii = 0, cc = "eczema",5)
dev.off()
pdf(here::here("out/fig4_ntwk_asthma_full.pdf"), 10, 10)
  par(mfcol = c(4,2))
  plot_all_ntwks(ii = 1, cc = "asthma")
  plot_all_ntwks(ii = 0, cc = "asthma",5)
dev.off()

pdf(here::here("out/fig4_ntwk_all.pdf"), 10, 10)
par(mfcol = c(4,4))
  plot_all_ntwks(ii = 1, cc = "eczema")
  plot_all_ntwks(ii = 0, cc = "eczema",5)
  plot_all_ntwks(ii = 1, cc = "asthma",10)
  plot_all_ntwks(ii = 0, cc = "asthma",14)
dev.off()
