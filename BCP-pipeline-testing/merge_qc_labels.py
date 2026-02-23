#!/usr/bin/env python3
# merge_ctx_labels.py
# Usage: python merge_ctx_labels.py input_parcellation.[nii|nii.gz] output_merged.nii.gz

import sys
import numpy as np
import nibabel as nb

def main(in_path, out_path):
    # Load image
    img = nb.load(in_path)
    data = np.asarray(img.dataobj).astype(np.int32, copy=True)

    # Merge cortical labels
    #data[(data >= 1000) & (data <= 1999)] = 3   # Left-Cerebral-Cortex
    #data[(data >= 2000) & (data <= 2999)] = 42  # Right-Cerebral-Cortex

    # Clean output image
    out = np.zeros_like(data, dtype=np.int32)

    # Output codes
    QC_WM   = 1  # qc.general.white.matter
    QC_GM   = 2  # qc.general.grey.matter
    QC_CSF  = 3  # qc.general.csf
    QC_CBL  = 4  # qc.cerebellum
    QC_BST  = 5  # qc.brainstem
    QC_THA  = 6  # qc.thalamus
    QC_PUTP = 7  # qc.putamen.pallidum
    QC_HIPA = 8  # qc.hippocampus.amygdala

    # qc.cerebellum (WM + cortex, both hemispheres)
    out[np.isin(data, [7, 8, 46, 47])] = QC_CBL

    # qc.brainstem
    out[data == 16] = QC_BST

    # qc.thalamus (L/R)
    out[np.isin(data, [10, 49])] = QC_THA

    # qc.putamen.pallidum (L/R putamen + pallidum)
    out[np.isin(data, [12, 13, 51, 52])] = QC_PUTP

    # qc.hippocampus.amygdala (L/R hippocampus + amygdala)
    out[np.isin(data, [17, 18, 53, 54])] = QC_HIPA

    # CSF
    out[np.isin(data, [4, 5, 14, 15, 24, 43, 44])] = QC_CSF
    # 4/43 lat vent, 5/44 inf lat vent, 14 third, 15 fourth, 24 CSF

    # Unassigned regions
    unassigned = (out == 0) & (data != 0)

    # White matter: cerebral WM 
    out[unassigned & np.isin(data, [2, 41, 28, 60])] = QC_WM

    # Grey matter: cortex + remaining “GM-ish” subcortical not otherwise bucketed
    unassigned = (out == 0) & (data != 0)
    out[unassigned & np.isin(data, [3, 42, 11, 50, 26, 58])] = QC_GM

    # Save as NIfTI
    out_img = nb.Nifti1Image(out, img.affine, img.header)
    out_img.set_data_dtype(np.int32)
    nb.save(out_img, out_path)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python merge_qc_labels.py input_parcellation.nii.gz output_merged.nii.gz")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])

