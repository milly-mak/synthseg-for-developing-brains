#!/bin/bash
#SBATCH --job-name=Reg
#SBATCH --time=00:03:00
#SBATCH --cpus-per-task=2
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU
#SBATCH --output=logs/Reg_%A_%a.txt
#SBATCH --array=1-72
#

modality=T1w

now=$(date +"%T")
echo "Starting;  Current time : $now"


echo "Setting up files"
mkdir logs # to save log files in 

# Basepath - this is what you'd have to change to your account:
rdspath=/rds/project/kw350/rds-kw350-meld/

#############################################################
# STEP 1: MAKE REQUIREMENTS AVAILABLE
#############################################################

# REQUIREMENT 1: GET PATH TO TOOL FOLDER
TOOLPATH=${rdspath}/growthcharts/tools/

# REQUIREMENT 3: ACTIVATE PYTHON ENVIRONMENT
echo "Start python environment"
# Setup SynthSeg
# Will need to make conda available - change this to your own conda installation
source /home/ld548/software/miniconda3/etc/profile.d/conda.sh
conda activate ${rdspath}/growthcharts/tools/synthseg/conda-envs/envs/synthseg_38
synthsegpath=${rdspath}/growthcharts/tools/synthseg/SynthSeg/
echo "Started python environment"

#############################################################
# STEP 2: GET PATHS TO RELEVANT SCAN AND SUBJECT INFO
#############################################################

# Input paths
allt1s=${rdspath}/growthcharts/dev/BOPS/code/register-BCP-BOPS/all-T1s.tsv
bidsdir_BCP=${rdspath}/growthcharts/data/BCP/BIDS/
bidsdir_BOPS=${rdspath}/growthcharts/dev/BOPS/BIDS/

# Read the row at the specified index
row=$(sed "${SLURM_ARRAY_TASK_ID}q;d" "$allt1s")
subject=$(echo "$row" | awk '{print $1}')
session=$(echo "$row" | awk '{print $2}')
acq=$(echo "$row" | awk '{print $3}')
#acq='acq-MRP'
#run=$(echo "$row" | awk '{print $4}')
run='run-001'

# Create variables the point to file to be processed
anatdir_BCP=${bidsdir_BCP}/${subject}/${session}/anat/
anatdir_BOPS=${bidsdir_BOPS}/${subject}/${session}/anat/

BCP_T1=${anatdir_BCP}/${subject}_${session}_acq-MRP_${run}_${modality}.nii.gz
BOPS_T1=${anatdir_BOPS}/${subject}_${session}_${acq}_${modality}.nii.gz
BOPS_segmentation=${anatdir_BOPS}/${subject}_${session}_${acq}_desc-aseg_dseg.nii.gz 

# Create output file paths
OUTDIR=${rdspath}/growthcharts/dev/BOPS/code/register-BCP-BOPS/BIDS/${subject}/${session}/
mkdir -p ${OUTDIR}

#############################################################
# STEP 3: REGISTER
#############################################################

python ants_rigid_register.py \
    --fixed ${BCP_T1} \
    --moving ${BOPS_T1} \
    --out_warped ${OUTDIR}/${subject}_${session}_${run}_from-BOPS_to-BCP_desc-rigid_${modality}.nii.gz \
    --segmentation ${BOPS_segmentation} \
    --out_seg ${OUTDIR}/${subject}_${session}_${run}_from-BOPS_to-BCP_desc-rigid_dseg.nii.gz

conda deactivate

