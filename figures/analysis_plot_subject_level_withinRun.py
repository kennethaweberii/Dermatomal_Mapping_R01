import os
import pandas as pd
import numpy as np
import argparse
from scipy.stats import ttest_rel
from scipy.stats import linregress

import matplotlib.pyplot as plt
# Example command:
#python analysis_plot_subject_level.py -metrics subject_metrics.txt -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/plots_test_2025-10-01 -metrics-roi ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois.txt

def get_parser():
    parser = argparse.ArgumentParser(description='Create subject level plots for analysis.')
   # parser.add_argument('-metrics', type=str, required=True, help='Path to the metrics file')
    parser.add_argument('-metrics-zscore', type=str, required=True, help='Path to the metrics file')
    parser.add_argument('-metrics-voxels', type=str, required=True, help='Path to the metrics file')
    parser.add_argument('-cope', type=str, required=True, help='Name of cope to analyze (e.g., cope1, cope2, cope3, cope4)')
    parser.add_argument('-path-out', type=str, required=True, help='Path to the output directory')
    return parser

def main():
    args = get_parser().parse_args()
    #metrics_path = args.metrics
    path_out = args.path_out
    if not os.path.exists(path_out):
        os.makedirs(path_out)
    metrics_roi_path = args.metrics_zscore
    metrics_voxels_path = args.metrics_voxels
    # Load the metrics dataset
    #dataset = pd.read_csv(metrics_path, delimiter=" ")
    dataset_zscore = pd.read_csv(metrics_roi_path, delimiter=" ")
    dataset_voxels = pd.read_csv(metrics_voxels_path, delimiter=" ")

    regions_rois = ['left_sc_gm_mask', 'right_sc_gm_mask', "left_sc_mask", 'right_sc_mask',
                    'C6_left_sc_gm_mask', 'C6_right_sc_gm_mask', 'C7_left_sc_gm_mask', 'C7_right_sc_gm_mask',
                    'C8_left_sc_gm_mask', 'C8_right_sc_gm_mask']


    # Create subject level plots for each ROI region for 4 amps
    measures = ['zscore_sc', 'voxels_sc']
    cope = args.cope
    trials = dataset_zscore['trial'].unique()
    xlabel = np.arange(0, len(trials))
    for region in regions_rois:
        for measure in measures:
            if measure == 'zscore_sc':
                dataset_roi = dataset_zscore
            elif measure == 'voxels_sc':
                dataset_roi = dataset_voxels
            fig, ax = plt.subplots(figsize=(5,3))
            width = 0.50
            color = (255/255, 208/255, 0/255)  # yellow

            # Set y-label and limits based on measure
            ylabel = 'Z Score' if measure == 'zscore_sc' else 'Voxels'
            if measure == 'zscore_sc':
                ylim = [1.5, 4.5]
                ytickmarks = [1.5, 2.5, 3.5, 4.5]
            elif measure == 'voxels_sc':
                if region in ['left_sc_gm_mask', 'right_sc_gm_mask', "left_sc_mask", 'right_sc_mask']:
                    ylim = [0, 1500]
                    ytickmarks = [0, 200, 400, 800, 1200, 1400]
                else:
                    ylim = [0, 650]
                    ytickmarks = [0, 100, 200, 300, 400, 500, 600]
            for subject in dataset_roi.subject.unique():
                data = dataset_roi[
                    (dataset_roi['subject'] == subject) &
                    (dataset_roi['region'] == region)
                ]
                print(data)
                # Ensure ydata is aligned with ['run-1', 'run-2', 'run-3']
                ydata = []
                for trial in trials:
                    val = data[data['trial'] == trial][measure]
                    if not val.empty:
                        ydata.append(val.values[0])
                    else:
                        ydata.append(np.nan)
                plt.plot(xlabel, ydata, color=color, marker=None, linewidth=2)

            # Means and SDs for each amp
            means = []
            sds = []
            for trial in trials:
                vals = dataset_roi[(dataset_roi['trial'] == trial) & (dataset_roi['region'] == region)][measure]
                means.append(vals.mean())
                sds.append(vals.std())
            plt.errorbar(xlabel, means, yerr=sds, color=(0,0,0), marker=None, linewidth=3, elinewidth=3, capsize=5, markeredgewidth=3)

            # Linear regression

            x_all = dataset_roi[(dataset_roi['region'] == region)]['trial'].values
            y_all = dataset_roi[(dataset_roi['region'] == region)][measure].values
            slope, intercept, r_value, p_value, std_err = linregress(x_all, y_all)
            fit_line = slope * np.arange(1, 4) + intercept

            # ax.text(
            #     0.05, 0.1,
            #     f'Linear fit: p={p_value:.3g}',
            #     transform=ax.transAxes,
            #     fontsize=10,
            #     verticalalignment='top',
            #     color='black'
            # )
            if ylim is not None:
                ax.set_ylim(ylim)
            if ytickmarks is not None:
                ax.set_yticks(ytickmarks)
            ax.set_ylabel(ylabel, fontsize=16, color=(0,0,0))
            ax.tick_params(labelsize=12, width=1.5, colors=(0,0,0))
            for axis in ['top','bottom','left','right']:
                ax.spines[axis].set_linewidth(1.5)
                ax.spines[axis].set_color((0,0,0))
            for axis in ['top','right']:
                ax.spines[axis].set_linewidth(0)
            plt.ticklabel_format(axis='y', style='sci', scilimits=(-3,3))
            ax.tick_params(bottom=False)
            plt.subplots_adjust(wspace=0.5)
            plt.show()
            fig.savefig(os.path.join(path_out, f"{measure}_{region}_{cope}_subject.png"), dpi=600, bbox_inches='tight', pad_inches=0, transparent=True)
            plt.close()

            # Paired t-tests between all pairs of copes for this ROI
            # trial_labels = trials.astype(str)
            # n_trials = len(trial_labels)
            # for i in range(n_trials):
            #     for j in range(i + 1, n_trials):
            #         trial_i = trial_labels[i]
            #         trial_j = trial_labels[j]
            #         merged = pd.merge(
            #             dataset_roi[(dataset_roi['trial'] == trial_i) & (dataset_roi['region'] == region)& (dataset_roi['cope']== cope)][['subject', measure]],
            #             dataset_roi[(dataset_roi['trial'] == trial_j) & (dataset_roi['region'] == region)& (dataset_roi['cope']== cope)][['subject', measure]],
            #             on='subject',
            #             suffixes=('_' + trial_i, '_' + trial_j)
            #         )
            #         if not merged.empty:
            #             stat, pval = ttest_rel(merged[measure + '_' + trial_i], merged[measure + '_' + trial_j])
            #             result = f"Paired t-test {trial_i} vs {trial_j}: t={stat:.4f}, p={pval:.4g}, n={len(merged)}"
            #         else:
            #             result = f"No paired data for {trial_i} vs {trial_j}"
            #         outname = f"{measure}_{region}_subject_{trial_i}_{trial_j}.txt"
            #         with open(os.path.join(path_out, outname), "w") as text_file:
            #             print(result, file=text_file)

if __name__ == "__main__":
    main()
