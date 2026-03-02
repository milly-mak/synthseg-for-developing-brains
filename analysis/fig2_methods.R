
basepath = '/rds/project/kw350/rds-kw350-meld/growthcharts/'
outpath=paste0(basepath,'dev/BOPS/figs/')
lbcc_installation=paste0(basepath,'/tools/LBCC-lifespan-models/')
SSr_tool_path=paste0(basepath,'/tools/SynthSeg-resize-and-crop/')


source(paste0(lbcc_installation,"100.common-variables.r"))
source(paste0(lbcc_installation,"102.gamlss-recode.r"))
source(paste0(lbcc_installation,"300.variables.r"))
source(paste0(lbcc_installation,"301.functions.r"))

FIT <- readRDS(paste0(lbcc_installation, "Share/RefittedModels/FIT_TCV.rds"))

POP.CURVE.LIST <- list(AgeTransformed=seq(log(90),log(365*102),length.out=2^7),sex=c("Female","Male"))
POP.CURVE.RAW <- do.call( what=expand.grid, args=POP.CURVE.LIST )

CURVE <- Apply.Param(NEWData=POP.CURVE.RAW, FITParam=FIT$param )

# Sex colors
sex_colors <- c("#D11807FF","#9DCCEFFF")  # teal vs red

p1 = CURVE %>%
  ggplot(aes(x=AgeTransformed,y=PRED.m500.pop, color=sex))+
  geom_smooth()+
  #geom_smooth(data=CURVE, aes(x=AgeTransformed,y=PRED.u975.pop, color=sex), linetype='dashed')+
  #geom_smooth(data=CURVE, aes(x=AgeTransformed,y=PRED.l025.pop, color=sex), linetype='dashed')+
  theme_minimal()+
  labs(color='')+
  ylab('TCV')+xlab('Age')+
  scale_x_continuous(breaks = log(280+c(0,180,1*365,5*365,18*365,30*365,80*365)),
                     labels = c('40w','6m','1y','5y','18y','30y','80y'), limits = c(log(280), log(100*365)))+
  ggtitle('Normative trajectory of TCV')+
  theme(text = element_text(size=12))+
  scale_color_manual(values=sex_colors)

scaling_factor=read.csv(paste0(SSr_tool_path,'scaling-factor.csv'))

p2 = scaling_factor %>% 
   filter(age_days>=270) %>%
   ggplot(aes(x=log(age_days), y=scalefactor_adj_perc500))+
   geom_point()+
   scale_x_continuous(breaks=log(280+c(0,180,1*365,5*365,18*365,30*365,80*365)),
                      labels=c('40w','6m','1y','5y','18y','30y','80y'))+
   theme_minimal()+
   theme(text = element_text(size=12))+
   ylab('Scaling factor') + xlab('Age')+
   ggtitle('Scaling factor')


p3=ggarrange(p1,p2, widths=c(1.2,1))
ggsave(p3,filename = paste0(outpath,'fig2.png'), bg='white', height = 3, width=10)
ggsave(p3,filename = paste0(outpath,'fig2.pdf'),  device = cairo_pdf,bg='white', height = 3, width=10)


  