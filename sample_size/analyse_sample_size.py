#!/usr/bin/env python3
import os
import glob
import numpy as np
import nibabel as nib
from scipy import stats
import math
import argparse


# -------- USER PARAMETERS --------
Z_FILENAME = "cope1.feat/thresh_zstat1.nii.gz"   # group-level z-map filename inside each iter folder
P_FILENAME = "cope1.feat/thresh_pstat1.nii.gz"   # (optional) group-level p-map
#SIG_FILENAME = "group_sig.nii.gz"  # (optional) binary significance map after correction
THRESHOLD_Z = 2.3              # if no binary maps: threshold to binarize Z maps (e.g., 3.2). If None, require group_sig present.
TWO_SIDED = True                # whether threshold corresponds to two-sided z
CONSENSUS_PCT = 0.5             # voxels present in >=50% of subsamples to be in consensus map
ROI_MASK = None                 # path to ROI nifti to compute ROI-level power (or None)
SIZE=[10, 15, 20, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39]      # list of sample sizes to process
SIZE=[10, 15, 20, 25, 30, 35, 39]     # list of sample sizes to process
#SIZE=[39]      # list of sample sizes to process
# ---------------------------------

# ---------------------------------
# TODO 23

def get_parser():
    parser = argparse.ArgumentParser(
        description="Compute frequency map of gorup level analysis with Monte Carlo.",)
    parser.add_argument('-path-in', required=True, type=str,
                        help="Path data_processed where the tSNR maps are stored.")
    parser.add_argument('-o', required=False, type=str,
                        help="Path output to put results.")

    return parser

def load_iter_folders(root_glob):
    folders = sorted(glob.glob(root_glob))
    print(folders)
    return [f for f in folders if os.path.isdir(f)]

def load_nifti_data(path):
    img = nib.load(path)
    return img.get_fdata(), img.affine, img.header

def save_nifti(data, affine, header, outpath):
    img = nib.Nifti1Image(data.astype(np.float32), affine, header)
    nib.save(img, outpath)
    print("Saved:", outpath)

def wilson_ci(k, n, conf=0.95):
    """Return (lower, upper) Wilson score interval for k successes out of n trials."""
    if n == 0:
        return (0.0, 1.0)
    z = stats.norm.ppf(1 - (1-conf)/2)
    phat = k / n
    denom = 1 + z*z/n
    centre = (phat + z*z/(2*n)) / denom
    margin = z * math.sqrt((phat*(1-phat)/n) + (z*z/(4*n*n))) / denom
    lo = max(0.0, centre - margin)
    hi = min(1.0, centre + margin)
    return lo, hi

def main():
    # Load iteration folders
    args = get_parser().parse_args()
    input_folder = os.path.abspath(args.path_in)
    output_folder = os.path.abspath(args.o) if args.o is not None else os.getcwd()
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    os.chdir(output_folder)

    for n in SIZE:
        OUT_PREFIX=f'n{n}'
        print(f"Processing size {n} ...")
        global ITER_GLOB
        ITER_GLOB = os.path.join(input_folder, f"n{n}", f"sample_size_{n}_iter_*.gfeat")
        print(f"Looking for iteration folders in {ITER_GLOB} ...")
        iter_folders = load_iter_folders(ITER_GLOB)
        n_iters = len(iter_folders)
        if n_iters == 0:
            raise SystemExit("No iteration folders found. Check ROOT/ITER_GLOB.")

        # Read first available file to grab shape/affine/header
        sample_folder = iter_folders[0]
        z_path = os.path.join(sample_folder, Z_FILENAME)
        if not os.path.exists(z_path):
            z_path = os.path.join(sample_folder, Z_FILENAME.replace("cope1", "cope4"))
            if not os.path.exists(z_path):
                raise SystemExit(f"No {Z_FILENAME} in {sample_folder}")
        sample_data, affine, header = load_nifti_data(z_path)

        shape = sample_data.shape
    
        # iterate
        z_stack_count = 0
        z_stack = []
        sig_count = np.zeros(shape, dtype=np.int32)
        #t_stack_count = 0
        #t_stack = []
        #sig_count = np.zeros(shape, dtype=np.int32)    
        z_sum = np.zeros(shape, dtype=np.float64)
        for idx, folder in enumerate(iter_folders):
            if idx % 50 == 0:
                print(f"Processing {idx+1}/{n_iters} ...")
            z_path = os.path.join(folder, Z_FILENAME)

            if not os.path.exists(z_path):
                z_path = os.path.join(folder, Z_FILENAME.replace("cope1", "cope4"))
                if not os.path.exists(z_path):
                    raise SystemExit(f"No {Z_FILENAME} in {folder}")
            zdata, _, _ = load_nifti_data(z_path)
            # accumulate z
            z_sum += np.nan_to_num(zdata)
            z_stack.append(zdata)
            z_stack_count += 1
            # binarize z map
            thresh = THRESHOLD_Z
            if thresh is None:
                raise SystemExit("THRESHOLD_Z not set. Cannot binarize z-maps.")
            if TWO_SIDED:
                binary = (np.abs(zdata) >= thresh).astype(np.int32)
            else:
                binary = (zdata >= thresh).astype(np.int32)

            sig_count += binary

        # Mean and median z-maps
        mean_z = z_sum / z_stack_count
        # Check if z_stack has values above 0
        if any(np.any(z > 0) for z in z_stack):
            print("yes!")
        median_z = np.median(np.stack(z_stack, axis=0), axis=0)
        save_nifti(mean_z, affine, header, f"{OUT_PREFIX}_mean_z.nii.gz")
        save_nifti(median_z, affine, header, f"{OUT_PREFIX}_median_z.nii.gz")

        # Frequency map (proportion)
        freq_map = sig_count.astype(np.float32) / float(n_iters)
        save_nifti(freq_map, affine, header, f"{OUT_PREFIX}_freq_map.nii.gz")

        # Wilson CI maps (optional)
        lo_map = np.zeros(shape, dtype=np.float32)
        hi_map = np.zeros(shape, dtype=np.float32)
        for idx_vox in np.ndindex(shape):
            k = int(sig_count[idx_vox])
            lo, hi = wilson_ci(k, n_iters, conf=0.95)
            lo_map[idx_vox] = lo
            hi_map[idx_vox] = hi
        save_nifti(lo_map, affine, header, f"{OUT_PREFIX}_freq_ci95_lo.nii.gz")
        save_nifti(hi_map, affine, header, f"{OUT_PREFIX}_freq_ci95_hi.nii.gz")

        # Consensus map at CONSENSUS_PCT
        thresh_count = int(np.ceil(CONSENSUS_PCT * n_iters))
        consensus = (sig_count >= thresh_count).astype(np.int32)
        save_nifti(consensus, affine, header, f"{OUT_PREFIX}_consensus_{int(CONSENSUS_PCT*100)}pct.nii.gz")

        # ROI-level power if ROI provided
        if ROI_MASK is not None:
            roi_data, _, _ = load_nifti_data(ROI_MASK)
            roi_bool = roi_data != 0
            roi_vox = roi_bool.sum()
            # count per iteration how many have any overlap
            # We need to re-scan iterations to check overlap per iter (unless we saved per-iter overlap)
            overlap_counts = 0
            for folder in iter_folders:
               # sig_path = os.path.join(folder, SIG_FILENAME)
                z_path = os.path.join(folder, Z_FILENAME)
                if os.path.exists(sig_path):
                    sd, _, _ = load_nifti_data(sig_path)
                    binary = (sd != 0)
                else:
                    td, _, _ = load_nifti_data(t_path)
                    if TWO_SIDED:
                        binary = (np.abs(td) >= THRESHOLD_T)
                    else:
                        binary = (td >= THRESHOLD_T)
                overlap = np.logical_and(binary, roi_bool).sum()
                if overlap > 0:
                    overlap_counts += 1
            roi_power = overlap_counts / n_iters
            lo, hi = wilson_ci(overlap_counts, n_iters, 0.95)
            print(f"ROI power (overlap any voxel): {roi_power:.3f} (95% CI: {lo:.3f} - {hi:.3f}), n_iters={n_iters}")

        # Dice vs full-sample map (if available)
        # fullmap_path = os.path.join(ROOT, "full_sample_group_sig.nii.gz")
        # if os.path.exists(fullmap_path):
        #     full_data, _, _ = load_nifti_data(fullmap_path)
        #     full_bin = (full_data != 0).astype(np.int32)
        #     dice_list = []
        #     # compute per-iteration dice (may be slow)
        #     for folder in iter_folders:
        #         sig_path = os.path.join(folder, SIG_FILENAME)
        #         if os.path.exists(sig_path):
        #             sd, _, _ = load_nifti_data(sig_path)
        #             binmap = (sd != 0).astype(np.int32)
        #         else:
        #             zd, _, _ = load_nifti_data(os.path.join(folder, Z_FILENAME))
        #             binmap = (np.abs(zd) >= THRESHOLD_Z).astype(np.int32)
        #         inter = (binmap & full_bin).sum()
        #         a = binmap.sum()
        #         b = full_bin.sum()
        #         if a + b == 0:
        #             dice = np.nan
        #         else:
        #             dice = 2*inter / (a + b)
        #         dice_list.append(dice)
        #     dice_arr = np.array(dice_list, dtype=np.float32)
        #     print(f"Dice vs full-sample map: mean={np.nanmean(dice_arr):.3f}, sd={np.nanstd(dice_arr):.3f}")

        print("Done.")

if __name__ == "__main__":
    main()
