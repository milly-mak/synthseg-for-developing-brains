#!/usr/bin/env python3
import argparse
import os
import ants


def parse_args():
    p = argparse.ArgumentParser(
        description="Resample a segmentation onto a target image grid (nearest-neighbour)."
    )
    p.add_argument("--seg", required=True, help="Segmentation to resample (e.g., BOPS seg in BCP space).")
    p.add_argument("--target", required=True, help="Target image defining the grid (e.g., BCP SynthSeg seg or BCP T1).")
    p.add_argument("--out", required=True, help="Output path for resampled segmentation.")
    return p.parse_args()


def main():
    args = parse_args()

    seg_path = os.path.abspath(args.seg)
    target_path = os.path.abspath(args.target)
    out_path = os.path.abspath(args.out)

    seg = ants.image_read(seg_path)
    target = ants.image_read(target_path)

    seg_on_target = ants.resample_image_to_target(
        image=seg,
        target=target,
        interp_type="nearestNeighbor"
    )

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    ants.image_write(seg_on_target, out_path)


if __name__ == "__main__":
    main()

