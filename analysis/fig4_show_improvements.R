library(tidyverse)
library(dplyr)
library(ggpubr)
library(exact2x2)

setwd("/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/")

# Path to save figures to
basepath='/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/'
outpath=paste0(basepath,'/figs/')


################################################################################
#            LOAD IN RESCALE & CROP DATA FROM NEURODEV SAMPLE                  #
################################################################################

# Setup bins for later plot
qcbins=c(0,280,280+30, 280+90, 280+180, 280+270, 280+365, 280+365+180, 280+seq(2*365,35*365,365))
pretty_labels <- c("40pmw","1m","3m","6m","9m","12m","18m","2y","5y","10y","18y")
bin_levels <- cut(qcbins[-1]-1, breaks=qcbins, right=FALSE, include.lowest=TRUE) %>% 
  levels()
# Pick only the age bins we want to label
selected_levels <- bin_levels[c(2,5,7,9,12,15,23,41)] 
selected_labels <- c("40pmw","6m","1y","2y","5y","10y","18y",'30y')

# Load in original SS data
ORIG=read.csv('/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/other/final_ss_dataset.csv') 
  # this one is updated after reruns
ORIG$pipeline = 'original'

# Load in updated SS data
studies = c('ABCD','PNC','HCP','HBCD','Calgary','BCP','BHRC','HCP-D','NSPN','dHCP','UCSD','NIHPD','IBIS','OpenNeuro-Pixar','OpenNeuro-Wang','devCCNP')
NEW=list()
for (i in 1:length(studies)) {
  study=studies[i]
  demographics = read.csv(paste0('../../data/',study,'/BIDS/demographics.tsv'), sep='\t')
  demographics = demographics %>% 
    mutate(site = as.character(site)) %>%  # MM note: added because NIHPD site is an integer
    select(participant_id,session,age_days_pma,site,dx)
  allfiles = Sys.glob(paste0('../../data/',study,'/BIDS/derivatives/synthseg-resize-and-crop/sub-*/ses-*/*/*desc-native_volumes-and-qc.csv'))
  allcsv = lapply(allfiles, function(x) read.csv(x))
  fullcsv = allcsv[which(unlist(lapply(allcsv,nrow)) == 1)]
  subject = unlist(lapply(fullcsv,function(x) try(str_split(basename(x$subject),'_')[[1]][[1]])))
  session = unlist(lapply(fullcsv,function(x) try(str_split(basename(x$subject),'_')[[1]][[2]])))
  STUDY=bind_rows(fullcsv)
  STUDY$study=study
  STUDY$participant_id = subject
  STUDY$session = session
  STUDY = STUDY %>% left_join(demographics)
  NEW[[i]]=STUDY
}
UPDATED = bind_rows(NEW)
colnames(UPDATED) = tolower(colnames(UPDATED))
colnames(UPDATED)[104:111] = paste0('qc.',colnames(UPDATED)[104:111])

UPDATED = UPDATED %>% 
  rowwise() %>%
  mutate(qc.min = min(c_across(starts_with("qc")), na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(modality = ifelse(grepl("_T1w", subject), "T1w",
  ifelse(grepl("_T2w", subject), "T2w", NA))) 


UPDATED$total.intracranial = rowSums(UPDATED[,colnames(UPDATED[,seq(2,100)])])
UPDATED$ID = paste0(UPDATED$study,'|',UPDATED$participant_id)
UPDATED$pipeline = 'updated'

updated_fullqc = UPDATED[,c("study","participant_id","subject","age_days_pma","qc.general.white.matter",
                    "qc.general.grey.matter","qc.general.csf","qc.cerebellum", "qc.brainstem", "qc.thalamus", "qc.putamen.pallidum", "qc.hippocampus.amygdala", "qc.min",
                     "dx" ,"session","total.intracranial","ID","modality","pipeline")]

UPDATED = UPDATED[,c("study","participant_id","subject","age_days_pma","qc.min",
                     "dx" ,"session","total.intracranial","ID","modality","pipeline")]


write.csv(UPDATED, file = paste0(basepath,'/other/final_rescale-crop_dataset.csv'), row.names = F)

#load in csv to skip above section: 
file_path <- file.path(basepath,'other', 'final_rescale-crop_dataset.csv')
UPDATED <- read.csv(file_path)


# combine original and updated datasets
ALL = ORIG %>% full_join(UPDATED)

# we want all the sessions, but only 1 run per session per subject, and prioritise T1s if that sub/ses has it
ALL <- ALL %>%
  filter(dx %in% c("CN", "CN - Sibling has ASD")) %>%
  group_by(ID, age_days_pma, pipeline) %>%
  mutate(mod_priority = ifelse(modality == "T1w", 1, 2)) %>%
  arrange(mod_priority) %>%
  slice(1) %>% # keep one row per session, if there are multiple runs
  ungroup() %>%
  mutate(bin = cut(age_days_pma, breaks = qcbins, right = FALSE, include.lowest = TRUE))


ALL <- ALL %>% mutate(study = fct_reorder(study, age_days_pma, .fun = min))
ALL$study = factor(ALL$study, levels=levels(ALL$study), labels=gsub('OpenNeuro-','',as.character(levels(ALL$study))))


################################################################################
#            SS ORIGINAL vs R&C ANALYSIS: LIFESPAN QC SCORES                   #
################################################################################

#### summary between two pipelines
ALL_summary <- ALL %>%
  select(participant_id, session, bin, qc.min, pipeline, study) %>%
  pivot_wider(names_from=pipeline,values_from=qc.min)
ALL_summary <- ALL_summary %>%
  filter(!is.na(updated) & !is.na(original))

# ALL df now only includes sessions where there is both an original and an updated qc.min value
ALL <- ALL %>%
  dplyr::semi_join(ALL_summary, by = c("participant_id", "session"))


write.csv(ALL, file = paste0(basepath,'/other/final_all_dataset.csv'), row.names = F)
ALL=read.csv('/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/other/final_all_dataset.csv') # has a mix of T1s and T2s for dHCP and HBCD, other datasets only T1


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


# OLD: Plot Original SynthSeg QC scores
if (0) {
p1 <- ALL %>%
  ggplot(aes(x = bin)) +
  # raw points per subject (jittered)
  #geom_jitter(subset(ALL, pipeline=='original'), mapping=aes(y = qc.min),, color = 'grey', width = 0.2, height = 0, alpha = 0.2, size = 2) +
  geom_jitter(subset(ALL, pipeline=='updated'),  mapping=aes(y = qc.min, color = study), width = 0.2, height = 0, alpha = 0.2, size = 2) +
  #scale_y_continuous(name = "SynthSeg QC Scores", limits = c(0, 1),breaks = seq(0, 1, 0.1), 
  #                   sec.axis = sec_axis(~ ., name = "Proportion ≥ 0.65", labels = scales::percent)) +
  scale_y_continuous(name = "Proportion ≥ 0.65", limits = c(0, 1), breaks = seq(0, 1, 0.1), labels = scales::percent,
    sec.axis = sec_axis( ~ ., name = "SynthSeg QC Scores"))+
  #scale_color_manual(values = study, guide = guide_legend(title = "Dataset", ncol=2)) +
  guides(color = guide_legend(override.aes = list(alpha = 1), title = "Dataset", ncol=2))+
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  geom_hline(yintercept = 0.65, linetype = "dashed") + 
  annotate("text", x = Inf, y = 0.65, label = "Threshold to \nPass QC (0.65)", hjust = 1, vjust = 1.5, size = 3) +
  # New colorscale for percentage values
  ggnewscale::new_scale_color() +
  # Bin-level percentage (point + line)
  geom_line(data = PERC, aes(y = perc, group=pipeline,color=pipeline), linewidth = 0.6) +
  geom_point(data = PERC, aes(y = perc, group=pipeline,color=pipeline), size = 2.2) +
  scale_color_manual(values=c('black','#CB6F42FF'), 
                     guide = guide_legend(title = "Pipeline", ncol=2)) +
  labs(x = "Age (post-menstrual) (binned)",color='Study') +
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10)
  ) #+
  #ggtitle('SynthSeg QC scores in neurodevelopmental sample')

title_theme <- theme(
  plot.title = element_text(hjust = 0, margin = margin(t = 10, b = 10)),
  plot.title.position = "plot"
)
p1_with_legend <- p1 + labs(title = "B | SynthSeg QC scores in neurodevelopmental sample") + title_theme 

}

########## Plot original vs new SynthSeg QC scores (B + C) ##############

median_qc_bin_orig <- ORIG %>% group_by(bin) %>% summarise(median_qc = median(qc.min))
median_qc_bin_updated <- ALL %>% filter(pipeline=="updated") %>% group_by(bin) %>% summarise(median_qc = median(qc.min))

# Neurodev dataset QCs (B)
p1 <- ggplot(ALL, aes(x = bin)) +
  # raw points per subject (jittered)
  geom_jitter(subset(ALL, pipeline=='updated'),  mapping=aes(y = qc.min, color = study), width = 0.2, height = 0, alpha = 0.2, size = 2) +
  geom_hline(yintercept = 0.65, linetype = "dashed") +
  annotate("text", x = Inf, y = 0.65, label = "Threshold to \nPass QC (0.65)", hjust = 1, vjust = 1.5, size = 3) +
  # bin-level qc medians (point + line): black for updated and grey for new  
  geom_line(data = median_qc_bin_orig, aes(y = median_qc, group = 1), color = "#929292", alpha = 1, linewidth = 0.6) +
  geom_point(data = median_qc_bin_orig, aes(y = median_qc, group=bin), color = "#929292", alpha = 1, size = 1.5) +
  geom_line(data = median_qc_bin_updated, aes(y = median_qc, group = 1), color = "black", alpha = 0.8, linewidth = 0.6) +
  geom_point(data = median_qc_bin_updated, aes(y = median_qc, group=bin), color = "black", alpha = 0.8, size = 1.5) +
 #scale_color_manual(values = DF$study, guide = guide_legend(title = "Dataset", ncol=2)) +
  #scale_y_continuous(name = "SynthSeg QC scores", limits = c(0, 1),breaks = seq(0, 1, 0.1), sec.axis = sec_axis(~ ., name = "Proportion ≥ 0.65", labels = scales::percent)) +
  scale_y_continuous(name = "SynthSeg QC Scores", limits = c(0, 1), breaks = seq(0, 1, 0.1)) +
  guides(color = guide_legend(override.aes = list(alpha = 1), title = "Dataset", ncol=8, title.position="top"))+
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  labs(x = "Age (post-menstrual)(binned)",color='Study') +
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10), 
    legend.position = "bottom",
    legend.title = element_text(hjust = 0.5), 
    legend.key.width  = unit(0.2, "cm")
  )+
  ggtitle('SynthSeg QC scores in aggregated pediatric sample') 

# Proportion of dataset passing QC (C)
p1_separate <- ggplot(ALL, aes(x=bin)) +
  geom_line(data = PERC, aes(y = perc, group=pipeline,color=pipeline), linewidth = 0.6) +
  geom_point(data = PERC, aes(y = perc, group=pipeline,color=pipeline), size = 2) +
  scale_color_manual(values=c('#929292','black'), #values=c('black','#CB6F42FF'), 
                     guide = guide_legend(title = "Pipeline", ncol=2)) +
  labs(x = "Age (post-menstrual) (binned)",color='Study') +
  scale_y_continuous(name = "Proportion ≥ 0.65", limits = c(0, 1), breaks = seq(0, 1, 0.1), labels = scales::percent) +
  scale_x_discrete(breaks = selected_levels, labels = selected_labels) +
  labs(x = "Age (post-menstrual)(binned)") +
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10), 
    legend.position = "bottom"
    #legend.key()
  )+
  ggtitle('SynthSeg QC scores in aggregated pediatric sample')




######## age-bin median regional QC scores (supplementary - REMOVED) #########
if (0) {
median_qc_bin_updated <- ALL %>% filter(pipeline == "updated") %>% group_by(bin, pipeline) %>% summarise(median_qc_gm = median(qc.general.grey.matter),
                                                                                          median_qc_wm = median(qc.general.white.matter), 
                                                                                          median_qc_csf = median(qc.general.csf), 
                                                                                          median_qc_cerebellum = median(qc.cerebellum),
                                                                                          median_qc_brainstem = median(qc.brainstem),
                                                                                          median_qc_thalamus = median(qc.thalamus),
                                                                                          median_qc_putamen_pallidum = median(qc.putamen.pallidum),
                                                                                          median_qc_hippocampus_amygdala = median(qc.hippocampus.amygdala),
                                                                                          median_qc_min = median(qc.min)) %>% ungroup() %>%
                      pivot_longer(cols = starts_with("median_qc"), names_to = "qc_region", values_to = "median_qc")
median_qc_bin <- ALL %>% group_by(bin, pipeline) %>% summarise(median_qc_gm = median(qc.general.grey.matter),
                                                                                          median_qc_wm = median(qc.general.white.matter), 
                                                                                          median_qc_csf = median(qc.general.csf), 
                                                                                          median_qc_cerebellum = median(qc.cerebellum),
                                                                                          median_qc_brainstem = median(qc.brainstem),
                                                                                          median_qc_thalamus = median(qc.thalamus),
                                                                                          median_qc_putamen_pallidum = median(qc.putamen.pallidum),
                                                                                          median_qc_hippocampus_amygdala = median(qc.hippocampus.amygdala),
                                                                                          median_qc_min = median(qc.min)) %>% ungroup() %>%
                      pivot_longer(cols = starts_with("median_qc"), names_to = "qc_region", values_to = "median_qc") %>% filter(qc_region != "median_qc_min") 

median_qc_bin$qc_region <- factor(
  median_qc_bin$qc_region,
  levels = c("median_qc_gm", "median_qc_wm", "median_qc_hippocampus_amygdala", "median_qc_putamen_pallidum", "median_qc_brainstem", "median_qc_cerebellum", "median_qc_thalamus", "median_qc_csf"),
  labels = c(
    "General grey matter",
    "General white matter",
    "Hippocampus & Amygdala",
    "Putamen & Pallidum",
    "Brainstem",
    "Cerebellum",
    "Thalamus",
    "General CSF"
  )
)
median_qc_bin_updated$qc_region <- factor(
  median_qc_bin_updated$qc_region,
  levels = c("median_qc_min", "median_qc_gm", "median_qc_wm", "median_qc_hippocampus_amygdala", "median_qc_putamen_pallidum", "median_qc_brainstem", "median_qc_cerebellum", "median_qc_thalamus", "median_qc_csf"),
  labels = c(
    "Overall minimum QC score",
    "General grey matter",
    "General white matter",
    "Hippocampus & Amygdala",
    "Putamen & Pallidum",
    "Brainstem",
    "Cerebellum",
    "Thalamus",
    "General CSF"
  )
)
pipeline_colours <- c(
  "original"= "grey",
  "updated" = "black")

# p1 with ALL qc regions
plot1 <- ggplot(median_qc_bin, aes(x = bin, y=median_qc, color=pipeline, group=pipeline)) + 
geom_line()+facet_wrap(~qc_region, ncol=2)+
  geom_hline(yintercept = 0.65, linetype = "dashed") +
  # bin-level qc medians (point + line): black for updated and grey for new  
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  labs(x = "Age (post-menstrual)(binned)",y="Median regional QC score", color='Pipeline') +
  theme_minimal() +
  scale_color_manual(values=pipeline_colours) +
  guides(color = guide_legend(ncol = 2))+
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 9.5), 
    legend.position = "bottom",
    legend.title = element_text(hjust = 0.5), 
    strip.text.x = element_text(size = 10))+
  ggtitle('Median regional QC scores across age bins') 

#ggsave(plot1,filename = paste0(outpath,'supplementary/SI_regional_qcs.png'), bg='white', height = 14, width=12)
#ggsave(plot1,filename = paste0(outpath,'supplementary/SI_regional_qcs.pdf'), device = cairo_pdf, bg='white', height = 14, width=12)

line_colors <- c(
  "Overall minimum QC score" = "black",
  "General grey matter" = "#63ad38",
  "General white matter" = "#007bff",
  "Hippocampus & Amygdala" = "#772b85",
  "Putamen & Pallidum" = "#b41f1f",
  "Brainstem" = "#67d0d2",
  "Cerebellum" = "#d5ce50",
  "Thalamus" = "#d78e40",
  "General CSF" = "#dd6ead"
)

plot2 <- ggplot(median_qc_bin_updated, aes(x = bin, y=median_qc, color=qc_region, group=qc_region)) + 
geom_line()+
  geom_hline(yintercept = 0.65, linetype = "dashed") +
  # bin-level qc medians (point + line): black for updated and grey for new  
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  labs(x = "Age (post-menstrual)(binned)",y="Median regional QC score")  +
  theme_minimal() +
  scale_color_manual(values=line_colors, name="QC Region") +
  guides(color = guide_legend(ncol = 3))+
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10), 
    legend.position = "bottom",
    legend.title = element_text(hjust = 0.5)
  )+
  ggtitle('Median regional QC scores across age bins in updated pipeline') 

#ggsave(plot2,filename = paste0(outpath,'supplementary/SI_regional_qcs_SSrc.png'), bg='white', height = 10, width=10)
#ggsave(plot2,filename = paste0(outpath,'supplementary/SI_regional_qcs_SSrc.pdf'), device = cairo_pdf, bg='white', height = 10, width=10)

plot1_and_2=ggarrange(
                    ggarrange(plot1, plot2, widths=c(1.3,1)), 
                    ncol=1, heights=c(1,1))

ggsave(plot1_and_2,filename = paste0(outpath,'supplementary/SI_regional_qcs_combined.png'), bg='white', height = 10, width=15)
ggsave(plot1_and_2,filename = paste0(outpath,'supplementary/SI_regional_qcs_combined.pdf'), bg='white', height = 10, width=15)

} 



######################## Statistics: SynthSeg Original vs Rescale+Crop ########################

# n and failed qc n in SS original & SS r&c
qc_summary <- ALL %>% select(qc.min, pipeline) %>%
  group_by(pipeline) %>%
  summarise(n_below_065 = sum(qc.min < 0.65, na.rm = TRUE), n_total=n()) %>%
  ungroup()

t1t2_sum <- ALL %>% filter(pipeline=="updated") %>% group_by(modality) %>% summarise(n=n())

# only under 2 years old
qc_summary_infants <- ALL %>% filter(bin %in% c("[0,280)", "[280,310)", "[310,370)", "[370,460)", "[460,550)", "[550,645)", "[645,825)", "[825,1.01e+03)")) %>% 
  select(qc.min, pipeline, bin) %>%
  group_by(pipeline) %>%
  summarise(n_above_065 = sum(qc.min >= 0.65, na.rm = TRUE), n_total=n()) %>%
  ungroup()


#### 1. per-agebin original vs updated pipeline comparison of QC ####
agebin_qc_wide <- ALL %>% # create wider dataframe
  select(participant_id, session, bin, pipeline, qc.min) %>%
  pivot_wider(names_from="pipeline", values_from="qc.min") %>%
    mutate( # makes the missing cells into NAs
    original = sapply(original, function(x) {
      if (length(x) == 0) NA else as.character(x[1])
    }),
    updated = sapply(updated, function(x) {
      if (length(x) == 0) NA else as.character(x[1])
    })
  ) %>%
  filter( # filter out any subs with empty cells
    !is.na(updated) & str_trim(updated) != "",
    !is.na(original) & str_trim(original) != ""
  )  
agebin_qc_wide <- agebin_qc_wide %>%
  mutate(diff = as.numeric(agebin_qc_wide$updated) - as.numeric(agebin_qc_wide$original)) 

# QQ plots to check normal distribution of each bin; non-normal bins use wilcoxon
agebin_qc_wide %>%
  ggplot(aes(sample = diff)) +
  stat_qq() +
  stat_qq_line() +
  facet_wrap(~ bin)
wilcox_bins <- c("[0,280)", "[280,310)", "[310,370)", "[370,460)") # these 4 bins are not normal distribution

# Statistics results - above 4 bins use wilcoxon, others use paired t-test
agebin_qc_results <- agebin_qc_wide %>%
  mutate(use_wilcox = bin %in% wilcox_bins) %>%
  group_by(bin) %>%
  summarise(
    count = n(),
    mean_diff = mean(as.numeric(updated) - as.numeric(original), na.rm = TRUE),
    cohens_d = mean(diff, na.rm = TRUE) / sd(diff, na.rm = TRUE),
    test = list(
      if (first(use_wilcox)) {
        wilcox.test(as.numeric(updated), as.numeric(original), paired = TRUE)
      } else {
        t.test(as.numeric(updated), as.numeric(original), paired = TRUE)
      }
    ),
    test_used = ifelse(first(use_wilcox), "Wilcoxon signed rank", "Paired T-test"),
    statistic = test[[1]]$statistic,
    p_value = test[[1]]$p.value,
    .groups = "drop"
  )%>%
  mutate(
    p_fdr = p.adjust(p_value, method = "BH"), 
    p_bonf = p.adjust(p_value, method = "bonferroni")
  ) %>%
    mutate(
    upper = as.numeric(sub(".*,\\s*([^\\)]+)\\)", "\\1", bin))
    )
agebin_qc_results[41, "upper"] <- 13100
agebin_qc_results[42, "upper"] <- 14550

# make age bins understandable
agebin_qc_results <- agebin_qc_results %>%
  mutate(upper_age_years = round((upper-280)/365.25) ) %>%
  mutate(
    upper_age_years = paste0(as.character(upper_age_years), "y")
  ) %>%
    mutate(
    upper_age = if_else(row_number() == 1, "40pmw",
                if_else(row_number() == 2, "1m",
                if_else(row_number() == 3, "3m",
                if_else(row_number() == 4, "6m",
                if_else(row_number() == 5, "9m",
                if_else(row_number() == 7, "1.5y",
                upper_age_years))))))
  ) %>%
  select(upper_age, count, mean_diff, test_used, statistic, p_value, p_bonf, cohens_d) %>%
  mutate(sig= case_when(
      p_bonf < 0.001 ~ "***",
      p_bonf < 0.01  ~ "**",
      p_bonf < 0.05  ~ "*",
      TRUE           ~ ""
    ))

library(gt)
agebin_qc_results %>% gt() 

write.csv(agebin_qc_results, "/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/supplementary/agebin_qc_results.csv", row.names=FALSE)



#### 2. per-agebin QC comparison between 2 pipelines, but P/F - not used ####
if (0) {
agebin_qc_pf_wide <- ALL %>%
  select(participant_id, session, bin, pipeline, qc.min) %>%
  mutate(qc_pf = if_else(qc.min >= 0.65, "p", "f"))%>%
  group_by(participant_id, session, bin, pipeline) %>%
  summarise(qc_pf = first(qc_pf), .groups = "drop") %>%  # collapse duplicates
  pivot_wider(names_from = pipeline, values_from = qc_pf)%>%
  mutate(
    original = sapply(original, function(x) {
      if (length(x) == 0) NA else as.character(x[1])
    }),
    updated = sapply(updated, function(x) {
      if (length(x) == 0) NA else as.character(x[1])
    })
  ) %>%
  filter(
    !is.na(updated) & str_trim(updated) != "",
    !is.na(original) & str_trim(original) != ""
  ) 

possible_levels <- c("p", "f")

data_list <- split(agebin_qc_pf_wide,addNA(agebin_qc_pf_wide$bin))
table_list <- lapply(data_list, function(agebin_qc_pf_wide) table(agebin_qc_pf_wide$original, agebin_qc_pf_wide$updated))

results_list <- map(data_list, ~{
  # Convert to factor with fixed levels to ensure a 2x2 table
  before_f <- factor(.x$original, levels = possible_levels)
  after_f  <- factor(.x$updated, levels = possible_levels)
  
  tbl <- table(before_f, after_f)
    mcnemar.exact(tbl)
})

final_results <- map_df(results_list, ~{
  tibble(
    p_value    = .x$p.value,
    odds_ratio = .x$estimate,
    statistic  = .x$statistic,
    conf_low   = .x$conf.int[1],
    conf_high  = .x$conf.int[2],
    method     = .x$method
  )
}, .id = "bin")

final_results <- final_results %>%
  mutate(p_bonf = p.adjust(p_value, method = "bonferroni")) %>%
  mutate(
  upper = as.numeric(sub(".*,\\s*([^\\)]+)\\)", "\\1", bin))
  ) 
final_results[41, "upper"] <- 13100
final_results[42, "upper"] <- 14550

# make age bins understandable
final_results_pf <- final_results %>%
  mutate(upper_age_years = round((upper-280)/365.25) ) %>%
  mutate(
    upper_age_years = paste0(as.character(upper_age_years), "y")
  ) %>%
    mutate(
    upper_age = if_else(row_number() == 1, "40pmw",
                if_else(row_number() == 2, "1m",
                if_else(row_number() == 3, "3m",
                if_else(row_number() == 4, "6m",
                if_else(row_number() == 5, "9m",
                if_else(row_number() == 7, "1.5y",
                upper_age_years))))))
  ) %>%
  select(upper_age, statistic, p_value, p_bonf, odds_ratio, conf_low, conf_high)

}

##################### ASSEMBLING THE FINAL FIGURE #########################

# Will use this to add crop panel
blank_panel <- ggplot() +
  theme_void() 

# # Put final Figure 1 together
# p_complete=ggarrange(p1,
#                      ggarrange(p12,p13_scatter, common.legend = T, legend='right', widths=c(1,1)),
#                      ggarrange(final_plot, blank_panel, widths=c(1,0.8)), 
#                      ncol=1, heights=c(1,0.7,1))

title_theme <- theme(
  plot.title = element_text(hjust = 0, margin = margin(t = 10, b = 10)),
  plot.title.position = "plot"
)

p1_with_legend <- p1 + labs(title = "B | New SynthSeg QC scores in neurodevelopmental sample") + title_theme
p1_separate_with_legend <- p1_separate + labs(title = "C | Proportion of neurodevelopmental sample\n      passing QC") + title_theme
blank_panel_with_legend <- blank_panel + labs(title = "A | Exemplary improvements in segmentation quality in both BOBS and neurodevelopmental samples") + title_theme


# Put final Figure 4 together
p_complete=ggarrange(blank_panel_with_legend,
                    ggarrange(p1_with_legend, p1_separate_with_legend, widths=c(1.2,1)), 
                    ncol=1, heights=c(1.5,1.3))


ggsave(p_complete,
       filename =paste0(outpath,'fig4_new.png'), 
       bg='white', height=10.5, width=10)

ggsave(p_complete,
       filename =paste0(outpath,'fig4_new.pdf'), 
       device = cairo_pdf,
       bg='white', height=10.5, width=10)



ggsave(p1_with_legend,
       filename =paste0(outpath,'fig4.png'), 
       bg='white', height=10.5, width=10)

ggsave(p1_with_legend,
       filename =paste0(outpath,'fig4.pdf'), 
       device = cairo_pdf,
       bg='white', height=10.5, width=10)




########## Old Supplementary Figures below (removed) ##########

if (0) {
ALL = ALL %>% 
  group_by(pipeline, ID, age_days_pma) %>%
  mutate(run=seq(n())) %>%
  ungroup()

ALL_wide = ALL %>% 
  select(study, ID, total.intracranial, qc.min, age_days_pma, pipeline, run) %>% 
  pivot_wider(names_from = pipeline, values_from = c('qc.min','total.intracranial'))
  
# not used
p2 = ALL_wide %>% 
  ggplot(aes(x=qc.min_original,y=qc.min_updated, color=study))+
  geom_point()+
  scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2))+
  theme_minimal()+
  xlab('Original QC')+ylab('Updated QC')
  
p3 = ALL_wide %>% 
  filter(!is.na(qc.min_updated)) %>%
  #ggplot(aes(x=total.intracranial_original,y=total.intracranial_updated, color=qc.min_updated>=0.65))+
  ggplot(aes(x=total.intracranial_original,y=total.intracranial_updated, color=qc.min_updated))+
  geom_point(size=3, alpha=0.2)+
  #geom_point(data=subset(ALL_wide, qc.min_updated<0.65),aes(x=total.intracranial_original,y=total.intracranial_updated, color=qc.min_updated),size=3)+
  geom_abline(intercept = 0, slope = 1, linetype='dashed')+
  #scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2))+
  theme_minimal()+
  theme(text = element_text(size=12) )+
  xlab('Original TIV')+ylab('Updated TIV')+
  scale_color_gradient2(midpoint = 0.65,high='#00767BFF',low='#FD9A44FF')+labs(color='QC')
  #scale_color_manual(values = c('#00767BFF','#FD9A44FF'))+labs(color='Pass QC')


ggsave(ggarrange(p2,p3, common.legend = T, legend = 'right'),
       filename =paste0(outpath,'supplementary/SI_fig_correlation-qc-scores.png'), 
       bg='white', height=3.5, width=9)

ggsave(ggarrange(p2,p3, common.legend = T, legend = 'right'),
       filename =paste0(outpath,'supplementary/SI_fig_correlation-qc-scores.pdf'), 
       device = cairo_pdf,
       bg='white', height=3.5, width=9)

}