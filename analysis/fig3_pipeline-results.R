library(readr)
library(dplyr)
library(stringr)
library(purrr)
library(emmeans)

setwd("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/code/")

# Path to save figures to
basepath='/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/'
outpath=paste0(basepath,'/figs/')

pipeline_colorscale=c('#7D2D3BFF','#D6E055FF','#AB9ED4FF','#CB6F42FF')
pipeline_levels=c('vanilla','crop','resize','resize and crop')

################################################################################
#                      READ IN REGIONAL DICE SCORES                           #
################################################################################

aggregate_dice = function(files, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores\\.csv$"){
  combined <- map_dfr(files, \(f) {
    m <- str_match(f, pat)
    read_csv(f, show_col_types = FALSE) %>%
      mutate(
        subject  = m[2],
        session  = m[3],
        file     = f,
        .before = 1
      )
  })
  return(combined)
}

path_vanilla = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_dice-scores-BOPS-labels.csv')
path_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/sub-*/ses-*/*_dice-scores-BOPS-labels.csv')
path_resize = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/sub-*/ses-*/*/*_dice-scores-BOPS-labels.csv')
path_resize_and_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_dice-scores-BOPS-labels.csv')

DICE_vanilla = aggregate_dice(path_vanilla, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_vanilla$pipeline='vanilla'
DICE_vanilla = DICE_vanilla[,c('subject','session','name','dice','pipeline')]

DICE_crop = aggregate_dice(path_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_crop$pipeline='crop'
DICE_crop = DICE_crop[,c('subject','session','name','dice','pipeline')]

DICE_resize = aggregate_dice(path_resize, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_resize$pipeline='resize'
DICE_resize = DICE_resize[,c('subject','session','name','dice','pipeline')]

DICE_resize_and_crop = aggregate_dice(path_resize_and_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_resize_and_crop$pipeline='resize and crop'
DICE_resize_and_crop = DICE_resize_and_crop[,c('subject','session','name','dice','pipeline')]

DICE_all = DICE_vanilla %>% full_join(DICE_crop) %>% full_join(DICE_resize) %>% full_join(DICE_resize_and_crop) 
colnames(DICE_all)[1] = 'participant_id'
DICE_all$pipeline = factor(DICE_all$pipeline, levels=pipeline_levels)

################################################################################
#                        READ IN SYNTHSEG QC SCORES                            #
################################################################################

QC_vanilla = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/BOPS_SS-volumes-qc-scores.csv')
QC_vanilla = QC_vanilla[,c(c('participant_id','session','subject'),colnames(QC_vanilla)[grep('qc.',colnames(QC_vanilla))])]
QC_vanilla$pipeline = 'vanilla'

QC_crop = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/BOPS_SS-volumes-qc-scores.csv')
QC_crop = QC_crop[,c(c('participant_id','session','subject'),colnames(QC_crop)[grep('qc.',colnames(QC_crop))])]
QC_crop$pipeline = 'crop'

QC_resize = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/BOPS_SS-volumes-qc-scores.csv')
QC_resize = QC_resize[,c(c('participant_id','session','subject'),colnames(QC_resize)[grep('qc.',colnames(QC_resize))])]
QC_resize$pipeline = 'resize'

QC_resize_and_crop = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/BOPS_SS-volumes-qc-scores.csv')
QC_resize_and_crop = QC_resize_and_crop[,c(c('participant_id','session','subject'),colnames(QC_resize_and_crop)[grep('qc.',colnames(QC_resize_and_crop))])]
QC_resize_and_crop$pipeline = 'resize and crop'

QC_all = QC_vanilla %>% full_join(QC_crop) %>% full_join(QC_resize) %>% full_join(QC_resize_and_crop)
QC_all$pipeline = factor(QC_all$pipeline, levels=pipeline_levels)

################################################################################
#                        READ IN BROAD DICE SCORES                             #
################################################################################
# We re-estimated DICE scores for labels that match broader regions that QC scores are calculated in
path_qc_vanilla = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_dice-scores-qc-labels.csv')
path_qc_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/sub-*/ses-*/*_dice-scores-qc-labels.csv')
path_qc_resize = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/sub-*/ses-*/*/*_dice-scores-qc-labels.csv')
path_qc_resize_and_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_dice-scores-qc-labels.csv')

DICE_QC_vanilla = aggregate_dice(path_qc_vanilla, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_vanilla$pipeline='vanilla'
DICE_QC_vanilla = DICE_QC_vanilla[,c('subject','session','name','dice','pipeline')]

DICE_QC_crop = aggregate_dice(path_qc_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_crop$pipeline='crop'
DICE_QC_crop = DICE_QC_crop[,c('subject','session','name','dice','pipeline')]

DICE_QC_resize = aggregate_dice(path_qc_resize, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_resize$pipeline='resize'
DICE_QC_resize = DICE_QC_resize[,c('subject','session','name','dice','pipeline')]

DICE_QC_resize_and_crop = aggregate_dice(path_qc_resize_and_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_resize_and_crop$pipeline='resize and crop'
DICE_QC_resize_and_crop = DICE_QC_resize_and_crop[,c('subject','session','name','dice','pipeline')]

DICE_QC_all = DICE_QC_vanilla %>% full_join(DICE_QC_crop) %>% full_join(DICE_QC_resize) %>% full_join(DICE_QC_resize_and_crop) 
colnames(DICE_QC_all)[1] = 'participant_id'
DICE_QC_all$pipeline = factor(DICE_QC_all$pipeline, levels=pipeline_levels)


################################################################################
#                          ANALYSIS: QC SCORES                                 #
################################################################################

# m2.qc = lme(qc_min~pipeline, random=(~1|participant_id),data = QC_all)
# anova(m2.qc)
# m2.pipeline.pairs = as.data.frame(emmeans(m2.qc, pairwise ~ pipeline, adjust="tukey")$contrasts)
# m2.pipeline.pairs$p.fdr = p.adjust(m2.pipeline.pairs$p.value, method='fdr')

QC_all <- QC_all %>%
  rowwise() %>%
  mutate(qc_min = min(across(starts_with("qc.")), na.rm = TRUE)) %>%
  ungroup()


p1 = QC_all %>% 
  ggplot(aes(x=pipeline, y=qc_min, color=pipeline))+
  geom_boxplot()+
  geom_jitter()+
  geom_hline(yintercept = 0.65, linetype='dashed')+
  theme_minimal()+
  ylab('Minimum QC score')+xlab('Pipeline')+
  theme(text=element_text(size=12), legend.position = 'none')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale)

################################################################################
#                    ANALYSIS: REGIONALLY MATCHED DICE                         #
################################################################################

DICE_QC = DICE_QC_all %>% 
  filter(name != 'qc.general.csf') %>% 
  group_by(pipeline, participant_id, session) %>% 
  summarise(dice_min=min(dice, na.rm=T))

p2 = DICE_QC %>%
  ggplot(aes(x=pipeline, y=dice_min, color=pipeline))+
  geom_boxplot(outliers = FALSE)+
  geom_jitter()+
  theme_minimal()+
  ylab('Minimum Dice score')+xlab('Pipeline')+
  labs(color='Pipeline')+
  theme(text=element_text(size=12), legend.position = 'none')+
  scale_color_manual(values=pipeline_colorscale)

# m1.dice = lme(median_dice~pipeline, random=(~1|participant_id),data = DICE_all_summary)
# anova(m1.dice)
# emm <- emmeans(m1.dice, ~ pipeline)
# m1.pipeline.pairs = as.data.frame(emmeans(m1.dice, pairwise ~ pipeline, adjust="tukey")$contrasts)
# m1.pipeline.pairs$p.fdr = p.adjust(m1.pipeline.pairs$p.value, method='fdr')

# Save out combined QC and Dice file

QC_all_wide = QC_all %>% 
  pivot_longer(cols = starts_with("qc"), names_to = 'name', values_to = 'qc_score'); QC_all_wide= QC_all_wide[,-3]

QC_DICE_combined = QC_all_wide %>% full_join(DICE_QC_all)
QC_DICE_combined$clean_name = gsub('\\.',' ',gsub('qc.','',QC_DICE_combined$name))
write.csv(QC_DICE_combined,'../other/QC.DICE.matched.regions.csv', row.names = F)

################################################################################
#                           ANALYSIS: BY AGE                                   #
################################################################################

demographics=read.table('BCP-pipeline-testing/all-T1s.tsv', header = T)

QC_DICE_min = QC_DICE_combined %>% 
  filter(clean_name != 'min' & clean_name != 'general csf') %>% 
  group_by(participant_id,session,pipeline) %>% 
  summarise(min_dice = min(dice), 
            min_qc = min(qc_score)) %>% 
  ungroup()

ALL = QC_DICE_min %>% full_join(demographics)
ALL=ALL[-which(is.na(ALL$pipeline)),]

p3 = ALL %>% 
  select(participant_id,session,min_qc, pipeline,age_days_pma) %>% 
  distinct() %>% 
  ggplot(aes(x=age_days_pma,y=min_qc, color=pipeline))+
  geom_hline(yintercept = 0.65, linetype='dashed')+
  geom_point()+
  theme_minimal()+
  theme(text=element_text(size=12))+
  xlab('Age (in months)')+
  ylab('Minimum QC score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale)

p4 = ALL %>% 
  select(participant_id,session,min_dice, pipeline,age_days_pma) %>% 
  distinct() %>% 
  ggplot(aes(x=age_days_pma,y=min_dice, color=pipeline))+
  geom_point()+
  theme_minimal()+
  theme(text=element_text(size=12))+
  xlab('Age (in months)')+
  ylab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale)


p5 = ALL %>% 
  filter(pipeline=='resize' | pipeline == 'resize and crop') %>%
  ggplot(aes(x=min_dice,y=min_qc, color=pipeline))+
  geom_point()+
  theme_minimal()+
  geom_abline(intercept = 0, slope=1, linetype='dashed')+
  theme(text=element_text(size=12))+
  ylab('Minimum QC score')+
  xlab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale[3:4])


ALL_wide = ALL %>% 
  filter(pipeline != 'crop') %>%
  #filter(pipeline=='vanilla' | pipeline =='resize and crop') %>% 
  pivot_wider(names_from = pipeline, values_from = c('min_dice','min_qc')) %>% 
  select(participant_id,session,min_dice_vanilla,min_dice_resize,`min_dice_resize and crop`, min_qc_vanilla, min_qc_resize, `min_qc_resize and crop`)

ALL_diff_long <- ALL_wide %>%
  mutate(
    dice_resize = min_dice_resize - min_dice_vanilla,
    dice_resizecrop = `min_dice_resize and crop` - min_dice_vanilla,
    
    qc_resize = min_qc_resize - min_qc_vanilla,
    qc_resizecrop = `min_qc_resize and crop` - min_qc_vanilla
  ) %>%
  select(participant_id, session,
         dice_resize, dice_resizecrop,
         qc_resize, qc_resizecrop) %>%
  pivot_longer(
    cols = -c(participant_id, session),
    names_to = c("metric", "pipeline"),
    names_sep = "_"
  ) %>%
  pivot_wider(
    names_from = metric,
    values_from = value
  )

ALL_diff_long$pipeline = factor(ALL_diff_long$pipeline, labels=c('resize', 'resize and crop'))

p6 = ALL_diff_long %>% 
  ggplot(aes(y=dice, x=qc, color=pipeline))+
  geom_point()+
  #geom_abline(intercept = 0, slope=1)+
  xlim(c(-0.3,0.8))+ylim(c(-0.3,0.8))+
  theme_minimal()+
  ylab(expression(Delta*DICE))+
  xlab(expression(Delta*QC))+
  geom_vline(xintercept = 0, linetype='dashed')+
  geom_hline(yintercept = 0, linetype='dashed')+
  scale_color_manual(values = pipeline_colorscale[c(3,4)])


blank_panel <- ggplot() +
  theme_void() 

# p7 = ggarrange(
#   ggarrange(
#     ggarrange(p1, p2, ncol = 1),
#     ggarrange(p3,p4, ncol = 1, common.legend = TRUE, legend = "right"),
#     ncol = 2,widths = c(0.8, 1)
#   ),
#   ggarrange(blank_panel,p5,blank_panel, nrow=1, widths=c(0.6,1,0.6), legend = 'none'),
#   nrow = 2,heights = c(2, 1)
# )

p7 = ggarrange(
  ggarrange(
    ggarrange(p1, p2, nrow = 1),
    ggarrange(p3,p4, nrow = 1, common.legend = TRUE, legend = "bottom"),
    nrow = 2
  ),
  ggarrange(p5,p6, nrow=1, legend = 'none'),
  nrow = 2,heights = c(2.3, 1)
)

# p7 = ggarrange(
#   ggarrange(
#     ggarrange(p1,p2, ncol = 1),
#     ggarrange(p3,p4, ncol = 1, common.legend = TRUE, legend = "right"),
#     ncol = 2,widths = c(0.8, 1)
#   ),
#   ggarrange(p5,p6,blank_panel,legend = 'none', widths = c(1,1,0.3),nrow=1),
#   nrow = 2,heights = c(2, 1)
# )

ggsave(p7, filename = paste0(outpath,'fig3.png'), bg='white', height = 10, width=10)
ggsave(p7, filename = paste0(outpath,'fig3.pdf'), device = cairo_pdf, bg='white', height = 10, width=10)


################################################################################
#                     ANALYSIS: REGIONAL DICE SCORE                            #
################################################################################

DICESUMMARY_ROI = DICE_all %>% 
  filter(name != 'CSF') %>%
  group_by(pipeline,name) %>% 
  summarise(mean_dice=mean(dice, na.rm=T))

write.csv(DICESUMMARY_ROI, file = '../other/regional_dice_dk.csv', row.names=F)

region_order <- DICESUMMARY_ROI %>%
  group_by(name) %>%
  summarise(med_dice = median(mean_dice, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(med_dice)) %>% 
  pull(name)

heat_df <- DICESUMMARY_ROI %>%
  mutate(region = factor(name, levels = region_order))

# Heatmap
p8 = heat_df %>%
  filter(region != 'Left-Cerebral-Exterior', 
         region != 'Left-Cerebellum-Exterior',
         region != 'Vermis',
         region != 'WM-hypointensities',
         region != 'Right-vessel', region != 'Left-vessel',
         region != 'Optic-Chiasm',
         region != 'Right-choroid-plexus', region != 'Left-choroid-plexus') %>% 
  ggplot(aes(x = pipeline, y = region, fill = mean_dice)) +
  geom_tile() +
  scale_fill_gradientn(name = "Dice\ncoefficient",
                       colours = (paletteer::paletteer_d("beyonce::X41")),
                       #colours= paletteer::paletteer_c("pals::parula", n=1000),
                       lim=c(0.4,1),na.value = 'grey') +
  labs(x = "", y = "") +
  ggtitle('Dice coefficient ground truth vs automated segmentation')+
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 40, hjust = 1, size=12),
    axis.text.y = element_text(size=12),
    panel.grid = element_blank(),
    text = element_text(size=12),
    plot.title = element_text(hjust = 0.7, vjust = 1),
    legend.title = element_text(margin = margin(b = 7, t = 7, r = 7, l = 7), size=12)
  )

ggsave(p8,filename = paste0(outpath,'supplementary/SI_fig_regional-dice.png'), bg='white', height = 7, width=7)
ggsave(p8,filename = paste0(outpath,'supplementary/SI_fig_regional-dice.pdf'), device = cairo_pdf, bg='white', height = 7, width=7)









