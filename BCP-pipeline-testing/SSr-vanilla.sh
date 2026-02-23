#!/bin/bash
#SBATCH --job-name=SSV
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=8
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU
#SBATCH --output=logs/SSr_vanilla_%A_%a.txt
#SBATCH --array=2-73
#SBATCH --partition=icelake
#
# Prior to running this script, create a table of all T1s that need to be processed
# The script for creating the required table is located at:
# 	BCP/code/preprocessing/run_get-T1s.sh
# That script produces the file BCP/preprocessing/all-T1s.tsv.
# The number of rows in the output file BCP/preprocessing/all-T1s.tsv is the array number
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

# REQUIREMENT 2: ACTIVATE PYTHON ENVIRONMENT
echo "Start python environment"
# Setup SynthSeg
# Will need to make conda available - change this to your own conda installation
source /home/ld548/software/miniconda3/etc/profile.d/conda.sh
conda activate ${TOOLPATH}/synthseg/conda-envs/envs/synthseg_38


#############################################################
# STEP 2: GET PATHS TO RELEVANT SCAN AND SUBJECT INFO
#############################################################

# Input paths
allt1s=${rdspath}/growthcharts/dev/BOPS/code/BCP-pipeline-testing/all-T1s.tsv
bidsdir=${rdspath}/growthcharts/data/BCP/BIDS/

# Read the row at the specified index
row=$(sed "${SLURM_ARRAY_TASK_ID}q;d" "$allt1s")
subject=$(echo "$row" | awk '{print $1}')
session=$(echo "$row" | awk '{print $2}')
#acq=$(echo "$row" | awk '{print $3}')
acq='acq-MRP'
#age_days=$(echo "$row" | awk '{print $5}')

run='run-001'
# Create variables the point to file to be processed
anatdir=${bidsdir}/${subject}/${session}/anat/
filename=/${subject}_${session}_${acq}_${run}_${modality}.nii.gz
INPUT_FILE=${anatdir}/${filename}
MODALITY=${modality}
#SCALE=0.5

# Create output file paths
OUTDIR=${rdspath}/growthcharts/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/${subject}/${session}/

#if [[ ! -f ${OUTDIR}/*/*seg.nii.gz ]]; then

mkdir -p ${OUTDIR}

#############################################################
# STEP 5: RUN SYNTHSEG
#############################################################

preprocessed_identifier=${subject}_${session}_${acq}_${run}_${modality}
outcsv=${OUTDIR}/${preprocessed_identifier}_volumes.csv
outqc=${OUTDIR}/${preprocessed_identifier}_qc.csv
outseg=${OUTDIR}/${preprocessed_identifier}_seg.nii.gz

# If this file exists, run synthseg
if [[ -f ${INPUT_FILE} ]]; then
        python ${synthsegpath}/scripts/commands/SynthSeg_predict.py --i ${INPUT_FILE} --o ${outseg} --parc --robust --vol ${outcsv} --qc ${outqc}
	echo "Ran SynthSeg;  Current time : $now"
fi

conda deactivate

now=$(date +"%T")

#fi


