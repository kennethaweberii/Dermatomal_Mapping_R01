import nibabel as nib
import numpy as np
import os

# Paths to the group maps per run
cope="4"
path_in = "/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/group_level_spinal_cord"
group_level_dir = "run-3/GroupLevel_trialwise_N40_randomize_corr2.3.gfeat"
group_maps = [
    os.path.join(path_in, "run-1", "GroupLevel_trialwise_N40_randomize_corr2.3.gfeat", f"cope{cope}.feat", "stats", "zstat1.nii.gz"),
    os.path.join(path_in, "run-2", "GroupLevel_trialwise_N40_randomize_corr2.3.gfeat", f"cope{cope}.feat", "stats", "zstat1.nii.gz"),
    os.path.join(path_in, "run-3", "GroupLevel_trialwise_N40_randomize_corr2.3.gfeat", f"cope{cope}.feat", "stats", "zstat1.nii.gz")
]
output_dir = "/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/icc/group_level_randomize_uncorr"
os.makedirs(output_dir, exist_ok=True)


# Load maps into a 4D array
maps_data = [nib.load(f).get_fdata() for f in group_maps]
data = np.stack(maps_data, axis=-1)  # shape: X, Y, Z, n_runs
X, Y, Z, R = data.shape

icc_map = np.zeros((X, Y, Z), dtype=np.float32)
icc_map[:] = np.nan

# Compute voxelwise ICC across runs
for x in range(X):
    for y in range(Y):
        for z in range(Z):
            voxel = data[x, y, z, :]
            # ICC = variance / total variance (simplified for single “group” voxel)
            if np.all(np.isnan(voxel)):
                continue
            mean_voxel = np.mean(voxel)
            ss_total = np.sum((voxel - mean_voxel) ** 2)
            ss_between = np.var(voxel, ddof=1) * (R - 1)
            icc = ss_between / (ss_total + 1e-8) if ss_total > 0 else np.nan
            icc_map[x, y, z] = icc

# Save result
affine = nib.load(group_maps[0]).affine
icc_map = np.nan_to_num(icc_map, nan=0.0)
icc_img = nib.Nifti1Image(icc_map, affine)
nib.save(icc_img, os.path.join(output_dir, "group_level_ICC_per_run.nii.gz"))
print("✅ Saved group-level ICC map across runs")
