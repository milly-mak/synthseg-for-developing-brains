#!/usr/bin/env python3
# estimate-dice.py
# Usage: python estimate-dice.py <img_orig> <img_comp> <lut.txt> <out_csv>

import sys
import numpy as np
import pandas as pd
import nibabel as nb

if len(sys.argv) != 5:
    print("Usage: python dice_from_lut_simple.py <img_orig> <img_comp> <lut> <out_csv>")
    sys.exit(1)

img_orig = sys.argv[1]
img_comp = sys.argv[2]
lut_path = sys.argv[3]
out_csv  = sys.argv[4]

# load images
mask_orig = nb.load(img_orig).get_fdata().astype(np.int32)
mask_comp = nb.load(img_comp).get_fdata().astype(np.int32)

# load LUT (extra columns allowed; we just ignore them)
lut = pd.read_csv(
    lut_path,
    sep=r"\s+",
    comment="#",
    header=None,
    names=["index", "name", "R", "G", "B", "A"],
    engine="python",
)

lut = lut[["index", "name"]].drop_duplicates()
lut = lut[(lut["index"] != 0) & (lut["name"] != "Unknown")].reset_index(drop=True)

def dice_for_value(a, b, val):
    A = (a == val)
    B = (b == val)
    inter = np.count_nonzero(A & B)
    denom = np.count_nonzero(A) + np.count_nonzero(B)
    return (2.0 * inter / denom) if denom > 0 else np.nan

rows = []
for _, r in lut.iterrows():
    idx = int(r["index"])
    d = dice_for_value(mask_orig, mask_comp, idx)
    rows.append((r["name"], idx, idx, d, img_comp))

dice_df = (pd.DataFrame(rows, columns=["name","index_orig","index_comp","dice","img_comp_path"])
             .sort_values("dice", ascending=True)
             .reset_index(drop=True))

dice_df.to_csv(out_csv, index=False)
