#!/usr/bin/env python3
"""
Apply transform to segmentation from command line.

Example:
  python ants_apply_transform.py \
    --fixed fixed.nii.gz \
    --moving moving.nii.gz \
    --transform transform.mat \
    --outfile moving_in_fixed_rigid.nii.gz 

Notes:
- Requires: pip install antspyx
- Works for NIfTI/MHA/etc supported by ANTs.
"""

import argparse
import os
import sys

import ants


def parse_args():
    p = argparse.ArgumentParser(
        description="Rigid registration using ANTsPy (ants.registration, type_of_transform=Rigid)."
    )
    p.add_argument("--fixed", required=True, help="Fixed/reference image (target space).")
    p.add_argument("--moving", required=True, help="Moving image (to be aligned to fixed).")
    p.add_argument(
        "--outfile",
        required=True,
        help="Output path for registration file in target space (in fixed space).",
    )

    return p.parse_args()


def main():
    args = parse_args()

    fixed_path = os.path.abspath(args.fixed)
    moving_path = os.path.abspath(args.moving)
    out_warped = os.path.abspath(args.out_warped)

    if not os.path.exists(fixed_path):
        print(f"ERROR: fixed image not found: {fixed_path}", file=sys.stderr)
        sys.exit(2)
    if not os.path.exists(moving_path):
        print(f"ERROR: moving image not found: {moving_path}", file=sys.stderr)
        sys.exit(2)

    # Read images
    fixed = ants.image_read(fixed_path)
    moving = ants.image_read(moving_path)

     # Rigid registration (writes transforms to disk)
    prefix = os.path.abspath(args.out_warped).replace(".nii.gz", "").replace(".nii", "")

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

if __name__ == "__main__":
    main()

