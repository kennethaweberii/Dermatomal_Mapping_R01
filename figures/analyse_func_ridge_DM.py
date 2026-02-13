#!/usr/bin/env python
# -*- coding: utf-8

import os
import argparse
import nibabel as nib
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.patches import Patch

def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i1",
                        required=True,
                        type=str,
                        help="First zstats file")
    parser.add_argument("-i2",
                        required=False,
                        type=str,
                        help="Second zstats file")
    parser.add_argument("-i3",
                        required=False,
                        type=str,
                        help="Third zstats file (optional)")
    parser.add_argument("-i4",
                        required=False,
                        type=str,
                        help="Fourth zstats file (optional)")
    parser.add_argument('-o', required=False, type=str,
                        help="Output filename")
    parser.add_argument('-t', required=False, type=str, choices=types.keys(),
                        help="Type of analysis")
    return parser



PALLETTE = {
    "run-1": "magenta",
    "run-2": "#FFD700",
    "run-3": "cyan",
    "Amp1": "#009933",
    "Amp2": "#8A2BE2",
    "Amp3": "#33FFFF",
    "Amp4": "#FF00FF",
    "Linear": "#FFCC00",
    "Discs": "#0000FF",
    "Rootlets": "red",
    'All': '#33FFFF',
    'Linear-NORDIC': '#0000FF',
}

types = {
    'runs': ['run-1', 'run-2', 'run-3'],
    'amps_all': ['Amp1', 'Amp2', 'Amp3', 'Amp4'],
    'amps_selected': ['Amp4', "Linear"],
    'reg': ['Discs', 'Rootlets'],
    'run1vsall': ['run-1', 'All'],
    'linear'    : ['Linear'],
    'nordic' : ['Linear', 'Linear-NORDIC'],
    'run-1': ['Amp3', 'Amp4', 'Linear']

}

def load_voxel_values_by_z(file_path):
    """Load voxel values and group them by Z-axis slices."""
    img = nib.load(file_path)
    data = img.get_fdata()
    threshold = 1.6
    data = np.where(data >= threshold, data, 0)
    if len(data.shape) != 3:
        raise ValueError("Expected a 3D fMRI activation map (x, y, z). Got shape: {}".format(data.shape))

    z_slices = data.shape[2]  # Number of Z slices
    voxel_dict = {}

    for z in range(z_slices):
        slice_data = data[:, :, z].flatten()
        slice_data = slice_data[~np.isnan(slice_data)]  # Remove NaNs
        slice_data = slice_data[slice_data != 0]  # Remove zero values
        voxel_dict[z] = slice_data

    return voxel_dict


def create_ridge_plot(nii_file1, nii_file2, nii_file3, nii_file4, output_file, type):
    """Generate and save a ridge plot with Z-axis as the Y-axis for up to four input files."""
    sns.set(style="white", context="talk")
    labels = types.get(type, [])
    print(f"Selected labels for type '{type}': {labels}")
    voxel_dict1 = load_voxel_values_by_z(nii_file1)

    data1 = [(z, v, labels[0]) for z, voxels in voxel_dict1.items() for v in voxels]
    data = data1

    if nii_file2:
        voxel_dict2 = load_voxel_values_by_z(nii_file2)
        data2 = [(z, v, labels[1]) for z, voxels in voxel_dict2.items() for v in voxels]
        data += data2

    if nii_file3:
        voxel_dict3 = load_voxel_values_by_z(nii_file3)
        data3 = [(z, v, labels[2]) for z, voxels in voxel_dict3.items() for v in voxels]
        data += data3

    if nii_file4:
        voxel_dict4 = load_voxel_values_by_z(nii_file4)
        data4 = [(z, v, labels[3]) for z, voxels in voxel_dict4.items() for v in voxels]
        data += data4

    df = pd.DataFrame(data, columns=["Z-Slice", "Voxel Intensity", "File"])
    # Plot ridge density along the Z-axis for all provided files
    plt.figure(figsize=(3.5, 11))  # Adjust figure size for better fit
    #sns.kdeplot(data=df[df["File"] == "run-1"], y="Z-Slice", weights="Voxel Intensity", fill=True, alpha=0.7, bw_adjust=0.5, color='magenta', label="run-1", common_norm=True, common_grid=True)  # Cyan color="magenta"
    #sns.kdeplot(data=df[df["File"] == "run-2"], y="Z-Slice", weights="Voxel Intensity", fill=True, alpha=0.7, bw_adjust=0.5, color='#FFD700', label="run-2", common_norm=True, common_grid=True)  # Magenta "#FFD700"
    label = np.unique(df["File"])
    print(label)
    sns.kdeplot(
        data=df,
        y="Z-Slice",
        hue="File",
        weights="Voxel Intensity",
        fill=True,
        hue_order=label,#[::-1],
        alpha=0.7,
        bw_adjust=0.5,
        common_norm=True,
        multiple="layer", # or layer stack
        palette={k: PALLETTE[k] for k in label if k in PALLETTE},  # Use only present labels and their colors
        legend=True
    )

    # Ensure legend labels match the colors in the palette
    handles, _ = plt.gca().get_legend_handles_labels()
    legend_labels = [l for l in label if l in PALLETTE]
    legend_colors = [PALLETTE[l] for l in legend_labels]
    custom_handles = [Patch(facecolor=c, edgecolor=c, label=l) for l, c in zip(legend_labels, legend_colors)]
    plt.legend(handles=custom_handles, labels=legend_labels, loc="upper center", bbox_to_anchor=(0.5, 1.2))
    #if nii_file3:
    #    sns.kdeplot(data=df[df["File"] == "run-3"], y="Z-Slice", weights="Voxel Intensity", fill=True, alpha=0.7, bw_adjust=0.5, color="cyan", label="run-3", common_norm=True)  # Darker Yellow
    #if nii_file4:
    #    sns.kdeplot(data=df[df["File"] == "Amp1"], y="Z-Slice", weights="Voxel Intensity", fill=True, alpha=0.6, bw_adjust=0.5, color="green", label="Amp1", common_norm=True, common_grid=True)  # Lighter Green
   
    # Formatting
    plt.ylabel("")
    #plt.legend([],[], frameon=False)
    plt.xlabel("Active Voxel Density")
    plt.gca().xaxis.set_tick_params(which='both', direction='in', length=6, width=1, color='black')  # Add tick lines with customization
    plt.ylim(45, 165) #plt.ylim(31, 257) OLD
    plt.gca().yaxis.set_ticks([])  # Remove y-axis ticks
    plt.gca().xaxis.set_tick_params(which='both', direction='in', length=6, width=1, color='black')  # Add tick lines for x-axis
    sns.despine(left=True, bottom=False, top=False)  # Remove the box around the plot
    plt.xticks(fontsize=22)  # Adjust x-axis label font size
    plt.tight_layout()  # Ensure everything fits within the figure

    # Save the figure
    plt.savefig(output_file, dpi=300)
    print(f"Ridge plot saved as: {output_file}")


def main():
    args = get_parser().parse_args()
    print(f"Input file 1: {args.i1}")
    if args.i2:
        print(f"Input file 2: {args.i2}")
    else:
        print("Input file 2: Not provided")
    if args.i3:
        print(f"Input file 3: {args.i3}")
    else:
        print("Input file 3: Not provided")
    if args.i4:
        print(f"Input file 4: {args.i4}")
    else:
        print("Input file 4: Not provided")
    create_ridge_plot(args.i1, args.i2, args.i3, args.i4, os.path.join(args.o, 'ridge_plot_' + args.t + '.png'), args.t)


if __name__ == "__main__":
    main()
