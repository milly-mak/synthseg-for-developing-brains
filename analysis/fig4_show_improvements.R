library(tidyverse)
library(dplyr)

setwd("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/")

# Path to save figures to
basepath='/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/'
outpath=paste0(basepath,'/figs/')

pipeline_colorscale=c('#7D2D3BFF','#D6E055FF','#AB9ED4FF','#CB6F42FF')
pipeline_levels=c('vanilla','crop','resize','resize and crop')


################################################################################
#                        ANALYSIS: DICE VS QC SCORE                            #
################################################################################

QC_DICE_BCP = read.csv('other/QC.DICE.matched.regions.csv')
QC_DICE_BCP$pipeline = factor(QC_DICE_BCP$pipeline, levels=pipeline_levels)

QC_DICE_min = QC_DICE_BCP %>% 
  filter(clean_name != 'min' & clean_name != 'general csf') %>% 
  group_by(participant_id,session,pipeline) %>% 
  summarise(min_dice = min(dice), 
            min_qc = min(qc_score)) %>% 
  ungroup()

p9=QC_DICE_min %>% 
  ggplot(aes(y=min_dice, x=min_qc, color=pipeline))+
  geom_point(alpha=0.5, size=2)+
  theme_minimal()+
  xlab('Minimum QC score')+
  ylab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale)+
  theme(text = element_text(size=12))

qc_regions = unique(QC_DICE_BCP$clean_name)
qc_regions = qc_regions[-c(grep('min',qc_regions),grep('csf',qc_regions))]
pretty_labels=str_to_sentence(qc_regions)
QC_DICE_plots = list()
for (i in 1:length(qc_regions)) {
  df_i <- QC_DICE_BCP %>% 
    filter(clean_name == qc_regions[i]) #%>%
  dice_range=range(df_i$dice, na.rm = TRUE)
  limits=c(floor(dice_range[1]*10)/10, ceiling(dice_range[2]*10)/10)
  common_breaks <- pretty(dice_range, n = 3)
  
  QC_DICE_plots[[i]] <- df_i %>% 
    ggplot(aes(x = qc_score, y = dice, color = pipeline)) +
    geom_point(alpha=0.5, size=2) +
    geom_abline(intercept = 0, slope = 1) +
    scale_y_continuous(limits = limits, breaks = common_breaks)+
    scale_x_continuous(limits = limits,breaks = common_breaks)+
    theme_minimal() +
    xlab("QC score") +
    ylab("Dice score") +
    theme(text = element_text(size = 12))+
    ggtitle(pretty_labels[i])+
    labs(color='Pipeline')+
    scale_color_manual(values=pipeline_colorscale)+
    theme(text = element_text(size=12), legend.position='none')
}

blank_panel <- ggplot() +
  theme_void() 

p11 = ggarrange(QC_DICE_plots[[1]],QC_DICE_plots[[2]])
p12 = ggarrange(plotlist = list(ggarrange(QC_DICE_plots[[3]],QC_DICE_plots[[4]], QC_DICE_plots[[5]], nrow=1), 
                                ggarrange(blank_panel, QC_DICE_plots[[6]], QC_DICE_plots[[7]],blank_panel, 
                                          nrow=1, widths = c(0.5,1,1,0.5))), 
                nrow=2)

p13=ggarrange(p11,p12, nrow=1)

################################################################################
#                       ANALYSIS: LIFESPAN QC SCORES                           #
################################################################################


# Setup bins for later plot
qcbins=c(0,280,280+30, 280+90, 280+180, 280+270, 280+365, 280+365+180, 280+seq(2*365,35*365,365))
pretty_labels <- c("40wk","1m","3m","6m","9m","12m","18m","2y","5y","10y","18y")
bin_levels <- cut(qcbins[-1]-1, breaks=qcbins, right=FALSE, include.lowest=TRUE) %>% 
  levels()
# Pick only the age bins we want to label
selected_levels <- bin_levels[c(2,5,7,9,12,15,23,41)] 
selected_labels <- c("40w","6m","1y","2y","5y","10y","18y",'30y')

# Load in original SS data
ORIG = read.csv(paste0(basepath,'/other/lifespan.original.SS.scores.csv'))
ORIG$pipeline = 'original'

# Load in updated SS data
# Extend this list of studies as we process data
studies = c('HBCD','Calgary','BCP','BHRC','HCP-D','NSPN','dHCP','UCSD','ABCD')
NEW=list()
for (i in 1:length(studies)) {
  study=studies[i]
  demographics = read.csv(paste0('../../data/',study,'/BIDS/demographics.tsv'), sep='\t')
  demographics = demographics %>% select(participant_id,session,session,age_days_pma,site,dx)
  allfiles = Sys.glob(paste0('../../data/',study,'/BIDS/derivatives/synthseg-resize-and-crop/sub-*/ses-*/*/*_volumes-and-qc.csv'))
  allcsv = lapply(allfiles, function(x) read.csv(x))
  fullcsv = allcsv
  subject = unlist(lapply(fullcsv,function(x) str_split(basename(x$file),'_')[[1]][[1]]))
  session = unlist(lapply(fullcsv,function(x) str_split(basename(x$file),'_')[[1]][[2]]))
  STUDY=bind_rows(fullcsv)
  STUDY$study=study
  STUDY$participant_id = subject
  STUDY$session = session
  STUDY = STUDY %>% left_join(demographics)
  NEW[[i]]=STUDY
}
UPDATED = bind_rows(NEW)
UPDATED = UPDATED[,-grep('Unknown',colnames(UPDATED))]
colnames(UPDATED) = tolower(colnames(UPDATED))
UPDATED = UPDATED %>% 
  rowwise() %>%
  mutate(qc.min = min(c_across(starts_with("qc")), na.rm = TRUE)) %>%
  ungroup()

UPDATED$total.intracranial = rowSums(UPDATED[,colnames(UPDATED[,seq(2,100)])])
UPDATED$ID = paste0(UPDATED$study,'|',UPDATED$participant_id)
UPDATED$pipeline = 'updated'
UPDATED = UPDATED[,c("study","participant_id","age_days_pma","qc.min",
                     "dx" ,"session","total.intracranial","ID","pipeline")]


ALL = ORIG %>% full_join(UPDATED)

ALL <- ALL %>%
  group_by(pipeline,ID) %>%
  arrange(age_days_pma, .by_group = TRUE) %>%
  mutate(session_num = dense_rank(age_days_pma)) %>%
  ungroup()


ALL <- ALL %>% mutate(study = fct_reorder(study, age_days_pma, .fun = min))
ALL$study = factor(ALL$study, levels=levels(ALL$study), labels=gsub('OpenNeuro-','',as.character(levels(ALL$study))))

ALL <- ALL %>%
  filter(session_num == 1, dx %in% c("CN", "CN - Sibling has ASD")) %>%
  mutate(bin = cut(age_days_pma, breaks = qcbins, right = FALSE, include.lowest = TRUE))

# Bin-level % >= 0.65
PERC <- ALL %>%
  group_by(pipeline, bin) %>%
  summarise(perc = mean(qc.min >= 0.65, na.rm = TRUE), n = dplyr::n()) %>% 
  ungroup()

# One shared palette for 'study' used in both plots
study_levels <- levels(ALL$study)
custom_colorscale=scales::hue_pal()(length(study_levels))
custom_colorscale=paletteer::paletteer_d("khroma::nightfall")[-17]
study_colors_lifespan <- setNames(custom_colorscale, study_levels)

# Plot Original SynthSeg QC scores
p1 <- ALL %>%
  ggplot(aes(x = bin)) +
  # raw points per subject (jittered)
  geom_jitter(subset(ALL, pipeline=='original'), mapping=aes(y = qc.min),, color = 'grey', width = 0.2, height = 0, alpha = 0.6, size = 2) +
  geom_jitter(subset(ALL, pipeline=='updated'),  mapping=aes(y = qc.min, color = study), width = 0.2, height = 0, alpha = 0.6, size = 2) +
  scale_y_continuous(name = "SynthSeg QC Scores", limits = c(0, 1),breaks = seq(0, 1, 0.1), 
                     sec.axis = sec_axis(~ ., name = "Proportion ≥ 0.65", labels = scales::percent)) +
  scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2)) +
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  geom_hline(yintercept = 0.65, linetype = "dashed") +
  # New colorscale for percentage values
  ggnewscale::new_scale_color() +
  # Bin-level percentage (point + line)
  geom_line(data = PERC, aes(y = perc, group=pipeline,color=pipeline), linewidth = 0.6) +
  geom_point(data = PERC, aes(y = perc, group=pipeline,color=pipeline), size = 2.2) +
  scale_color_manual(values=c('grey60','black'), 
                     guide = guide_legend(title = "Pipeline", ncol=2)) +
  labs(x = "Post-menstrual age (binned)",color='Study') +
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10)
  )+
  ggtitle('SynthSeg QC scores in aggregated pediatric sample')



ggsave(ggarrange(p1,p13, nrow=2,heights=c(1.2,1)),
       filename =paste0(outpath,'fig4.png'), 
       bg='white', height=7, width=10)

ggsave(ggarrange(p1,p13, nrow=2,heights=c(1.2,1)),
       filename =paste0(outpath,'fig4.pdf'), 
       device = cairo_pdf,
       bg='white', height=7, width=10)

ALL = ALL %>% 
  group_by(pipeline, ID, age_days_pma) %>%
  mutate(run=seq(n())) %>%
  ungroup()

ALL_wide = ALL %>% 
  select(study, ID, total.intracranial, qc.min, age_days_pma, pipeline, run) %>% 
  pivot_wider(names_from = pipeline, values_from = c('qc.min','total.intracranial'))
  
p2 = ALL_wide %>% 
  ggplot(aes(x=qc.min_original,y=qc.min_updated, color=study))+
  geom_point()+
  scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2))+
  theme_minimal()+
  xlab('Original QC')+ylab('Updated QC')
  
p3 = ALL_wide %>% 
  ggplot(aes(x=total.intracranial_original,y=total.intracranial_updated, color=study))+
  geom_point()+
  geom_abline(intercept = 0, slope = 1, linetype='dashed')+
  scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2))+
  theme_minimal()+
  xlab('Original TIV')+ylab('Updated TIV')


ggsave(ggarrange(p2,p3, common.legend = T, legend = 'right'),
       filename =paste0(outpath,'supplementary/SI_fig_correlation-qc-scores.png'), 
       bg='white', height=3.5, width=9)

ggsave(ggarrange(p2,p3, common.legend = T, legend = 'right'),
       filename =paste0(outpath,'supplementary/SI_fig_correlation-qc-scores.pdf'), 
       device = cairo_pdf,
       bg='white', height=3.5, width=9)

