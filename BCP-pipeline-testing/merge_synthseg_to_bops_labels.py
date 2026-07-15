#!/usr/bin/env python3
# This script merges SynthSeg segmentation labels to match the BOPS segmentation labels
# Specifically, BOPS does not have cortical regions, but rather a global 'Left/right-Cerebral-Cortex' label
#
# merge_synthseg_to_bops_labels.py
# Usage: python merge_synthseg_to_bops_labels.py input_synthseg.nii.gz output_bopslabels.nii.gz

import sys
import numpy as np
import nibabel as nb

def main(in_path, out_path):
    img = nb.load(in_path)
    data = np.asarray(img.dataobj).astype(np.int32, copy=True)

    # Merge DK cortical labels -> BOPS cortical labels
    # FreeSurfer LUT's use numbers over 1000 for left, and over 2000 for right cortical regions
    data[(data >= 1000) & (data <= 1999)] = 3   # Left-Cerebral-Cortex
    data[(data >= 2000) & (data <= 2999)] = 42  # Right-Cerebral-Cortex

    # Drop labels we don't want because BOPS doesnt include it
    #drop_vals = [172, 77, 85, 30, 62, 31, 63]  # Vermis, WM-hypo, Optic-Chiasm, vessels, choroid plexus
    #data[np.isin(data, drop_vals)] = 0

    # Save out results
    out_img = nb.Nifti1Image(data, img.affine, img.header)
    out_img.set_data_dtype(np.int32)
    nb.save(out_img, out_path)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python merge_synthseg_to_bops_labels.py input_synthseg.nii.gz output_bopslabels.nii.gz")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
