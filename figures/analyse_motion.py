
import argparse
import os
import sys
import yaml
import pandas as pd
from scipy.stats import linregress
import numpy as np
from scipy.stats import ttest_rel
from scipy.stats import shapiro, wilcoxon
import matplotlib.pyplot as plt


def get_parser():
    parser = argparse.ArgumentParser(description='Create subject level plots for analysis.')
    parser.add_argument('-file', type=str, required=True, help='Path to the motion ouliers metrics file')
    parser.add_argument('-include', type=str, required=True, help="Include list .yml file with subjects to include. If not provided, all subjects found will be included.")
    parser.add_argument('-path-out', type=str, required=True, help='Path to the output directory')
    return parser


def main():
    args = get_parser().parse_args()
    path = args.file
    path_out = args.path_out
    if not os.path.exists(path_out):
        os.makedirs(path_out)
    data = pd.read_csv(path, delimiter=" ")
    subjects = data['subject'].unique().tolist()
    data = data.dropna()

    if args.include is not None:
        # Check if input yml file exists
        if os.path.isfile(args.include):
            fname_yml = args.include
        else:
            sys.exit("ERROR: Input yml file {} does not exist or path is wrong.".format(args.include))
        with open(fname_yml, 'r') as stream:
            try:
                include = list(yaml.safe_load(stream))
            except yaml.YAMLError as exc:
                print(exc)
    else:
        include = []
    if include:
        subjects = [sub for sub in subjects if sub in include]

    plt.figure(figsize=(4,3))
    width = 0.50
    # Use a qualitative colormap for distinct subject lines
    cmap = plt.cm.get_cmap('tab20', len(subjects))
    for idx, subject in enumerate(subjects):
        subject_data = data[data['subject'] == subject]
        x_labels = ["run-1", "run-2", "run-3"]
        plt.plot(subject_data["run"], subject_data["motion_outliers"], marker="o", markersize=4, alpha=0.7, color=cmap(idx)) #, color=color)
    # Calculate mean and std for each run across subjects
    means = data.groupby('run')['motion_outliers'].mean().values
    sds = data.groupby('run')['motion_outliers'].std().values
    plt.errorbar(x_labels, means, yerr=sds, color=(0,0,0), marker=None, linewidth=2, elinewidth=2, capsize=4, markeredgewidth=2)
    # Annotate means and std below each run
    for idx, (x, mean, sd) in enumerate(zip(x_labels, means, sds)):
        plt.text(
            idx, - 5,
            f"{mean:.2f}±{sd:.2f}",
            ha='center',
            va='top',
            fontsize=8,
            color='black'
        )   
    # Add linear fit and p-value to the plot


    x_all = np.array([1, 2, 3])
    y_all = np.array(means)
    slope, intercept, r_value, p_value, std_err = linregress(x_all, y_all)
    #fit_line = slope * x_all + intercept
    plt.text(
        0.6, 0.95,
        f'Linear fit: p={p_value:.3g}',
        transform=plt.gca().transAxes,
        fontsize=8,
        verticalalignment='top',
        color='black'
    )

    plt.title(f'Number of motion outliers across runs')
    plt.ylabel('Motion Outliers')
    plt.ylim(-0.5,45)
    plt.grid(False)
    plt.ticklabel_format(axis='y', style='sci', scilimits=(-3,3))
    plt.savefig(os.path.join(path_out, f'subject_motion_outliers.png'), dpi=300, bbox_inches='tight')
    plt.close()
    # Paired t-tests between all pairs of runs for motion outliers

    run_labels = ['run-1', 'run-2', 'run-3']

    n_runs = len(run_labels)
    # Collect motion outliers for included subjects
    motion_matrix = []
    for subject in subjects:
        subject_data = data[data['subject'] == subject]
        if not subject_data.empty:
            motion_matrix.append([
                subject_data.loc[subject_data['run'] == 'run-1', "motion_outliers"].values[0],
                subject_data.loc[subject_data['run'] == 'run-2', "motion_outliers"].values[0],
                subject_data.loc[subject_data['run'] == 'run-3', "motion_outliers"].values[0]
            ])
    motion_matrix = np.array(motion_matrix)
    print('Mean motion outliers per run:', np.nanmean(motion_matrix, axis=0))
    print('SD motion outliers per run:', np.nanstd(motion_matrix, axis=0))
    # Paired t-tests
    for i in range(n_runs):
        for j in range(i + 1, n_runs):
            run_i = run_labels[i]
            run_j = run_labels[j]
            ratings_i = motion_matrix[:, i]
            ratings_j = motion_matrix[:, j]
            # Remove pairs with NaN
            mask = ~np.isnan(ratings_i) & ~np.isnan(ratings_j)
            # Check normality for the differences
            diffs = ratings_i[mask] - ratings_j[mask]
            if len(diffs) > 2:
                stat_norm, p_norm = shapiro(diffs)
            else:
                stat_norm, p_norm = None, 1  # Not enough data to test normality

            if p_norm is not None and p_norm > 0.05:
                # Normal distribution, use paired t-test
                stat, pval = ttest_rel(ratings_i[mask], ratings_j[mask])
                test_used = "Paired t-test"
            else:
                # Not normal, use Wilcoxon signed-rank test
                stat, pval = wilcoxon(ratings_i[mask], ratings_j[mask])
                test_used = "Wilcoxon signed-rank test"
            result = f"{test_used} {run_i} vs {run_j}: stat={stat:.4f}, p={pval:.4g}, n={np.sum(mask)}" if pval is not None else f"No paired data for {run_i} vs {run_j}"

            outname = f"motion_ouliers_{run_i}_vs_{run_j}_paired_ttest.txt"
            with open(os.path.join(path_out, outname), "w") as text_file:
                print(result, file=text_file)


if __name__ == "__main__":
    main()

