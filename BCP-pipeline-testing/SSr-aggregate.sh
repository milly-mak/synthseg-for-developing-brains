#!/bin/bash
# This script aggregates the SynthSeg Volumes and QC Scores 
study='BOPS'
basedir=/rds/project/kw350/rds-kw350-meld/growthcharts/

# VANILLA SS
SSoutputs=${basedir}/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust/
volumefiles=${SSoutputs}/sub-*/ses-*/*_T1w_volumes.csv
toolpath=${basedir}tools/synthseg/
${toolpath}/aggregate-synthseg-robust.sh --input "${volumefiles}" --output "${SSoutputs}" --csv "${study}_SS-volumes-qc-scores.csv"

# CROP ONLY
SSoutputs=${basedir}/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-crop/
volumefiles=${SSoutputs}/sub-*/ses-*/*desc-cropped_T1w_volumes.csv
toolpath=${basedir}tools/synthseg/
${toolpath}/aggregate-synthseg-robust.sh --input "${volumefiles}" --output "${SSoutputs}" --csv "${study}_SS-volumes-qc-scores.csv"

# RESIZE ONLY
SSoutputs=${basedir}/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize/
volumefiles=${SSoutputs}/sub-*/ses-*/*/*_volumes.csv
toolpath=${basedir}tools/synthseg/
${toolpath}/aggregate-synthseg-robust.sh --input "${volumefiles}" --output "${SSoutputs}" --csv "${study}_SS-volumes-qc-scores.csv"

# RESIZE AND CROP
SSoutputs=${basedir}/dev/BOPS/code/BCP-pipeline-testing/BIDS/derivatives/synthseg-robust-resize-crop/
volumefiles=${SSoutputs}/sub-*/ses-*/*/*_volumes.csv
toolpath=${basedir}tools/synthseg/
${toolpath}/aggregate-synthseg-robust.sh --input "${volumefiles}" --output "${SSoutputs}" --csv "${study}_SS-volumes-qc-scores.csv"






