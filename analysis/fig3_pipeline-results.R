library(readr)
library(dplyr)
library(stringr)
library(purrr)
library(emmeans)
library(tidyr)
library(paletteer)
library(ggplot2)
library(ggpubr)
library(png)
library(grid)
library(ggridges)


setwd("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/code/")

# Path to save figures to
basepath='/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/'
outpath=paste0(basepath,'/figs/')

pipeline_colorscale=c('#92c75a','#7D2D3BFF','#AB9ED4FF','#CB6F42FF') ##D6E055FF
pipeline_levels=c('original','crop','rescale','rescale+crop')
#pipeline_labels=c('original','crop','rescale','rescale and crop')

################################################################################
#                      READ IN REGIONAL DICE SCORES                            #
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

path_original = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_T1w_dice-scores-BOPS-labels.csv')
path_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/sub-*/ses-*/*_dice-scores-BOPS-labels.csv')
path_rescale = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/sub-*/ses-*/*/*_dice-scores-BOPS-labels.csv')
path_rescale_and_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_T1w_dice-scores-BOPS-labels.csv')

DICE_original = aggregate_dice(path_original, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_original$pipeline='original'
DICE_original = DICE_original[,c('subject','session','name','dice','pipeline')]

DICE_crop = aggregate_dice(path_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_crop$pipeline='crop'
DICE_crop = DICE_crop[,c('subject','session','name','dice','pipeline')]

DICE_rescale = aggregate_dice(path_rescale, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_rescale$pipeline='rescale'
DICE_rescale = DICE_rescale[,c('subject','session','name','dice','pipeline')]

DICE_rescale_and_crop = aggregate_dice(path_rescale_and_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-BOPS-labels\\.csv$"); DICE_rescale_and_crop$pipeline='rescale+crop'
DICE_rescale_and_crop = DICE_rescale_and_crop[,c('subject','session','name','dice','pipeline')]

DICE_all = DICE_original %>% full_join(DICE_crop) %>% full_join(DICE_rescale) %>% full_join(DICE_rescale_and_crop) 
colnames(DICE_all)[1] = 'participant_id'
DICE_all$pipeline = factor(DICE_all$pipeline, levels=pipeline_levels)

# visually assessed that the registration of BOPS into BCP space wasnt good for this subject
DICE_all = DICE_all %>% filter(! (participant_id == 'sub-372377' & session=='ses-2mo'))


################################################################################
#                        READ IN SYNTHSEG QC SCORES                            #
################################################################################

QC_original = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/BOPS_SS-volumes-qc-scores.csv')
QC_original = QC_original[,c(c('participant_id','session','subject'),colnames(QC_original)[grep('qc.',colnames(QC_original))])]
QC_original$pipeline = 'original'

QC_crop = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/BOPS_SS-volumes-qc-scores.csv')
QC_crop = QC_crop[,c(c('participant_id','session','subject'),colnames(QC_crop)[grep('qc.',colnames(QC_crop))])]
QC_crop$pipeline = 'crop'

QC_rescale = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/BOPS_SS-volumes-qc-scores.csv')
QC_rescale = QC_rescale[,c(c('participant_id','session','subject'),colnames(QC_rescale)[grep('qc.',colnames(QC_rescale))])]
QC_rescale$pipeline = 'rescale'

QC_rescale_and_crop = read.csv('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/BOPS_SS-volumes-qc-scores.csv')
QC_rescale_and_crop = QC_rescale_and_crop[,c(c('participant_id','session','subject'),colnames(QC_rescale_and_crop)[grep('qc.',colnames(QC_rescale_and_crop))])]
QC_rescale_and_crop$pipeline = 'rescale+crop'

QC_all = QC_original %>% full_join(QC_crop) %>% full_join(QC_rescale) %>% full_join(QC_rescale_and_crop)
QC_all$pipeline = factor(QC_all$pipeline, levels=pipeline_levels)

# visually assessed that the registration of BOPS into BCP space wasnt good for this subject
QC_all = QC_all %>% filter(! (participant_id == 'sub-372377' & session=='ses-2mo'))

################################################################################
#                        READ IN BROAD DICE SCORES                             #
################################################################################
# We re-estimated DICE scores for labels that match broader regions that QC scores are calculated in
path_qc_original = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_T1w_dice-scores-qc-labels.csv')
path_qc_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/sub-*/ses-*/*_dice-scores-qc-labels.csv')
path_qc_rescale = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/sub-*/ses-*/*/*_dice-scores-qc-labels.csv')
path_qc_rescale_and_crop = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_T1w_dice-scores-qc-labels.csv')

DICE_QC_original = aggregate_dice(path_qc_original, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_original$pipeline='original'
DICE_QC_original = DICE_QC_original[,c('subject','session','name','dice','pipeline')]

DICE_QC_crop = aggregate_dice(path_qc_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_crop$pipeline='crop'
DICE_QC_crop = DICE_QC_crop[,c('subject','session','name','dice','pipeline')]

DICE_QC_rescale = aggregate_dice(path_qc_rescale, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_rescale$pipeline='rescale'
DICE_QC_rescale = DICE_QC_rescale[,c('subject','session','name','dice','pipeline')]

DICE_QC_rescale_and_crop = aggregate_dice(path_qc_rescale_and_crop, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_rescale_and_crop$pipeline='rescale+crop'
DICE_QC_rescale_and_crop = DICE_QC_rescale_and_crop[,c('subject','session','name','dice','pipeline')]

DICE_QC_all = DICE_QC_original %>% full_join(DICE_QC_crop) %>% full_join(DICE_QC_rescale) %>% full_join(DICE_QC_rescale_and_crop) 
colnames(DICE_QC_all)[1] = 'participant_id'
DICE_QC_all$pipeline = factor(DICE_QC_all$pipeline, levels=pipeline_levels)

# visually assessed that the registration of BOPS into BCP space wasnt good for this subject
DICE_QC_all = DICE_QC_all %>% filter(! (participant_id == 'sub-372377' & session=='ses-2mo'))


################################################################################
#                        READ IN T1 vs T2 SCORES                               #
################################################################################

path_qc_original_T1 = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_T1w_dice-scores-qc-labels.csv')
path_qc_original_T2 = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/sub-*/ses-*/*_T2w_dice-scores-qc-labels.csv')

DICE_QC_original_T1 = aggregate_dice(path_qc_original_T1, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_original_T1$pipeline='original'; DICE_QC_original_T1$modality='T1'
DICE_QC_original_T1 = DICE_QC_original_T1[,c('subject','session','name','dice','pipeline', 'modality')] 

DICE_QC_original_T2 = aggregate_dice(path_qc_original_T2, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_original_T2$pipeline='original'; DICE_QC_original_T2$modality='T2'
DICE_QC_original_T2 = DICE_QC_original_T2[,c('subject','session','name','dice','pipeline', 'modality')]


path_qc_rescale_and_crop_T1 = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_T1w_dice-scores-qc-labels.csv')
path_qc_rescale_and_crop_T2 = Sys.glob('BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/sub-*/ses-*/*/*_T2w_dice-scores-qc-labels.csv')

DICE_QC_rescale_and_crop_T1 = aggregate_dice(path_qc_rescale_and_crop_T1, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_rescale_and_crop_T1$pipeline='rescale+crop'; DICE_QC_rescale_and_crop_T1$modality='T1'
DICE_QC_rescale_and_crop_T1 = DICE_QC_rescale_and_crop_T1[,c('subject','session','name','dice','pipeline', 'modality')]

DICE_QC_rescale_and_crop_T2 = aggregate_dice(path_qc_rescale_and_crop_T2, pat="^.*/(sub-[^_]+)_(ses-[^_]+)_(.+)_dice-scores-qc-labels\\.csv$"); DICE_QC_rescale_and_crop_T2$pipeline='rescale+crop'; DICE_QC_rescale_and_crop_T2$modality='T2'
DICE_QC_rescale_and_crop_T2 = DICE_QC_rescale_and_crop_T2[,c('subject','session','name','dice','pipeline', 'modality')]


DICE_T1_T2 = DICE_QC_original_T1 %>% full_join(DICE_QC_original_T2) %>% full_join(DICE_QC_rescale_and_crop_T1) %>% full_join(DICE_QC_rescale_and_crop_T2) 
colnames(DICE_T1_T2)[1] = 'participant_id'
DICE_T1_T2$pipeline = factor(DICE_T1_T2$pipeline, levels=pipeline_levels)

# visually assessed that the registration of BOPS into BCP space wasnt good for this subject
DICE_T1_T2 = DICE_T1_T2 %>% filter(! (participant_id == 'sub-372377' & session=='ses-2mo'))


################################################################################
#                 PIPELINE ANALYSIS: QC SCORES (B)                             #
################################################################################

QC_all <- QC_all %>%
  rowwise() %>%
  mutate(qc_min = min(across(starts_with("qc.")), na.rm = TRUE)) %>%
  ungroup()

########## Filter out any scans that failed any of the 4 pipelines - 61 -> 56 scans
QC_all_filtered <- QC_all %>%
  select(participant_id, session, pipeline, qc_min) %>%
  pivot_wider(names_from="pipeline", values_from="qc_min") %>%
  filter(!is.na(`rescale+crop`) & !is.na(original) & !is.na(crop) & !is.na(rescale)) 

QC_all <- QC_all %>%
  dplyr::semi_join(QC_all_filtered, by = c("participant_id", "session"))


# for making p1 and p2 on local computer
saveRDS(QC_all, file = "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/QC_all.rds")


# B | pipeline X min QC (without axis break)
p1 = QC_all %>% 
  ggplot(aes(x=pipeline, y=qc_min, color=pipeline))+
  geom_jitter(alpha=0.6, size=2)+
  geom_boxplot(outlier.shape = NA)+
  geom_hline(yintercept = 0.65, linetype='dashed')+
  theme_minimal()+
  ylab('Minimum QC score')+xlab('Pipeline')+
  theme(text=element_text(size=12, face = "plain", family = ""), legend.position = 'none')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale) #+ 
  #ggbreak::scale_y_break(c(0.1, 0.3))


################################################################################
#               PIPELINE ANALYSIS: REGIONALLY MATCHED DICE (A)                 #
################################################################################

DICE_QC = DICE_QC_all %>% 
  filter(name != 'qc.general.csf') %>% 
  group_by(pipeline, participant_id, session) %>% 
  summarise(dice_min=min(dice, na.rm=T))

########## We decided to filter out any scans that failed any of the 4 pipelines - 61 -> 56 scans
DICE_QC_filtered <- DICE_QC %>%
  select(participant_id, session, pipeline, dice_min) %>%
  pivot_wider(names_from="pipeline", values_from="dice_min") %>%
  filter(!is.na(`rescale+crop`) & !is.na(original) & !is.na(crop) & !is.na(rescale)) 

DICE_QC <- DICE_QC %>%
  dplyr::semi_join(DICE_QC_filtered, by = c("participant_id", "session"))

DICE_QC_all <- DICE_QC_all %>%
  dplyr::semi_join(DICE_QC_filtered, by = c("participant_id", "session"))


# for making p1 and p2 on local computer
saveRDS(DICE_QC, file = "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/DICE_QC.rds")


# A | pipeline X min Dice (without axis break)
p2 = DICE_QC %>%
  ggplot(aes(x=pipeline, y=dice_min, color=pipeline))+
  geom_jitter(alpha=0.4, size=2)+
  geom_boxplot(outliers = FALSE)+
  theme_minimal()+
  ylab('Minimum Dice score')+xlab('Pipeline')+
  labs(color='Pipeline')+
  theme(text=element_text(size=12, face = "plain", family = ""), legend.position = 'none')+
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
#                    ANALYSIS: BY AGE (C + D)                                  #
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

# D | Age X Minimum QC score
p3 = ALL %>% 
  filter(pipeline=='original' | pipeline == 'rescale+crop') %>%
  select(participant_id,session,min_qc, pipeline,age_days_pma) %>% 
  distinct() %>% 
  ggplot(aes(x=age_days_pma,y=min_qc, color=pipeline))+
  geom_hline(yintercept = 0.65, linetype='dashed')+
  geom_point(alpha=0.5, size=2)+
  theme_minimal()+
  theme(text=element_text(size=12, face = "plain", family = ""), legend.position = 'bottom')+
  xlab('Age (in months)')+
  ylab('Minimum QC score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale[c(1,4)])+
  scale_x_continuous(breaks = 280+c(30, 90, 180,270,360),
                     labels = c("1m", "3m", "6m", "9m",'1y')) 

leg <- get_legend(p3)

# C | Age X Minimum dice score 
p4 = ALL %>% 
  filter(pipeline=='original' | pipeline == 'rescale+crop') %>%
  select(participant_id,session,min_dice, pipeline,age_days_pma) %>% 
  distinct() %>% 
  ggplot(aes(x=age_days_pma,y=min_dice, color=pipeline))+
  geom_point(alpha=0.5, size=2)+
  theme_minimal()+
  theme(text=element_text(size=12, face = "plain", family = ""))+
  xlab('Age (in months)')+
  ylab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale[c(1,4)])+
  scale_x_continuous(breaks = 280+c(30, 90, 180,270,360),
                     labels = c("1m", "3m", "6m", "9m",'1y')) 
                     

if (0) {
  p5 = ALL %>% 
  filter(pipeline=='rescale' | pipeline == 'rescale+crop') %>%
  ggplot(aes(x=min_dice,y=min_qc, color=pipeline))+
  geom_point(alpha=1)+
  theme_minimal()+
  geom_abline(intercept = 0, slope=1, linetype='dashed')+
  theme(text=element_text(size=12, face = "plain", family = ""))+
  ylab('Minimum QC score')+
  xlab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_color_manual(values=pipeline_colorscale[3:4]) 
} 


ALL_wide = ALL %>% 
  filter(pipeline != 'crop') %>%
  pivot_wider(names_from = pipeline, values_from = c('min_dice','min_qc')) %>% 
  select(participant_id,session,min_dice_original,min_dice_rescale,`min_dice_rescale+crop`, min_qc_original, min_qc_rescale, `min_qc_rescale+crop`)

ALL_diff_long <- ALL_wide %>%
  mutate(
    dice_rescale = min_dice_rescale - min_dice_original,
    dice_rescalecrop = `min_dice_rescale+crop` - min_dice_original,
    
    qc_rescale = min_qc_rescale - min_qc_original,
    qc_rescalecrop = `min_qc_rescale+crop` - min_qc_original
  ) %>%
  select(participant_id, session,
         dice_rescale, dice_rescalecrop,
         qc_rescale, qc_rescalecrop) %>%
  pivot_longer(
    cols = -c(participant_id, session),
    names_to = c("metric", "pipeline"),
    names_sep = "_"
  ) %>%
  pivot_wider(
    names_from = metric,
    values_from = value
  )

ALL_diff_long$pipeline = factor(ALL_diff_long$pipeline, labels=c('rescale', 'rescale+crop'))


################################################################################
#                    DICE vs QC SCORE IMPROVEMENTS (E)                         #
################################################################################

# old E: delta dice x delta qc
if (0) {
  p6 = ALL_diff_long %>% 
  ggplot(aes(y=dice, x=qc, color=pipeline))+
  geom_point(alpha=0.4, size=2)+
  #geom_abline(intercept = 0, slope=1)+
  xlim(c(-0.3,0.8))+ylim(c(-0.3,0.8))+
  theme_minimal()+
  theme(text=element_text(size=12, face = "plain", family = ""))+
  ylab(expression(Delta*DICE))+
  xlab(expression(Delta*QC))+
  geom_vline(xintercept = 0, linetype='dashed')+
  geom_hline(yintercept = 0, linetype='dashed')+
  scale_color_manual(values = pipeline_colorscale[c(3,4)])
}

# E | min QC X min DC, only for original and r&c
p5_new = ALL %>% 
  filter(pipeline=='original' | pipeline == 'rescale+crop') %>%
  ggplot(aes(x=min_dice,y=min_qc, color=pipeline))+
  geom_point(alpha=0.5, size=3)+
  theme_minimal()+
  geom_abline(intercept = 0, slope=1, linetype='dashed')+
  theme(text=element_text(size=12, face = "plain", family = ""))+
  ylab('Minimum QC score')+
  xlab('Minimum Dice score')+
  labs(color='Pipeline')+
  scale_y_continuous(limits = c(0,0.85))+ 
  scale_x_continuous(limits = c(0,0.85)) + 
  scale_color_manual(values = pipeline_colorscale[c(1,4)])

################################################################################
#          ANALYSIS: DICE VS QC SCORE BY QC CLASS / REGION (F)                 #
################################################################################

QC_DICE_min = QC_DICE_combined %>% 
  filter(clean_name != 'min' & clean_name != 'general csf') %>% 
  group_by(participant_id,session,pipeline) %>% 
  summarise(min_dice = min(dice), 
            min_qc = min(qc_score)) %>% 
  ungroup()


# removed 
if (0) {
  p9=QC_DICE_min %>% 
    ggplot(aes(y=min_dice, x=min_qc, color=pipeline))+
    geom_point(alpha=0.5, size=2)+
    theme_minimal()+
    xlab('Minimum QC score')+
    ylab('Minimum Dice score')+
    labs(color='Pipeline')+
    scale_color_manual(values=pipeline_colorscale)+
    theme(text = element_text(size=12))


qc_regions = unique(QC_DICE_combined$clean_name)
qc_regions = qc_regions[-c(grep('min',qc_regions),grep('csf',qc_regions))]
pretty_labels=str_to_sentence(qc_regions)
QC_DICE_combined$title_region = str_to_sentence(QC_DICE_combined$clean_name)
QC_DICE_plots = list()
for (i in 1:length(qc_regions)) {
  df_i <- QC_DICE_combined %>% 
    filter(clean_name == qc_regions[i]) #%>%
  dice_range=range(df_i$dice, na.rm = TRUE)
  limits=c(floor(dice_range[1]*10)/10, ceiling(dice_range[2]*10)/10)
  common_breaks <- pretty(dice_range, n = 3)
  
  QC_DICE_plots[[i]] <- df_i %>% 
    ggplot(aes(x = qc_score, y = dice, color = pipeline)) +
    geom_point(alpha=0.4, size=2) +
    geom_abline(intercept = 0, slope = 1) +
    scale_y_continuous(limits = limits, breaks = common_breaks)+
    scale_x_continuous(limits = limits,breaks = common_breaks)+
    theme_minimal() +
    xlab("QC score") +
    ylab("Dice score") +
    theme(text = element_text(size = 12, face = "plain", family = ""))+
    ggtitle(pretty_labels[i])+
    labs(color='Pipeline')+
    scale_color_manual(values=pipeline_colorscale)+
    theme(text = element_text(size=12, face = "plain", family = ""), 
          legend.position='none',
          plot.title = element_text(size = 12, face = "plain", family = ""))
}

p11 = ggarrange(QC_DICE_plots[[1]],QC_DICE_plots[[2]])

anchors <- df_plot_regional %>%
  group_by(clean_name) %>%
  summarise(
    lim_low  = floor(min(c(qc_score, dice), na.rm = TRUE) * 10) / 10,
    lim_high = ceiling(max(c(qc_score, dice), na.rm = TRUE) * 10) / 10,
    .groups = "drop"
  ) %>%
  pivot_longer(c(lim_low, lim_high), values_to = "v") %>%
  transmute(clean_name, qc_score = v, dice = v)

p12 = ggplot(df_plot_regional, aes(x = qc_score, y = dice, color = pipeline)) +
  geom_point(alpha = 0.4, size = 2) +
  geom_blank(data = anchors, aes(x = qc_score, y = dice), inherit.aes = FALSE) +
  geom_abline(intercept = 0, slope = 1) +
  facet_wrap(~title_region, scales = "free") +
  scale_color_manual(values = pipeline_colorscale) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  theme_minimal() +
  labs(x = "QC score", y = "Dice score", color = "Pipeline") +
  theme(
    text = element_text(size = 12, face = "plain", family = ""),
    legend.position = "none",
    strip.text = element_text(size = 12, face = "plain", family = "",
                              margin = margin(t = 0, b = 1)),
    panel.spacing = unit(0.6, "lines"),                           # tighter facet gaps
    plot.margin = margin(t = -2, b = 0),
    strip.background = element_blank()
  )

# blank_panel <- ggplot() +
#   theme_void() 

# p12 = ggarrange(plotlist = list(ggarrange(QC_DICE_plots[[3]],QC_DICE_plots[[4]], QC_DICE_plots[[5]], nrow=1), 
#                                 ggarrange(blank_panel, QC_DICE_plots[[6]], QC_DICE_plots[[7]],blank_panel, 
#                                           nrow=1, widths = c(0.5,1,1,0.5))), 
#                 nrow=2)
p13=ggarrange(p11,p12,widths=c(0.7,1), nrow=1)
}


df_plot_regional <- QC_DICE_combined %>% 
  filter(clean_name != "min", 
         clean_name != "general csf")

df_plot_regional$title_region = df_plot_regional$title_region %>% 
  str_replace("^(\\S+)\\s(\\S+)$","\\1 &\n\\2") %>% 
  str_replace("General", "General\n") 
df_plot_regional$title_region = factor(df_plot_regional$title_region, 
                                       levels=c('General\n grey matter', 'General\n white matter', 'Hippocampus &\namygdala','Putamen &\npallidum', 'Brainstem', 'Cerebellum', 'Thalamus' ))


# new F | Dice by region
p14 = df_plot_regional %>% 
  filter(pipeline == 'original' | pipeline == 'rescale+crop') %>%
  ggplot(aes(x = dice, y = title_region, color = pipeline, fill=pipeline)) +
  geom_density_ridges(alpha = 0.5, scale = 0.9) +
  scale_fill_manual(values = pipeline_colorscale[c(1,4)]) +
  scale_color_manual(values = pipeline_colorscale[c(1,4)]) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  scale_y_discrete(limits = rev) +
  theme_minimal() +
  theme(text=element_text(size=12, face = "plain", family = ""), 
    legend.position="none")+
  ylab('Region')+
  xlab('Minimum Dice score') 




######################## Statistics ########################

# Broader QC regions (Table S1)
df_plot_regional_stats <- df_plot_regional %>%
  filter(pipeline=="original" | pipeline=="rescale+crop") %>%
  select(participant_id, session, pipeline, dice, title_region) %>%
  pivot_wider(names_from="pipeline", values_from="dice") %>%
  filter(!is.na(`rescale+crop`) & !is.na(original)) %>%
  rename(rescale_crop=`rescale+crop`)

dice_regional_test <- df_plot_regional_stats %>%
  group_by(title_region) %>%
  summarise(
    p_value = t.test(
      as.numeric(rescale_crop),
      as.numeric(original),
      paired = TRUE
    )$p.value, 
    t_statistic = t.test(
      as.numeric(rescale_crop),
      as.numeric(original),
      paired = TRUE
    )$statistic
  ) %>%
  mutate(
    p_bonf = p.adjust(p_value, method = "bonferroni")
  ) 

write.csv(dice_regional_test, "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/supplementary/dice_regional_test_table.csv", row.names=FALSE)


# 30 Dice regions (Table S2)
DICE_all <- DICE_all %>%
  dplyr::semi_join(DICE_QC_filtered, by = c("participant_id", "session"))

`%nin%` <- negate(`%in%`)
DICE_all_stats <- DICE_all %>%
  filter(name %nin% c("Vermis", "Left-choroid-plexus", "Right-choroid-plexus", "CSF", "Left-Cerebral-Exterior", "Left-Cerebellum-Exterior", "Left-vessel", "Right-vessel", "WM-hypointensities", "Optic-Chiasm")) %>%
  filter(pipeline=="original" | pipeline=="rescale+crop") %>%
  filter(participant_id %in% DICE_QC_filtered$participant_id) %>%
  pivot_wider(names_from="pipeline", values_from="dice") %>%
  filter(!is.na(`rescale+crop`) & !is.na(original)) %>%
  rename(rescale_crop=`rescale+crop`)

dice_30regions_test <- DICE_all_stats %>%
  group_by(name) %>%
  summarise(
    p_value = t.test(
      as.numeric(rescale_crop),
      as.numeric(original),
      paired = TRUE
    )$p.value, 
    statistic = t.test(
      as.numeric(rescale_crop),
      as.numeric(original),
      paired = TRUE
    )$statistic
  ) %>%
  mutate(
    p_bonf = p.adjust(p_value, method = "bonferroni")
  )

write.csv(dice_30regions_test, "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/supplementary/dice_30regions_test_table.csv", row.names=FALSE)


##### Pairwise comparisons for DICE and QC, between all pipelines (Table 1) #####

## Repeated measures ANOVA: QC ##
anova_model_qc <- aov(qc_min ~ pipeline, data = QC_all)
summary(anova_model_qc)
# Check normal distribution
qqline(residuals(anova_model_qc))

QC_pairwise <- pairwise.t.test(QC_all$qc_min, QC_all$pipeline, paired = TRUE, p.adjust.method = "bonferroni")

# Make pairwise pipeline df 
groups <- unique(QC_all$pipeline)
pairs <- combn(groups, 2, simplify = FALSE) # make all pairwise combinations

df_results_qc <- lapply(pairs, function(p) { # paired t-test for each pair
  x <- QC_all$qc_min[QC_all$pipeline == p[1]]
  y <- QC_all$qc_min[QC_all$pipeline == p[2]]
  test <- t.test(y, x, paired = TRUE)
  data.frame(
    pipeline1 = p[1],
    pipeline2 = p[2],
    mean_diff_p2_p1 = mean(y - x),
    t_stat = test$statistic,
    p_value = test$p.value
  )
}) %>%
  bind_rows() %>%
  mutate(
    p_fdr = p.adjust(p_value, method = "BH"), 
    p_bonf = p.adjust(p_value, method = "bonferroni"))  

write.csv(df_results_qc, "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/supplementary/pipeline_pairwise_qc_table.csv", row.names=FALSE)


## Repeated measures ANOVA: Dice ##
anova_model_dice <- aov(dice_min ~ pipeline, data = DICE_QC)
summary(anova_model_dice)
# Check normal distribution
qqline(residuals(anova_model_dice))

DICE_pairwise <- pairwise.t.test(DICE_QC$dice_min, DICE_QC$pipeline, paired = TRUE, p.adjust.method = "bonferroni")

# Make pairwise pipeline df 
groups_dice <- unique(DICE_QC$pipeline)
pairs <- combn(groups_dice, 2, simplify = FALSE) # make all pairwise combinations

df_results_dice <- lapply(pairs, function(p) { # paired t-test for each pair
  x <- DICE_QC$dice_min[DICE_QC$pipeline == p[1]]
  y <- DICE_QC$dice_min[DICE_QC$pipeline == p[2]]
  test <- t.test(y, x, paired = TRUE)
  data.frame(
    pipeline1 = p[1],
    pipeline2 = p[2],
    mean_diff_p2_p1 = mean(y - x),
    t_stat = test$statistic,
    p_value = test$p.value
  )
}) %>%
  bind_rows() %>%
  mutate(
      p_fdr = p.adjust(p_value, method = "BH"), 
      p_bonf = p.adjust(p_value, method = "bonferroni"))  

write.csv(df_results_dice, "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/supplementary/pipeline_pairwise_dice_table.csv", row.names=FALSE)



##########  T1 vs T2 Analysis (Supplementary Figure S1) ##########
DICE_T1_T2_sum <- DICE_T1_T2 %>%
  filter(name != 'qc.general.csf') %>% 
  group_by(pipeline, modality, participant_id, session) %>% 
  summarise(dice_min=min(dice, na.rm=T))

# filter out NAs
DICE_T1_T2_wide <- DICE_T1_T2_sum %>%
  pivot_wider(names_from=c("pipeline", "modality"), values_from="dice_min") %>%
  filter(!is.na(`rescale+crop_T1`) & !is.na(original_T1) & !is.na(original_T2) & !is.na(`rescale+crop_T2`)) 

# T1 vs T2 DICE in original and in r&c
diff <- DICE_T1_T2_wide$original_T2 - DICE_T1_T2_wide$original_T1
qqnorm(diff)
qqline(diff)
diff <- DICE_T1_T2_wide$`rescale+crop_T2` - DICE_T1_T2_wide$`rescale+crop_T1`
qqnorm(diff)
qqline(diff)
diff <- DICE_T1_T2_wide$`rescale+crop_T2` - DICE_T1_T2_wide$original_T1
qqnorm(diff)
qqline(diff)

wilcox.test(DICE_T1_T2_wide$original_T2, DICE_T1_T2_wide$original_T1, paired=TRUE)
t.test(DICE_T1_T2_wide$`rescale+crop_T2`, DICE_T1_T2_wide$`rescale+crop_T1`, paired=TRUE)
t.test(DICE_T1_T2_wide$`rescale+crop_T2`, DICE_T1_T2_wide$original_T2, paired=TRUE)
t.test(DICE_T1_T2_wide$`rescale+crop_T1`, DICE_T1_T2_wide$original_T1, paired=TRUE)


#look at change in dice between pipelines:
DICE_T1_T2_wide <- DICE_T1_T2_wide %>% 
  mutate(T1_diff=`rescale+crop_T1`-original_T1, T2_diff=`rescale+crop_T2`-original_T2)
diff <- DICE_T1_T2_wide$T2_diff - DICE_T1_T2_wide$T1_diff
qqnorm(diff)
qqline(diff)
wilcox.test(DICE_T1_T2_wide$T2_diff, DICE_T1_T2_wide$T1_diff, paired=TRUE)


## Boxplots 
DICE_T1_T2_sum %>% filter(pipeline=="original") %>%
  ggplot(aes(x=modality, y=dice_min, color=modality))+
  geom_jitter(alpha=0.6, size=2)+
  geom_boxplot(outlier.shape = NA)+
  theme_minimal()

DICE_T1_T2_sum %>% filter(pipeline=="rescale+crop") %>%
  ggplot(aes(x=modality, y=dice_min, color=modality))+
  geom_jitter(alpha=0.6, size=2)+
  geom_boxplot(outlier.shape = NA)+
  theme_minimal()

# Change in dice (between pipelines) in T1 vs T2 - boxplot
DICE_T1_T2_wide %>% pivot_longer(cols=c("T1_diff", "T2_diff"), names_to="modality", values_to="dice_min") %>%
  ggplot(aes(x=modality, y=dice_min, color=modality))+
  geom_jitter(alpha=0.6, size=2)+
  geom_boxplot(outlier.shape = NA)+
  theme_minimal()+
  ylab('change in dice scores (updated minus original)')+xlab('modality')+
  labs(color='modality')

# All 4 combinations boxplot
DICE_T1_T2_longer <- DICE_T1_T2_wide %>% pivot_longer(cols=c("original_T1", "rescale+crop_T1", "original_T2","rescale+crop_T2"), names_to="pipeline_modality", values_to="dice_min")

t1_t2_plot <- DICE_T1_T2_longer %>%
  ggplot(aes(x=factor(pipeline_modality, levels = c("original_T1", "rescale+crop_T1", "original_T2", "rescale+crop_T2")), y=dice_min, color=pipeline_modality))+
  geom_jitter(alpha=0.6, size=2)+
  geom_boxplot(outlier.shape = NA)+
  theme_minimal() +
  ylab('Minimum Dice Score')+xlab('Pipeline / Modality')+
  labs(color='Pipeline / Modality')+
  scale_color_manual(values= c(
    "original_T1" = '#92c75a',
    "rescale+crop_T1" = '#CB6F42FF',
    "original_T2" = '#7dc6de',
    "rescale+crop_T2" = '#e34658' ), 
  labels = c( 
    "original_T1" = 'original / T1w',
    "rescale+crop_T1" = 'rescale+crop / T1w',
    "original_T2" = 'original / T2w',
    "rescale+crop_T2" = 'rescale+crop / T2w' )) + 
  scale_x_discrete(labels = c(
    "original_T1" = 'original / T1w',
    "rescale+crop_T1" = 'rescale+crop / T1w',
    "original_T2" = 'original / T2w',
    "rescale+crop_T2" = 'rescale+crop / T2w'))  +
  theme(legend.position="none", text=element_text(size=12, face = "plain", family = ""),
    plot.title = element_text(hjust = 0, margin = margin(t = 10, b = 10), size=15),
    plot.title.position = "plot", 
    plot.margin = margin(5.5, 5.5, 5.5, 5.5)) +
    ggtitle("Improved DICE scores on T1w and T2w scans")

ggsave(t1_t2_plot,filename = paste0(outpath,'supplementary/SI_fig_t1_t2_plot.png'), bg='white', height = 7, width=7)
ggsave(t1_t2_plot,filename = paste0(outpath,'supplementary/SI_fig_t1_t2_plot.pdf'), device = cairo_pdf, bg='white', height = 7, width=7)


# Adding age
DICE_T1_T2_wide_dems = DICE_T1_T2_wide %>% full_join(demographics) %>%
pivot_longer(cols=c("original_T1", "original_T2", "rescale+crop_T1", "rescale+crop_T2"), names_to="pipeline_modality", values_to="dice_min")

# Age x min dice in orig & r&c, but for T2 
t2_dice_age <- DICE_T1_T2_wide_dems %>% 
  filter(pipeline_modality=='original_T2' | pipeline_modality == 'rescale+crop_T2') %>%
  select(participant_id,session,dice_min, pipeline_modality,age_days_pma) %>% 
  distinct() %>% 
  ggplot(aes(x=age_days_pma,y=dice_min, color=pipeline_modality))+
  geom_point(alpha=0.5, size=2)+
  theme_minimal()+
  theme(text=element_text(size=12, face = "plain", family = ""))+
  xlab('Age (in months)')+
  ylab('Minimum Dice Score')+
  labs(color='Pipeline')+
  scale_color_manual(values=c("original_T2" = '#7dc6de',"rescale+crop_T2" = '#e34658'), 
    labels = c("original_T2" = 'original',"rescale+crop_T2" = 'rescale+crop'))+
  scale_x_continuous(breaks = 280+c(30, 90, 180,270,360),
                     labels = c("1m", "3m", "6m", "9m",'1y')) + 
  ggtitle("Dice improvements in young infants for T2w scans")

ggsave(t2_dice_age,filename = paste0(outpath,'supplementary/SI_fig_t2_age.png'), bg='white', height = 7, width=7)
ggsave(t2_dice_age,filename = paste0(outpath,'supplementary/SI_fig_t2_age.pdf'), device = cairo_pdf, bg='white', height = 7, width=7)


# p7 = ggarrange(
#   ggarrange(
#     ggarrange(p1, p2, ncol = 1),
#     ggarrange(p3,p4, ncol = 1, common.legend = TRUE, legend = "right"),
#     ncol = 2,widths = c(0.8, 1)
#   ),
#   ggarrange(blank_panel,p5,blank_panel, nrow=1, widths=c(0.6,1,0.6), legend = 'none'),
#   nrow = 2,heights = c(2, 1)
# )
# 
# p7 = ggarrange(
#   ggarrange(
#     ggarrange(p1, p2, nrow = 1),
#     ggarrange(p3,p4, nrow = 1, common.legend = TRUE, legend = "bottom"),
#     nrow = 2
#   ),
#   ggarrange(p5,p6, nrow=1, legend = 'none'),
#   nrow = 2,heights = c(2.3, 1)
# )

# p7 = ggarrange(
#   ggarrange(
#     ggarrange(p1,p2, ncol = 1),
#     ggarrange(p3,p4, ncol = 1, common.legend = TRUE, legend = "right"),
#     ncol = 2,widths = c(0.8, 1)
#   ),
#   ggarrange(p5,p6,blank_panel,legend = 'none', widths = c(1,1,0.3),nrow=1),
#   nrow = 2,heights = c(2, 1)
# )

# load in the locally edited p1 and p2 pngs
#img <- png::readPNG("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/p1.png")
#p1_img <- grid::rasterGrob(img, interpolate = TRUE)
#img_2 <- png::readPNG("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/p2.png")
#p2_img <- grid::rasterGrob(img_2, interpolate = TRUE)


################ Putting together figure 3 #################

blank_panel <- ggplot() +
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    axis.ticks = element_blank()
  )

title_theme <- theme(
  plot.title = element_text(hjust = 0, margin = margin(t = 10, b = 10), size=15),
  plot.title.position = "plot", 
  plot.margin = margin(5.5, 5.5, 5.5, 5.5)
)
blank_panel_with_legend_C <- blank_panel + labs(title = "A | Dice by pipeline") + title_theme
blank_panel_with_legend_D <- blank_panel + labs(title = "B | QC score by pipeline") + title_theme
p4_with_legend <- p4 + labs(title = "C | Dice improvement in young infants") + title_theme
p3_with_legend <- p3 + labs(title = "D | QC improvement in young infants") + title_theme
p5_with_legend <- p5_new + labs(title = "E | Improvements in Dice vs QC") + title_theme
p14_with_legend <- p14 + labs(title = "F | Dice improvement by region") + title_theme

fig3_final=ggarrange(
  ggarrange(blank_panel_with_legend_C, blank_panel_with_legend_D, nrow=1, legend="none"),
  ggarrange(p4_with_legend, p3_with_legend, nrow = 1,legend = "none"),
  ggarrange(p5_with_legend,p14_with_legend, nrow = 1,legend = 'none'), 
  leg,
  heights = c(1,1,1.5, 0.12),
  nrow = 4, 
  align="v"
)

ggsave(fig3_final, filename = paste0(outpath,'fig3.png'), bg='white', height = 9, width=10)
ggsave(fig3_final, filename = paste0(outpath,'fig3.pdf'), device = cairo_pdf, bg='white', height = 9, width=10)



####### ANALYSIS: REGIONAL DICE SCORE (removed)  

if (0) {
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

}
