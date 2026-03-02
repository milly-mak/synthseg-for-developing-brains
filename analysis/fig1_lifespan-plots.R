library(dplyr)
library(ggplot2)
library(forcats)
library(ggridges)
library(ggbreak)
library(matrixStats)
library(patchwork)

setwd("/rds/project/kw350/rds-kw350-meld/growthcharts/code/all-data/")

# Path to save figures to
basepath='/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/'
outpath=paste0(basepath,'/figs/')

# Read in original original SynthSeg QC scores
DEMO=read.csv('all-synthseg-and-demographics.csv')
DEMO$qc.min =rowMins(as.matrix(DEMO[,grep('qc\\.', colnames(DEMO))]))
DEMO = DEMO %>% 
  select(study, participant_id, age_days_pma, qc.min, dx, session,
         total.intracranial,left.cerebral.white.matter,right.cerebellum.white.matter,
         right.cerebral.cortex,left.cerebral.cortex)
DEMO$ID = paste0(DEMO$study,'|',DEMO$participant_id)

# ABCD has some weird age outliers
DEMO = DEMO %>% filter(! ((study=='ABCD' & age_days_pma > 17*365) | (study=='ABCD' & age_days_pma < 7*365)) )
DEMO = DEMO %>% filter(!is.na(age_days_pma))

write.csv(DEMO, file = paste0(basepath,'/other/lifespan.original.SS.scores.csv'), row.names = F)

DEMO <- DEMO %>% mutate(study = fct_reorder(study, age_days_pma, .fun = min))

DEMO <- DEMO %>%
  group_by(ID) %>%
  arrange(age_days_pma, .by_group = TRUE) %>%
  mutate(session_num = dense_rank(age_days_pma)) %>%
  ungroup()

qcbins=c(0,280,280+30, 280+90, 280+180, 280+270, 280+365, 280+365+180, 280+seq(2*365,35*365,365))
pretty_labels <- c("40wk","1m","3m","6m","9m","12m","18m","2y","5y","10y","18y")
bin_levels <- cut(qcbins[-1]-1, breaks=qcbins, right=FALSE, include.lowest=TRUE) %>% 
  levels()

# Pick only the age bins we want to label
selected_levels <- bin_levels[c(2,5,7,9,12,15,23,41)] 
selected_labels <- c("40w","6m","1y","2y","5y","10y","18y",'30y')

DEMO$study = factor(DEMO$study, levels=levels(DEMO$study), labels=gsub('OpenNeuro-','',as.character(levels(DEMO$study))))

DF <- DEMO %>%
  filter(session_num == 1, dx %in% c("CN", "CN - Sibling has ASD")) %>%
  mutate(bin = cut(age_days_pma, breaks = qcbins, right = FALSE, include.lowest = TRUE))

# Bin-level % >= 0.65
PERC <- DF %>%
  group_by(bin) %>%
  summarise(perc = mean(qc.min >= 0.65, na.rm = TRUE), n = dplyr::n()) %>% 
  ungroup()

# One shared palette for 'study' used in both plots
study_levels <- levels(DF$study)
custom_colorscale=scales::hue_pal()(length(study_levels))
custom_colorscale=paletteer::paletteer_d("khroma::nightfall")[-17]
study_colors_lifespan <- setNames(custom_colorscale, study_levels)

# Plot Original SynthSeg QC scores
p1 <- ggplot(DF, aes(x = bin)) +
  # raw points per subject (jittered)
  geom_jitter(aes(y = qc.min, color = study), width = 0.2, height = 0, alpha = 0.6, size = 2) +
  geom_hline(yintercept = 0.65, linetype = "dashed") +
  # bin-level percentage (point + line)
  geom_line(data = PERC, aes(y = perc, group = 1), color = "black", linewidth = 0.6) +
  geom_point(data = PERC, aes(y = perc), color = "black", size = 2.2) +
  scale_color_manual(values = study_colors_lifespan, guide = guide_legend(title = "Dataset", ncol=2)) +
  scale_y_continuous(name = "SynthSeg QC scores", limits = c(0, 1),breaks = seq(0, 1, 0.1), sec.axis = sec_axis(~ ., name = "Proportion ≥ 0.65", labels = scales::percent)) +
  scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
  labs(x = "Post-menstrual age (binned)",color='Study') +
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "black",size = 12),
    axis.title.y.left = element_text(color = "black",size = 12),
    axis.text.y  = element_text(size = 10),
    axis.text.x  = element_text(size = 10)
  )+
  ggtitle('SynthSeg QC scores in aggregated pediatric sample')

if (0){
  # Coverage matrix for bottom subplot: which studies have data in which bins
  COVER <- DF %>%
    filter(!is.na(bin)) %>%
    group_by(study, bin) %>%
    summarise(n = dplyr::n(), .groups='drop') %>%
    mutate(has_data = n > 0)
  
  # Order studies by their earliest bin (nice left-to-right “start” order)
  study_order <- COVER %>%
    group_by(study) %>%
    summarise(first_bin = min(as.integer(bin)), .groups = "drop") %>%
    arrange(first_bin) %>%
    pull(study)
  
  COVER <- COVER %>%
    mutate(study = factor(study, levels = study_order))
  
  # Might not use this
  p_bottom <- ggplot(COVER, aes(x = bin, y = study)) +
    geom_tile(aes(fill = study, alpha = has_data), height = 0.9) +
    scale_fill_manual(values = study_colors_lifespan, guide = "none") +
    scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.12), guide = "none") +
    scale_x_discrete( breaks = selected_levels, labels = selected_labels) +
    labs(x = "Post-menstrual age (binned)", y = "Dataset") +
    theme_minimal() +
    theme(
      panel.grid = element_blank(),
      axis.title.y = element_text(size = 12),
      axis.text.y  = element_text(size = 10),
      axis.text.x  = element_text(size = 10)
    )
  
  
  p2 = (p1 / p_bottom) +
    plot_layout(heights = c(3, 1.9), guides = "collect") &
    theme(
      legend.position = "right",          # legend spans both plots
      legend.box = "vertical",            # stack items vertically
      legend.title = element_text(face = "bold", size = 10),
      legend.text  = element_text(size = 9),
      legend.key.height = unit(0.5, "cm"),
      legend.key.width  = unit(0.8, "cm")
    )
  ggsave(p2,filename = paste0(outpath,'lifespan.qc.png'), bg='white', height=6, width=13)
  ggsave(p2,filename = paste0(outpath,'lifespan.qc.pdf'), device = cairo_pdf, bg='white', height=6, width=13)
  
}

p3 = DEMO %>%
  filter(session_num == 1 & (dx=='CN' | dx == "CN - Sibling has ASD")) %>%
  ggplot(aes(x = age_days_pma, fill = study)) +
  geom_histogram(binwidth = 365, color = "black",position = "stack" ) +  # binwidth can be adjusted
  scale_x_continuous(breaks=c(0,280,280+2*365,280+5*365,280+12*365,280+18*365,280+35*365), 
                     labels=c('','40w','2y','5y','12y','18y','35y'))+
  scale_y_break(c(450, 1000), scales = 0.5) +  # adjust the break range as needed
  theme_minimal()+
  geom_hline(yintercept =200, linetype='dashed')+
  geom_hline(yintercept =100, linetype='dashed')+
  ylab('Sample size')+xlab('Age in years')+labs(fill='Study')+
  guides(fill = guide_legend(ncol = 2))+
  scale_fill_manual(values = study_colors_lifespan, guide = "none") 

ggsave(p3,filename = paste0(outpath,'supplementary/SI_fig_lifespan.sample.png'), bg='white', height = 4, width=8)
ggsave(p3,filename = paste0(outpath,'supplementary/SI_fig_lifespan.sample.pdf'), device = cairo_pdf, bg='white', height = 4, width=8)

# Not using this
# p4 = DEMO %>% filter(session_num == 1) %>% 
#   ggplot(aes(x=age_days_pma,y=study, fill=study))+
#   geom_density_ridges(rel_min_height=0.001,scale = 3)+
#   scale_x_continuous(breaks=c(0,280,280+2*365,280+5*365,280+12*365,280+18*365,280+35*365), 
#                      labels=c('','40wk','2y','5y','12y','18y','35y'))+
#   theme_minimal()+
#   ylab('Sample size')+xlab('Age in years')+labs(fill='Study')+
#   scale_fill_manual(values = study_colors_lifespan, guide = "none") 
# 
# ggsave(p4,filename = '/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/figs/lifespan.sample.distribution.png', bg='white', height = 4, width=8)


# Load SynthSeg training datasets
if(0){
  # Create subset of data from LBCC - Milly dont run this, you wont have access
  LBCC_all=read.csv('/rds/project/rds-BPTFK94868I/data/aparc.aseg.lifespan.v.Goettingen.240820.csv')
  LBCC = subset(LBCC_all, study=='ADNI' | study=='OASIS' | study=='HCP')
  LBCC$TCV = LBCC$SupraTentorialVolNotVent
  LBCC = (LBCC[,c('participant','session','study','run','dx','age_days','sex','site','TCV')])
  LBCC=subset(LBCC, run=='1' & session=='1')
  LBCC$age_days=round(LBCC$age_days)
  LBCC$sex = factor(LBCC$sex, levels=c('female','male'), labels=c('Female','Male'))
  write.csv(LBCC, paste0(basepath,'/other/SynthSeg-training-data.csv'), row.names=F)
}

LBCC = read.csv('/rds/project/kw350/rds-kw350-meld/growthcharts/dev/BOPS/other/SynthSeg-training-data.csv')

# Load LBCC model
lbcc_installation='/rds/project/kw350/rds-kw350-meld/growthcharts/tools/LBCC-lifespan-models/'
source(paste0(lbcc_installation,"100.common-variables.r"))
source(paste0(lbcc_installation,"102.gamlss-recode.r"))
source(paste0(lbcc_installation,"300.variables.r"))
source(paste0(lbcc_installation,"301.functions.r"))

FIT <- readRDS(paste0(lbcc_installation, "Share/RefittedModels/FIT_TCV.rds"))
POP.CURVE.LIST <- list(AgeTransformed=seq(log(90),log(365*102),length.out=2^7),sex=c("Female","Male"))
POP.CURVE.RAW <- do.call( what=expand.grid, args=POP.CURVE.LIST )
CURVE <- Apply.Param(NEWData=POP.CURVE.RAW, FITParam=FIT$param )

# # Overlay SynthSeg training data on lifespan trajectory of TCV
# p5 = CURVE %>% 
#   ggplot(aes(x=AgeTransformed,y=PRED.m500.pop, color=sex))+
#   geom_smooth()+
#   geom_smooth(data=CURVE, aes(x=AgeTransformed,y=PRED.u975.pop, color=sex), linetype='dashed')+
#   geom_smooth(data=CURVE, aes(x=AgeTransformed,y=PRED.l025.pop, color=sex), linetype='dashed')+
#   geom_point(data=LBCC, aes(x=log(age_days),y=TCV/10000, color=study), alpha=0.5)+
#   scale_color_manual(values=c('indianred','skyblue4','seagreen','seagreen2','seagreen3'))+
#   theme_minimal()+
#   labs(color='')+
#   ylab('TCV')+
#   scale_x_continuous(breaks = log(280+c(0,1*365,5*365,18*365,30*365,80*365)),
#                      labels = c('40PMA','1y','5y','18y','30y','80y'), limits = c(log(280), log(100*365)))+
#   ggtitle('Normative trajectory of TCV + SynthSeg datasets')+
#   theme(axis.text = element_text(size=12),
#         text = element_text(size=12))

# Estimate lifespan max TCV
max_vol = CURVE %>% group_by(sex) %>% summarize(max_vol = max(PRED.m500.pop)) # Get maximum TCV
# Setup centile lines
centiles=0.5
Pred.Set <- setNames(centiles,'m500')

# Get ages to sample from TCV trajectory
INPUT=do.call(args=list(age_days=(seq(7*20,365*105)), sex=c("Female","Male")), what=expand.grid)
INPUT$AgeTransformed=log(INPUT$age_days)

grab_volume = Apply.Param(NEWData=INPUT, FITParam=FIT$param, Pred.Set=Pred.Set)

# Estimate scaling factor based on max volume
grab_volume = grab_volume %>% left_join(max_vol)
grab_volume = grab_volume <- grab_volume %>%
  mutate(
    across(
      matches("^PRED\\.[lmu]\\d{3}\\.pop$"),
      ~ (max_vol / .x)^(1/3),
      .names = "perc{col}"
    )
  ) %>%
  rename_with(
    ~ sub("^percPRED\\.[lmu](\\d{3})\\.pop$", "perc\\1", .x),
    starts_with("percPRED.")
  )

grab_volume$age_days=round(exp(grab_volume$AgeTransformed))

n_sample=10000
idx <- sample.int(nrow(LBCC), size = n_sample, replace = T)
scale_mat <- data.frame(matrix(runif(n_sample * 3, min = 0.8, max = 1.2), nrow = n_sample))
scale_mat$scaling_factor <- apply(scale_mat,1,product)
scale_mat$idx = idx
scale_mat$TCV_rescaled = LBCC$TCV[scale_mat$idx]*scale_mat$scaling_factor

ylim_tcV=c(20,175)

quantiles_rescaled <- scale_mat %>%
  summarise(
    q05 = quantile(TCV_rescaled/10000, 0.1, na.rm = TRUE),
    q50 = quantile(TCV_rescaled/10000, 0.50, na.rm = TRUE),
    q95 = quantile(TCV_rescaled/10000, 0.9, na.rm = TRUE)
  )

quantiles_orig <- LBCC %>%
  summarise(
    q05 = quantile(TCV/10000, 0.1, na.rm = TRUE),
    q50 = quantile(TCV/10000, 0.50, na.rm = TRUE),
    q95 = quantile(TCV/10000, 0.9, na.rm = TRUE)
  )
quantiles = rbind((quantiles_orig),(quantiles_rescaled))
quantiles$group=c('original','rescaled')

# Color palette for studies 
study_colors <- c(
  "#238F9DFF", "#00767BFF", "#125A56FF",  # seagreen tones
  "grey80", "grey40"                      # for original / rescaled
)
# Sex colors
sex_colors <- c("#D11807FF","#9DCCEFFF")  # teal vs red

# Dummy df for quantile legend ---
quant_legend_df <- data.frame(
  x = 0, xend = 1, y = 0, yend = 0,
  quant = factor(c("q05", "q50", "q95"), levels = c("q05", "q50", "q95"))
)

p5_left_clean <- ggplot() +
  # --- 1. Smooths: color = sex (legend "Sex") ---
  geom_smooth(data = CURVE,aes(x = AgeTransformed, y = PRED.m500.pop, color = sex),se = FALSE, linewidth = 2) +
  geom_smooth(data = CURVE,aes(x = AgeTransformed, y = PRED.u975.pop, color = sex),se = FALSE, linewidth = 0.7, alpha = 0.1) +
  geom_smooth(data = CURVE,aes(x = AgeTransformed, y = PRED.l025.pop, color = sex),se = FALSE, linewidth = 0.7, alpha = 0.1) +
  scale_color_manual(name   = "Sex", values = sex_colors) +
  guides(color = guide_legend(order = 1, override.aes = list(alpha = 1, linewidth = 1.5))) +
  ggnewscale::new_scale_color() +
  # Overlay point
  geom_point(
    data = LBCC,
    aes(x = log(age_days), y = TCV/10000, color = study),
    alpha = 0.6, size = 1.8) +
  scale_color_manual(name   = "Original data",values = study_colors) +
  guides(color = guide_legend(order = 2, override.aes = list(size = 3, alpha = 1))) +
  # Quantile lines
  ggnewscale::new_scale_color() +
  geom_hline(data = quantiles,aes(yintercept = q05, color = group),linetype = "dotted", linewidth = 0.6, show.legend = FALSE)+
  geom_hline(data = quantiles,aes(yintercept = q50, color = group),linetype = "solid", linewidth = 0.8, show.legend = FALSE) +
  geom_hline(data = quantiles,aes(yintercept = q95, color = group),linetype = "dotted", linewidth = 0.6, show.legend = FALSE) +
  geom_segment(data = quant_legend_df,aes(x = x, xend = xend, y = y, yend = yend, linetype = quant), linewidth = 0.9, inherit.aes = FALSE) +
  scale_linetype_manual(
    name   = "Quantile",
    values = c(q05 = "dotted", q50 = "solid", q95 = "dotted"),
    labels = c(q05 = "5th", q50 = "50th", q95 = "95th"),
    guide='none'
  ) +
  scale_color_manual(values = c(original = "grey80", rescaled = "grey40"),guide  = "none")+
  # Layout
  coord_cartesian(ylim = ylim_tcV) +
  scale_x_continuous(
    breaks = log(280 + c(0, 1*365, 5*365, 18*365, 30*365, 80*365)),
    labels = c('40w','1y','5y','18y','30y','80y'),
    limits = c(log(280), log(100*365))) +
  labs(y = "Total cerebrum volume",x = NULL,title = "Normative trajectory & SynthSeg data") +
  theme_minimal(base_size = 12) +
  theme(axis.text = element_text(size = 12),
        axis.title.y = element_text(color = "black",size = 12),
        axis.text.y  = element_text(size = 10),
        axis.text.x  = element_text(size = 10))

p10_right_clean <-
  ggplot() +
  stat_density(data = LBCC, aes(y = TCV/10000, x = after_stat(density), fill = "original"),
               orientation = "y", geom = "area", alpha = 0.6) +
  stat_density(data = scale_mat, aes(y = TCV_rescaled/10000, x = after_stat(density), fill = "rescaled"),
               orientation = "y", geom = "area", alpha = 0.6) +
  scale_fill_manual(name   = "Distribution",values = c(original = "grey80", rescaled = "grey40")) +
  ggnewscale::new_scale_color() +
  geom_hline(data = quantiles,aes(yintercept = q05, color = group),linetype = "dotted", linewidth = 0.6, show.legend = FALSE)+
  geom_hline(data = quantiles,aes(yintercept = q50, color = group),linetype = "solid", linewidth = 0.8, show.legend = FALSE) +
  geom_hline(data = quantiles,aes(yintercept = q95, color = group),linetype = "dotted", linewidth = 0.6, show.legend = FALSE) +
  scale_color_manual(values = c(original = "grey80", rescaled = "grey40"),guide  = "none")+
  coord_cartesian(ylim = ylim_tcV) +
  scale_x_continuous(breaks = c(0.00, 0.02)) +
  labs(x = "Density", y = NULL) +
  theme_void(base_size = 12) 

final_plot <-
  (p5_left_clean | p10_right_clean) +
  plot_layout(widths = c(5, 1), guides = "collect") &
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    legend.justification = "top",
    legend.box.spacing = unit(0.05, "cm"),
    legend.spacing.y = unit(0.05, "cm"),
    legend.key.height = unit(0.3, "cm")#,   # smaller boxes
  )


DICEQC = read.csv('../../dev/BOPS/code/BOPS-pipeline-testing/all-qc-and-dice.csv')
BOPSDEMO = read.csv('../../dev/BOPS/BIDS/demographics.tsv', sep='\t')
colnames(BOPSDEMO)[1]='subject'
BOPSDEMO = BOPSDEMO[,c('subject','session','age_days_pma','sex','GA_at_birth','site')]
DICEQC = DICEQC %>% left_join(BOPSDEMO)
DICEQC$pipeline = factor(DICEQC$pipeline, levels=c('synthseg-robust','reconall-clinical', 'resampled-down', 'resampled-median', 'resampled-up'))
DICEQC = DICEQC %>% filter(name != 'Left-Cerebral-Exterior' & name != 'Left-Cerebellum-Exterior') 
DICEQC = DICEQC %>% filter(pipeline=='synthseg-robust' & modality=='t2w') 

DICESUMMARY = DICEQC %>% 
  filter(modality=='t2w' & name != 'CSF') %>%
  group_by(subject, session, pipeline, age_days_pma) %>% 
  summarise(median_dice=median(dice, na.rm=T))

p12 = DICESUMMARY %>%
  left_join(DICEQC[,c('subject','session','qc_min')]) %>% 
  ggplot(aes(x = age_days_pma, y = median_dice, color = qc_min))+
  geom_point(size=2)+
  theme_minimal()+
  ylab('Dice coefficient')+xlab('Age')+
  ggtitle('Spatial overlap with ground truth')+
  labs(color='QC score')+
  theme(axis.text = element_text(size=12), 
        text = element_text(size=12))+
  scale_x_continuous(breaks = 280+c(30, 90, 180,270,360),
                     labels = c("1m", "3m", "6m", "9m",'1y'))+
  scale_color_gradient2(midpoint = 0.65,high='#00767BFF',low='#FD9A44FF')

DEMO$TCV = DEMO$left.cerebral.white.matter+DEMO$right.cerebellum.white.matter+DEMO$right.cerebral.cortex+DEMO$left.cerebral.cortex

p13_scatter = DEMO[,c('participant_id','session','TCV','age_days_pma','qc.min')] %>%
  ggplot(aes(x = log2(age_days_pma), y = TCV/10000, color = qc.min))+
  geom_point(size=2)+
  theme_minimal()+
  ylab('Total cerebrum volume')+xlab('Age')+
  ggtitle('Pediatric QC scores')+
  labs(color='QC score')+
  scale_x_continuous( breaks = log2(280+c(0,180,365,2*365,5*365,10*365,18*365,30*365)), 
                      labels = selected_labels) +
  scale_color_gradient2(midpoint = 0.65,high='#00767BFF',low='#FD9A44FF')+
  theme(axis.text = element_text(size=12), 
        text = element_text(size=12), 
        legend.position='none')


# Data for side panel
side_df <- DEMO %>% transmute(tcv_1000 = TCV/1000, qc = qc.min)  %>% filter(is.finite(tcv_1000), is.finite(qc))
breaks <- seq(min(side_df$tcv_1000), max(side_df$tcv_1000), length.out = 1001)

# Empirical mean qc per TCV bin
qc_by_bin <- side_df %>%
  mutate(bin = cut(tcv_1000, breaks = breaks, include.lowest = TRUE)) %>%
  group_by(bin) %>%
  summarise(qc_mean = mean(qc, na.rm=T), .groups = "drop")

# density curve -> thin horizontal slices
d <- density(side_df$tcv_1000, na.rm = TRUE)
dens_df <- tibble(tcv_1000 = d$x, dens = d$y) %>%
  mutate(
    tcv_1000_next = lead(tcv_1000),
    bin = cut(tcv_1000, breaks = breaks, include.lowest = TRUE)
  ) %>%
  filter(!is.na(tcv_1000_next)) %>%
  left_join(qc_by_bin, by = "bin") %>%
  arrange(tcv_1000) %>%
  tidyr::fill(qc_mean, .direction = "downup")

# right density panel
p13_yden <- ggplot(dens_df) +
  geom_rect(aes(xmin = 0, xmax = dens, ymin = tcv_1000, ymax = tcv_1000_next, fill = qc_mean), colour = NA) +
  geom_hline(yintercept = as.numeric(quantile(side_df$tcv_1000, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)),
             linetype = c('dotted','solid',"dotted"), linewidth = 0.8, colour = "grey20") +
  scale_fill_gradient2(midpoint = 0.65, high = "#00767BFF", low = "#FD9A44FF") +
  theme_void() + labs(fill='QC Min')+
  theme(
    axis.title = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    legend.position = "right"
  )
  
p13 = p13_scatter + p13_yden + plot_layout(widths = c(1, 0.2))

# Will use this to add crop panel
blank_panel <- ggplot() +
  theme_void() 

# Put final Figure 1 together
p_complete=ggarrange(p1,
                     ggarrange(p12,p13, common.legend = T, legend='right', widths=c(0.8,1)),
                     ggarrange(final_plot, blank_panel, widths=c(1,0.8)), 
                     ncol=1, heights=c(1,0.7,1))

ggsave(p_complete,filename =paste0(outpath,'fig1.png'), bg='white', height=11.5, width=10)
ggsave(p_complete,filename =paste0(outpath,'fig1.pdf'),device = cairo_pdf,  bg='white', height=11.5, width=10)

# # Estimate scaling factor based on max volume
# LBCC_normative = LBCC %>% left_join(subset(grab_volume, sex=='Male')[,c('age_days','perc500')])
# LBCC_normative$TCV_transformed = LBCC_normative$TCV/10000
# 
# # Add random rescaling as in SS training
# set.seed(123)  # for reproducibility
# LBCC_normative <- LBCC_normative %>%
#   mutate(
#     TCV_rescaled = TCV_transformed * (1 + runif(n(), -0.2, 0.2))
#   )
# 
# p6 = ggplot(LBCC_normative) +
#   geom_histogram(aes(x = TCV_transformed),
#                  bins = 50, fill = paletteer::paletteer_d("khroma::nightfall")[1], alpha = 0.6) +
#   geom_histogram(aes(x = TCV_rescaled),
#                  bins = 50, fill = paletteer::paletteer_d("khroma::nightfall")[5], alpha = 0.6) +
#   theme_minimal() +
#   labs(
#     x = "TCV",
#     y = "N",
#     title = "TCV with random ±20% rescaling"
#   )+
#   theme(axis.text = element_text(size=12),
#         text = element_text(size=12))
# 
# 
# LBCC_plot = LBCC_normative %>% left_join(max_vol)
# LBCC_plot$TCV_orig_scale = LBCC_plot$TCV_transformed/LBCC_plot$max_vol
# LBCC_plot$TCV_rescaled_scale = LBCC_plot$TCV_rescaled/LBCC_plot$max_vol
# 
# df = data.frame(scaling_factor=c(LBCC_plot$TCV_rescaled_scale, LBCC_plot$TCV_orig_scale),
#                 group=c(rep('rescaled',nrow(LBCC_plot)),rep('orig',nrow(LBCC_plot)))) 
# 
# 
# # Compute quantiles per group
# quantiles_df <- df %>%
#   group_by(group) %>%
#   summarise(
#     q25 = quantile(scaling_factor, 0.1, na.rm = TRUE),
#     q50 = quantile(scaling_factor, 0.50, na.rm = TRUE),
#     q75 = quantile(scaling_factor, 0.9, na.rm = TRUE)
#   )
# 
# # Plot histogram with quantile lines
# p7 = ggplot(df) +
#   geom_histogram(aes(x = scaling_factor, fill = group), alpha = 0.6, bins = 50, position = "identity") +
#   geom_vline(
#     data = quantiles_df,
#     aes(xintercept = q25, color = group), linetype = "dashed", linewidth = 0.6
#   ) +
#   geom_vline(
#     data = quantiles_df,
#     aes(xintercept = q50, color = group), linetype = "solid", linewidth = 0.8
#   ) +
#   geom_vline(
#     data = quantiles_df,
#     aes(xintercept = q75, color = group), linetype = "dashed", linewidth = 0.6
#   ) +
#   scale_fill_manual(values = paletteer::paletteer_d("khroma::nightfall")[c(1,5)]) +
#   scale_color_manual(values = paletteer::paletteer_d("khroma::nightfall")[c(1,5)], guide = "none") +  # use same colors for lines
#   theme_minimal() +
#   xlab("Scaling factor") +
#   ylab("N") +
#   labs(fill = "") +
#   ggtitle("Scaling factor with quantile lines")+
#   scale_x_continuous(breaks=seq(0.5,1.5,0.1))+
#   theme(axis.text = element_text(size=12),
#         text = element_text(size=12))
# 
# 
# 
# ggarrange(p2,ggarrange(p5,ggarrange(p6,p7, common.legend = T, legend = 'bottom'), ncol=1), ncol=1)



