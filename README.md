# Infant pipeline development code

This repository tests two hypotheses:

1. That SyntSeg is sensitive brain size, and therefore struggles to process infant scans.
2. That SynthSeg performs better on cropped brain images. 

### Register BOPS 'ground truth' segmentations into BCP-space
The following script takes the BOPS manually curated ground truth segmentations, and registers them into BCP space:

`Register-BCP-BOPS/register-BCP-to-BOPS.sh` 

### Run six different processing pipelines
We will run the following four pipelines:

1. SynthSeg robust vanilla (`SSr-vanilla`)
3. SynthSeg robust crop (`SSr-crop`)
4. SynthSeg robust resize (`SSr-resize`)
5. SynthSeg robust resize and crop (`SSr-resize-and-crop`)

Two additional pipelines are no longer in use:
1. Recon-All Clinical vanilla (`RCA-clinical-vanilla`)
2. Recon-All Clinical resize and crop (`RCA-clinical-resize-and-crop`)
   
We use the following scripts to process the BCP T1w-scans:

`BCP-pipeline-testing/${pipeline}.sh`



### Estimate DICE coefficient between groundtruth and SynthSeg segmentations
Use the following scripts to estimate the DICE coefficient between the BOPS groundtruth segmentation, registered into BCP space, and the SynthSeg segmentations for each of the pipelines:

`BCP-pipeline-testing/DICE-${pipeline}.sh`



This makes use of the following helper scripts:

`BCP-pipeline-testing/voxel-grid.py` which resamples we use to match the voxel grids of the BOPS and BCP parcellations

`BCP-pipeline-testing/merge_synthseg_to_bops_labels.py` which merges SynthSeg segmentation labels to resemble BOPS labels

`BCP-pipeline-testing/merge_qc_labels.py` which merges segmentation labels from BOPS label format to SynthSeg QC labels

`BCP-pipeline-testing/estimate-dice.py` which estimates the DICE coefficient between two segmentations


### Analyse the goodness metrics for the different pipelines

We analyse the goodness metrics for all pipelines in R, using scripts in the `analysis` folder. Each script generates one figure for the resulting manuscript. 

`fig1_lifespan-plots.R` Highlights background info and hypotheses
`fig2_methods.R` Shoes how we estimate the scaling factor
`fig3_pipeline-results.R` Compares segmentation results in BCP
`fig4_show_improvements.R` Shows improvements across neurodevelopment

