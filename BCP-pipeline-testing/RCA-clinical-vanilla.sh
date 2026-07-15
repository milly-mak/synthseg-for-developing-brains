#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --array=1-72
#SBATCH --cpus-per-task=4
#SBATCH --time=02:00:00
#SBATCH --job-name=ResBOPS
#SBATCH --output=logs/RCA-clinical-vanilla-%a.txt
#SBATCH --partition=icelake-himem
#SBATCH --account=CORE-WCHN-MELD-SL2-CPU

modality=T1w
study=BOPS

now=$(date +"%T")
echo "Start time : $now"

rdspath=/rds/project/kw350/rds-kw350-meld/

############################################################
# STEP 1: MAKE REQUIREMENTS AVAILABLE
#############################################################

# REQUIREMENT 1: GET PATH TO TOOL FOLDER
TOOLPATH=${rdspath}/growthcharts/tools/

# REQUIREMENT 2: GET PATH TO FREESURFER SINGULARITY
FS_SINGULARITY=${TOOLPATH}/freesurfer/freesurfer_7.4.1.sif
FS_LICENSE=${TOOLPATH}/freesurfer/license.txt

#############################################################
# STEP 2: GET PATHS TO RELEVANT SCAN AND SUBJECT INFO
#############################################################

allt1s=${rdspath}/growthcharts/dev/${study}/code/preprocessing/all-T1s.tsv
bidsdir=${rdspath}/growthcharts/data/BCP/BIDS/

row=$(sed "${SLURM_ARRAY_TASK_ID}q;d" "$allt1s")
subject=$(echo "$row" | awk '{print $1}')
session=$(echo "$row" | awk '{print $2}')
acq='acq-MRP'
run='run-001'

anatdir=${bidsdir}/${subject}/${session}/anat/
filename=/${subject}_${session}_${acq}_${run}_${modality}.nii.gz
INPUT_FILE=${anatdir}/${filename}

NTHREADS=4

OUTDIR=${rdspath}/growthcharts/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/reconall-clinical/${subject}/${session}/surfaces/

mkdir -p ${OUTDIR}


#############################################################
# STEP 3: RUN RECON-ALL CLINICAL
#############################################################


singularity run --cleanenv \
--env FS_LICENSE=${FS_LICENSE} \
--env SUBJECTS_DIR=${OUTDIR} \
-B ${FS_LICENSE}:/opt/freesurfer/license.txt \
-B ${OUTDIR}:/derivatives \
-B ${anatdir}:/input \
${FS_SINGULARITY} \
recon-all-clinical.sh \
/input/${filename} \
${subject} \
$NTHREADS \
/derivatives/





