import nibabel as nib
import numpy as np
import pingouin as pg
import pandas as pd
import glob
import os


import numpy as np

import os
import numpy as np
import nibabel as nib

def icc_3_1_group(data):
    """
    Compute ICC(3,1) for multiple subjects per voxel.
    data: shape (n_subjects, n_runs) - non-zero values only
    """
    data = np.array(data, dtype=np.float32)
    # Remove runs with all zeros
    if np.all(data == 0):
        return np.nan

    n, k = data.shape
    if n < 2:
        return np.nan  # need at least 2 subjects

    mean_per_subject = np.mean(data, axis=1)
    grand_mean = np.mean(data)

    ss_subject = k * np.sum((mean_per_subject - grand_mean) ** 2)
    ss_error = np.sum((data - mean_per_subject[:, None])**2)
    ms_subject = ss_subject / (n - 1)
    ms_error = ss_error / ((n - 1) * (k - 1))

    icc = (ms_subject - ms_error) / (ms_subject + (k - 1) * ms_error + 1e-8)
    return icc


# --- SETTINGS ---
subjects = ["sub-DMAim1HC004", "sub-DMAim1HC006", "sub-DMAim1HC007", "sub-DMAim1HC015", "sub-DMAim1HC018", "sub-DMAim1HC020", "sub-DMAim1HC030", "sub-DMAim1HC033", "sub-DMAim1HC001", "sub-DMAim1HC005", "sub-DMAim1HC016", "sub-DMAim1HC017", "sub-DMAim1HC022", "sub-DMAim1HC023", "sub-DMAim1HC027", "sub-DMAim1HC025", "sub-DMAim1HC035", "sub-DMAim1HC008", "sub-DMAim1HC031", "sub-DMAim1HC032", "sub-DMAim1HC034", "sub-DMAim1HC019", "sub-DMAim1HC037", "sub-DMAim1HC028", "sub-DMAim1HC038", "sub-DMAim1HC039", "sub-DMAim1HC009", "sub-DMAim1HC045", "sub-DMAim1HC002", "sub-DMAim1HC047", "sub-DMAim1HC029", "sub-DMAim1HC036", "sub-DMAim1HC046", "sub-DMAim1HC042", "sub-DMAim1HC003", "sub-DMAim1HC053", "sub-DMAim1HC052", "sub-DMAim1HC051", "sub-DMAim1HC054", "sub-DMAim1HC013"]
#subjects = ["sub-DMAim1HC004", "sub-DMAim1HC006", "sub-DMAim1HC007"]
runs = ["1", "2", "3"]
output_dir = "/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/icc/voxelwise"
path_in = "/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/"
copes = ['1', '2', '3', '4', '5']
os.makedirs(output_dir, exist_ok=True)
icc_maps = []


for cope in copes:
    print(f"\n📊 Computing voxelwise ICC for cope {cope}...")
    icc_maps = []
    data_list = []
    for sub in subjects:
        # Load all runs for this subject
        sub_maps = []
        for run in runs:
            zmap = os.path.join(path_in, sub, 'ses-spinalcord', 'func', f'run-{run}',f"{sub}_ses-spinalcord_task-tens_run-{run}_bold_mc2_pnm_stc2template_smooth225_trialwise_second_level.gfeat", "cope1.feat",  f'thresh_zstat{cope}.nii.gz')
            # Check if file exists
            if not os.path.exists(zmap):
                print(f"File not found: {zmap}")
            else:   
                img = nib.load(zmap)
                sub_maps.append(img.get_fdata())
        #data = np.stack(maps, axis=-1)  # shape: (X, Y, Z, 3)
        data_list.append(np.stack(sub_maps, axis=-1))
        #X, Y, Z, R = data.shape
        #icc_map = np.zeros((X, Y, Z))
        #icc_map[:] = np.nan
    # Stack subjects: shape = X, Y, Z, n_subjects, R
    data_all = np.stack(data_list, axis=-2)  # shape: X, Y, Z, n_subjects, runs
    X, Y, Z, n_subs, R = data_all.shape

    icc_map = np.full((X, Y, Z), np.nan, dtype=np.float32)
    for x in range(X):
        for y in range(Y):
            for z in range(Z):
                voxel_data = data_all[x, y, z, :, :]  # shape: subjects × runs
                # Remove zero runs per subject
                #voxel_data[voxel_data == 0] = np.nan
                # Remove subjects with all NaNs
                voxel_data = voxel_data[~np.all(np.isnan(voxel_data), axis=1)]
                if voxel_data.shape[0] < 2:
                    continue  # need at least 2 subjects
                icc_map[x, y, z] = icc_3_1_group(voxel_data)
    # Change NaNs to zeros for saving
    icc_map[np.isnan(icc_map)] = 0
    # --- Group-average ICC map ---
    # Save final ICC map
    icc_img = nib.Nifti1Image(icc_map, affine=img.affine)
    out_file = os.path.join(output_dir, f"group_cope{cope}_ICC_voxelwise.nii.gz")
    nib.save(icc_img, out_file)
    import matplotlib.pyplot as plt

    print("✅ Saved group-level voxelwise ICC map.")
    plt.hist(icc_map[np.isfinite(icc_map)], bins=1000, range=(-0.1, 0.5))
    plt.xlabel("ICC")
    plt.ylabel("Voxel count")
    plt.savefig(os.path.join(output_dir, f"group_cope{cope}_ICC_histogram.png"))
    plt.close()
