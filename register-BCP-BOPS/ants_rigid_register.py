#!/usr/bin/env python3
"""
Rigid registration (ANTsPy) from command line.

Example:
  python ants_rigid_register.py \
    --fixed fixed.nii.gz \
    --moving moving.nii.gz \
    --out_warped moving_in_fixed_rigid.nii.gz 

Notes:
- Requires: pip install antspyx
- Works for NIfTI/MHA/etc supported by ANTs.
"""

import argparse
import os
import sys
import ants
import numpy as np


def parse_args():
    p = argparse.ArgumentParser(
        description="Rigid registration using ANTsPy (ants.registration, type_of_transform=Rigid)."
    )
    p.add_argument("--fixed", required=True, help="Fixed/reference image (target space).")
    p.add_argument("--moving", required=True, help="Moving image (to be aligned to fixed).")
    p.add_argument(
        "--out_warped",
        required=True,
        help="Output path for rigid-warped moving image (in fixed space).",
    )
    p.add_argument("--segmentation", required=True, help="Segmentation (to be aligned to fixed).")
    p.add_argument("--out_seg", required=True, help="Output path for rigid-warped segmentation (in fixed space).")
    return p.parse_args()


def main():
    args = parse_args()

    fixed_path = os.path.abspath(args.fixed)
    moving_path = os.path.abspath(args.moving)
    out_warped = os.path.abspath(args.out_warped)
    seg_path = os.path.abspath(args.segmentation)
    out_seg = os.path.abspath(args.out_seg)


    if not os.path.exists(fixed_path):
        print(f"ERROR: fixed image not found: {fixed_path}", file=sys.stderr)
        sys.exit(2)
    if not os.path.exists(moving_path):
        print(f"ERROR: moving image not found: {moving_path}", file=sys.stderr)
        sys.exit(2)
    if not os.path.exists(seg_path):
        print(f"ERROR: fixed image not found: {seg_path}", file=sys.stderr)
        sys.exit(2)

    # Read images
    fixed = ants.image_read(fixed_path)
    moving = ants.image_read(moving_path)

     # Rigid registration (writes transforms to disk)
    prefix = os.path.abspath(args.out_warped).replace(".nii.gz", "_").replace(".nii", "_")

    # Rigid registration
    reg = ants.registration(
        fixed=fixed,
        moving=moving,
        type_of_transform="Rigid",
        outprefix=prefix
    )

    # reg["warpedmovout"] is the moving image resampled into fixed space
    warped = reg["warpedmovout"]
    ants.image_write(warped, out_warped)

    seg = ants.image_read(seg_path)

    seg_warped = ants.apply_transforms(
        fixed=fixed,                 # target space (same fixed image as before)
        moving=seg,                  # the segmentation to move
        transformlist=reg["fwdtransforms"],  # moving -> fixed
        interpolator="nearestNeighbor"
    )

    ants.image_write(seg_warped, out_seg)

    # QC plot 1: warped moving (BOPS T1) over fixed (BCP T1)
    qc_t1_png = out_warped.replace(".nii.gz", "_desc-qcOverlay_T1w.png").replace(".nii", "_desc-qcOverlay_T1w.png")
    ants.plot_ortho(
        fixed,
        overlay=warped,
        overlay_cmap="nipy_spectral",   # "NIH-like" colorful scale
        overlay_alpha=0.35,
        filename=qc_t1_png
    )

    c = [s // 2 for s in fixed.shape]
    c[0] = c[0] + 8

    qc_seg_png = out_warped.replace(".nii.gz", "_desc-qcOverlay_dseg.png").replace(".nii", "_desc-qcOverlay_dseg.png")

    seg_np = seg_warped.numpy().astype(np.int32)

    labs = np.unique(seg_np)
    labs = labs[labs != 0]  # keep 0 as background

    lut = np.zeros(seg_np.max() + 1, dtype=np.int32)
    lut[labs] = np.arange(1, len(labs) + 1, dtype=np.int32)

    seg_plot = lut[seg_np]

    seg_plot_img = ants.from_numpy(
        seg_plot,
        origin=seg_warped.origin,
        spacing=seg_warped.spacing,
        direction=seg_warped.direction,
    ).clone("float")

    ants.plot_ortho(
        fixed,
        overlay=seg_plot_img,
        xyz=c,
        overlay_cmap="gist_ncar",
        overlay_alpha=0.45,
        filename=qc_seg_png
    )

    
if __name__ == "__main__":
    main()

