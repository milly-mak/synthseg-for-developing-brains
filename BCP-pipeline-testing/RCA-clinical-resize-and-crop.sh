#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --array=2-73
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
#SBATCH --job-name=RCAresBCP
#SBATCH --output=logs/RCA-clinical-resize-and-crop-%a.txt
#SBATCH --partition=icelake-himem
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU

# Run with 10 CPU and 6h for +0.2

modality=T1w # T2
study=BOPS

rdspath=/rds/project/kw350/rds-kw350-meld/growthcharts/

#############################################################
# STEP 1: MAKE REQUIREMENTS AVAILABLE
#############################################################

# REQUIREMENT 1: GET PATH TO TOOL FOLDER
TOOLPATH=${rdspath}/tools/reconall-clinical-resampling/

# REQUIREMENT 2: GET PATH TO LBCC BRAINCHART MODELS
LBCC_PATH=${rdspath}/tools/LBCC-lifespan-models/

# REQUIREMENT 3: GET PATH TO FREESURFER SINGULARITY
FS_SINGULARITY=${rdspath}/tools/freesurfer/freesurfer_7.4.1.sif
FS_LICENSE=${rdspath}/tools/freesurfer/license.txt

# REQUIREMENT 4: ACTIVATE PYTHON ENVIRONMENT
# Activate a python environment that has the following packages installed:
echo "Start python environment"
# Setup SynthSeg
# Will need to make conda available - change this to your own conda installation
source /home/ld548/software/miniconda3/etc/profile.d/conda.sh
conda activate ${rdspath}/tools/synthseg/conda-envs/envs/synthseg_38
synthsegpath=${rdspath}/tools/synthseg/SynthSeg/
echo "Started python environment"


#############################################################
# STEP 2: GET PATHS TO RELEVANT SCAN AND SUBJECT INFO
#############################################################

# For convenience, I have a lot of relevant scan info in a table
# We use this table further below
# Columns are: subject-id | session | acquisition | irrelevant | age in days 
allt1s=${rdspath}/dev/${study}/code/preprocessing/all-T1s.tsv
bidsdir=${rdspath}/data/BCP/BIDS/


# Read the row at the specified index
row=$(sed "${SLURM_ARRAY_TASK_ID}q;d" "$allt1s")
subject=$(echo "$row" | awk '{print $1}')
session=$(echo "$row" | awk '{print $2}')
acq='acq-MRP'
run='run-001'
age_days=$(echo "$row" | awk '{print $5}')

anatdir=${bidsdir}/${subject}/${session}/anat/
filename=/${subject}_${session}_${acq}_${run}_${modality}.nii.gz

#############################################################
# STEP 3: SETUP PIPELINE INPUT PATHS
#############################################################

# Extract data from each column into separate variables
SUBID=${subject}
AGE_DAYS=${age_days}
# ${SCAN_IDENTIFIER}_${MODALITY}.nii.gz should be input file
#SCAN_IDENTIFIER=${subid}_${ses}_${acq}
MODALITY=${modality}
SCALE=0.5
OUTDIR=${rdspath}/dev/${study}/code/BCP-pipeline-testing/BIDS/derivatives/reconall-clinical-resize-and-crop/${SUBID}/${session}/
INPUT_FILE=${anatdir}/${filename}

#############################################################
# STEP 4: GET THINGS RUNNING
#############################################################

${TOOLPATH}/reconall-clinical-resize-and-crop.sh \
       --subid=${SUBID} \
       --age_days=${AGE_DAYS} \
       --input_file=${INPUT_FILE} \
       --modality=${MODALITY} \
       --scale=${SCALE} \
       --outdir=${OUTDIR} \
       --fs_singularity=${FS_SINGULARITY} \
       --fs_license=${FS_LICENSE} \
       --toolpath=${TOOLPATH} 


