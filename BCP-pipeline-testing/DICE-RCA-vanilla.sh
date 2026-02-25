#!/bin/bash
#SBATCH --job-name=Dice
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=1
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU
#SBATCH --output=logs/DICE_rca-vanilla_%a.txt
#SBATCH --array=2-73
#SBATCH --partition=icelake

now=$(date +"%T")
echo "Starting"
echo "Current time : $now"

study='BOPS'
modality='T1w'

echo "Setting up files"
mkdir logs # to save log files in 

# Basepath - this is what you'd have to change to your account:
rdspath=/rds/project/kw350/rds-kw350-meld/

pipeline='reconall-clinical'

# Input paths
allt1s=${rdspath}/growthcharts/dev/${study}/code/BCP-pipeline-testing/all-T1s.tsv
bidsdir=${rdspath}/growthcharts/dev/${study}/code/BCP-pipeline-testing/BIDS/derivatives/${pipeline}/
segmentationdir=${rdspath}/growthcharts/dev/${study}/code/register-BCP-BOPS/BIDS/

#############################################################
# STEP 1: MAKE REQUIREMENTS AVAILABLE
#############################################################

# REQUIREMENT 1: GET PATH TO TOOL FOLDER
TOOLPATH=${rdspath}/growthcharts/tools/

# REQUIREMENT 2: GET PATH TO FREESURFER SINGULARITY
FS_SINGULARITY=${TOOLPATH}/freesurfer/freesurfer_7.4.1.sif
FS_LICENSE=${TOOLPATH}/freesurfer/license.txt

# REQUIREMENT 3: ACTIVATE PYTHON ENVIRONMENT
echo "Start python environment"
# Setup SynthSeg
# Will need to make conda available - change this to your own conda installation
source /home/ld548/software/miniconda3/etc/profile.d/conda.sh
conda activate ${rdspath}/growthcharts/tools/synthseg/conda-envs/envs/synthseg_38
synthsegpath=${rdspath}/growthcharts/tools/synthseg/SynthSeg/
echo "Started python environment"

#############################################################
# STEP 2: READ IN DATA
#############################################################

# Get processing file info from list of all files to process
# Get the line corresponding to the array task (skip header)
line=$(sed -n "$((SLURM_ARRAY_TASK_ID))p" "$allt1s")
# Parse columns to get file info
read -r subject session acq sex age <<< "$line"

derivatives_dir=${bidsdir}/${subject}/${session}/

#############################################################
# STEP 3: GET APARC+ASEG FILE INTO NATIVE SPACE
#############################################################
input_dir=${rdspath}/growthcharts/data/BCP/BIDS/${subject}/${session}/anat/
input_file=${subject}_${session}_acq-MRP_run-001_${modality}.nii.gz

aparc_resampled=${subject}_${session}_acq-MRP_run-001_${res}_aseg+aparc-native.nii.gz

singularity run --cleanenv \
  --env FS_LICENSE=${FS_LICENSE} \
  --env SUBJECTS_DIR="${derivatives_dir}/surfaces/" \
  -B ${FS_LICENSE}:/opt/freesurfer/license.txt \
  -B ${derivatives_dir}:/derivatives \
  -B ${input_dir}:/input \
  ${FS_SINGULARITY} \
  mri_vol2vol \
    --mov /derivatives/surfaces/${subject}/mri/aparc+aseg.mgz \
    --targ /input/${input_file} \
    --regheader \
    --interp nearest \
    --o /derivatives/${aparc_resampled}


#############################################################
# STEP 4: GET BOPS SEGMENTATION INTO BCP GRID 
#############################################################

groundtruth_segmentation=${segmentationdir}/${subject}/${session}/${subject}_${session}_run-001_from-BOPS_to-BCP_desc-rigid_dseg.nii.gz
resampled_groundtruth_segmentation=${derivatives_dir}/${subject}_${session}_run-001_desc-resampled-into-BCP_dseg.nii.gz

# Resample BOPS segementation into BCP grid. They are already in the same BCP space 
python voxel-grid.py --seg ${groundtruth_segmentation} --target ${derivatives_dir}/${aparc_resampled} --out ${resampled_groundtruth_segmentation}

#############################################################
# STEP 5: DICE ESTIMATION
#############################################################

### DICE BETWEEN BCP SYNTHSEG SEGMENTATION OUTPUT AND BOPS GROUNDTRUTH
rca_BOPS_labels=${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_desc-BOPS-labels_aseg+aparc-native.nii.gz

# Merge DK labels to match BOPS labels
python merge_synthseg_to_bops_labels.py ${derivatives_dir}/${aparc_resampled} ${rca_BOPS_labels}

# DICE
python estimate-dice.py \
  ${resampled_groundtruth_segmentation} \
  ${rca_BOPS_labels} \
  /home/ld548/rds/rds-kw350-meld/growthcharts/dev/BOPS/BIDS/LUT.txt \
  ${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_T1w_dice-scores-BOPS-labels.csv

### DICE BETWEEN QC-LABEL CLASSES IN BCP SYNTHSEG SEGMENTATION OUTPUT AND BOPS GROUNDTRUTH

# DICE comparison with SynthSeg-QC-label-segmentation
rca_QC_merged_labels=${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_desc-aparc+aseg-QC-merged-labels_T1w_labels.nii.gz
groundtruth_QC_merged_labels=${derivatives_dir}/${subject}_${session}_run-001_desc-QC-merged-labels_dseg.nii.gz

# Merge labels to match SynthSeg QC classes
python merge_qc_labels.py ${rca_BOPS_labels} ${rca_QC_merged_labels}
python merge_qc_labels.py ${resampled_groundtruth_segmentation} ${groundtruth_QC_merged_labels}

# DICE
python estimate-dice.py ${groundtruth_QC_merged_labels} ${rca_QC_merged_labels} LUT.qc-labels.txt ${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_T1w_dice-scores-qc-labels.csv










