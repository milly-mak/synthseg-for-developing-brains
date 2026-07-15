#!/bin/bash
#SBATCH --job-name=SSR
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=12
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU
#SBATCH --output=logs/SSr_resize_%A_%a.txt
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
#run=$(echo "$row" | awk '{print $4}')
age_days=$(echo "$row" | awk '{print $5}')

run='run-001'
# Create variables the point to file to be processed
anatdir=${bidsdir}/${subject}/${session}/anat/
filename=/${subject}_${session}_${acq}_${run}_${modality}.nii.gz
INPUT_FILE=${anatdir}/${filename}
MODALITY=${modality}
SCALE=0.5

# Create output file paths
OUTDIR=${rdspath}/growthcharts/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/${subject}/${session}/

#if [[ ! -f ${OUTDIR}/*/*seg.nii.gz ]]; then

#############################################################
# STEP 3: RESIZE INPUT IMAGE
#############################################################

csv_file="${TOOLPATH%/}/reconall-clinical-resampling/scaling-factor.csv"
scale_suffix="$(awk -v s="$SCALE" 'BEGIN{if(!(s>0&&s<1)) exit 1; printf "%.0f", s*1000}')"
col="scalefactor_adj_perc${scale_suffix}"


AGE_DAYS_ROUNDED=$(printf "%.0f" "$age_days")
# Check if rounding changed the value
if (( $(echo "$age_days != $AGE_DAYS_ROUNDED" | bc -l) )); then
  echo "Warning: age_days ($age_days) was rounded to nearest full day ($AGE_DAYS_ROUNDED)" >&2
  AGE_DAYS=${AGE_DAYS_ROUNDED}
fi

scale_factor="$(
  awk -v age="$AGE_DAYS" -v col="$col" -F',' '
    NR==1{
      for(i=1;i<=NF;i++){ gsub(/^"|"$/,"",$i); if($i=="age_days") A=i; if($i==col) C=i }
      next
    }
    {
      # strip quotes on the fields we care about (robust if some rows are quoted)
      if (A) { tmp=$A; gsub(/^"|"$/,"",tmp); $A=tmp }
      if (C) { tmp=$C; gsub(/^"|"$/,"",tmp); $C=tmp }
    }
    $A==age { print $C; exit }
  ' "$csv_file"
)"

echo "Rescale data"
# Extract the filename (without extension)
filename=$(basename "$INPUT_FILE" .nii.gz)
# If the filename ends with "_${MODALITY}", strip it
if [[ "$filename" == *_${MODALITY} ]]; then
    scan_identifier="${filename%_${MODALITY}}"
else
    scan_identifier="$filename"
fi

resampled_scan=${scan_identifier}_res-${scale_factor}_${MODALITY}
resampled_file=${OUTDIR}/${resampled_scan}/${resampled_scan}.nii.gz

#if false; then
mkdir -p ${OUTDIR}/${resampled_scan}/
python ${TOOLPATH}/reconall-clinical-resampling/change_resolution_header.py -i ${INPUT_FILE} -o ${resampled_file} -s ${scale_factor}

now=$(date +"%T")
echo "Resized image;  Current time : $now"
#fi

#############################################################
# STEP 5: RUN SYNTHSEG
#############################################################

preprocessed_identifier=${resampled_scan}
outcsv=${OUTDIR}/${resampled_scan}/${preprocessed_identifier}_volumes.csv
outqc=${OUTDIR}/${resampled_scan}/${preprocessed_identifier}_qc.csv
outseg=${OUTDIR}/${resampled_scan}/${preprocessed_identifier}_seg.nii.gz

# If this file exists, run synthseg
if [[ -f ${OUTDIR}/${resampled_scan}/${preprocessed_identifier}.nii.gz ]]; then
        python ${synthsegpath}/scripts/commands/SynthSeg_predict.py --i ${OUTDIR}/${resampled_scan}/${preprocessed_identifier}.nii.gz --o ${outseg} --parc --robust --vol ${outcsv} --qc ${outqc}
	echo "Ran SynthSeg;  Current time : $now"
fi

conda deactivate

now=$(date +"%T")

#fi


