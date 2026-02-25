#!/bin/bash
#SBATCH --job-name=Dice
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=1
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU
#SBATCH --output=logs/DICE_resize_%a.txt
#SBATCH --array=2-73
#SBARCH --partition=icelake

now=$(date +"%T")
echo "Starting"
echo "Current time : $now"

study='BOPS'

echo "Setting up files"
mkdir logs # to save log files in 

# Basepath - this is what you'd have to change to your account:
rdspath=/rds/project/kw350/rds-kw350-meld/

pipeline='synthseg-robust-resize'

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

# BOPS groundtruth segmentation
groundtruth_segmentation=${segmentationdir}/${subject}/${session}/${subject}_${session}_run-001_from-BOPS_to-BCP_desc-rigid_dseg.nii.gz

# Get SynthSeg segmentation
resize_folder=$(ls ${bidsdir}/${subject}/${session})
res=${resize_folder#*_res-}   # remove everything up to "res-"
res=${res%%_*}
inv_resolution=$(printf '%s / %s\n' "1" "$res" | bc -l)
res='res-'${res}

derivatives_dir=${bidsdir}/${subject}/${session}/${resize_folder}/
synthseg_segmentation=${derivatives_dir}/${subject}_${session}_acq-MRP_run-001_${res}_T1w_seg.nii.gz

echo 'BOPS segmentation in BCP space: '${groundtruth_segmentation}
echo 'SynthSeg segmentation: '${synthseg_segmentation}

#############################################################
# STEP 3: GET RESIZED PARCELLATION INTO NATIVE SPACE 
#############################################################
input_dir=${rdspath}/growthcharts/data/BCP/BIDS/${subject}/${session}/anat/
cp ${input_dir}/${subject}_${session}_acq-MRP_run-001_T1w.nii.gz ${bidsdir}/${subject}/${session}/${resize_folder}/

seg_resize_space=${subject}_${session}_acq-MRP_run-001_${res}_desc-resized-space_T1w_seg.nii.gz
seg_synthseg_output=${subject}_${session}_acq-MRP_run-001_${res}_T1w_seg.nii.gz
resized_T1=${subject}_${session}_acq-MRP_run-001_${res}_T1w.nii.gz
seg_native=${subject}_${session}_acq-MRP_run-001_${res}_desc-native-headerchange_T1w_seg.nii.gz

if false; then

singularity run --cleanenv \
  --env FS_LICENSE="${TOOLPATH}/freesurfer/license.txt" \
  --env SUBJECTS_DIR="${derivatives_dir}/" \
  -B "${TOOLPATH}/freesurfer/license.txt:/opt/freesurfer/license.txt" \
  -B "${derivatives_dir}/:/derivatives" \
  -B "${input_dir}:/anat" \
  "${TOOLPATH}/freesurfer/freesurfer_7.4.1.sif" \
  mri_vol2vol \
    --mov /derivatives/${seg_synthseg_output} \
    --targ /derivatives/${resized_T1} \
    --regheader \
    --interp nearest \
    --o /derivatives/${seg_resize_space}

echo "Resampled SynthSeg segmentation to input native space"

python ${TOOLPATH}/reconall-clinical-resampling/change_resolution_header.py \
        -i ${derivatives_dir}/${seg_resize_space} \
        -o ${derivatives_dir}/${seg_native} \
        -s ${inv_resolution} \
        --force-int

echo "Header change resampled SynthSeg segmentation"
fi

#############################################################
# STEP 4: DICE COMPARISON
#############################################################


resampled_groundtruth_segmentation=${derivatives_dir}/${subject}_${session}_run-001_desc-resampled-into-BCP_dseg.nii.gz

if false; then
# Resample BOPS segementation into BCP grid. They are already in the same BCP space 
python voxel-grid.py --seg ${groundtruth_segmentation} --target ${derivatives_dir}/${seg_native} --out ${resampled_groundtruth_segmentation}
fi

# Merge cortical labels for comparison with the ground truth 'cortex' labels
#SS_seg_merged_labels=${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_desc-SS-seg-merged-labels_T1w_labels.nii.gz

# DICE comparison with ground truth segmentation
#python merge_ctx_labels.py ${derivatives_dir}/${seg_native} ${SS_seg_merged_labels}

#python dice_per_region.py ${resampled_groundtruth_segmentation} ${SS_seg_merged_labels} ${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_T1w_dice-scores.csv

### DICE BETWEEN BCP SYNTHSEG SEGMENTATION OUTPUT AND BOPS GROUNDTRUTH
SS_BOPS_labels=${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_desc-BOPS-labels_seg.nii.gz
python merge_synthseg_to_bops_labels.py ${derivatives_dir}/${seg_native} ${SS_BOPS_labels}
python estimate-dice.py \
  ${resampled_groundtruth_segmentation} \
  ${SS_BOPS_labels} \
  /home/ld548/rds/rds-kw350-meld/growthcharts/dev/BOPS/BIDS/LUT.txt \
  ${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_T1w_dice-scores-BOPS-labels.csv

### DICE BETWEEN QC-LABEL CLASSES IN BCP SYNTHSEG SEGMENTATION OUTPUT AND BOPS GROUNDTRUTH
# DICE comparison with SynthSeg-QC-label-segmentation
SS_QC_merged_labels=${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_desc-SS-QC-merged-labels_T1w_labels.nii.gz
groundtruth_QC_merged_labels=${derivatives_dir}/${subject}_${session}_run-001_desc-QC-merged-labels_dseg.nii.gz

python merge_qc_labels.py ${SS_BOPS_labels} ${SS_QC_merged_labels}
python merge_qc_labels.py ${resampled_groundtruth_segmentation} ${groundtruth_QC_merged_labels}

python estimate-dice.py ${groundtruth_QC_merged_labels} ${SS_QC_merged_labels} LUT.qc-labels.txt ${derivatives_dir}/${subject}_${session}_acq-MPR_run-001_T1w_dice-scores-qc-labels.csv









