
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
    parser.add_argument('-pain-file', type=str, required=True, help='Path to the pain metrics file')
    parser.add_argument('-include', type=str, required=True, help="Include list .yml file with subjects to include. If not provided, all subjects found will be included.")
    parser.add_argument('-path-out', type=str, required=True, help='Path to the output directory')
    return parser


def main():
    args = get_parser().parse_args()
    pain_path = args.pain_file
    path_out = args.path_out
    if not os.path.exists(path_out):
        os.makedirs(path_out)
    pain_data = pd.read_csv(pain_path)
    def format_record_id(record_id):
        try:
            num = int(record_id)
            if num < 10:
                return f"sub-DMAim1HC00{num}"
            elif num < 100:
                return f"sub-DMAim1HC0{num}"
            else:
                return f"sub-DMAim1HC{num}"
        except ValueError:
            return record_id

    if 'record_id' in pain_data.columns:
        pain_data['record_id'] = pain_data['record_id'].apply(format_record_id)
    pain_data = pain_data.dropna()
    pain_data = pain_data.drop(columns=['redcap_event_name'])
    print(pain_data.head())
    subjects = pain_data['record_id'].unique()

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
    print(include)
    if include:
        subjects = [sub for sub in subjects if sub in include]

    plt.figure(figsize=(4,3))
    width = 0.50
    # Use a qualitative colormap for distinct subject lines
    cmap = plt.cm.get_cmap('tab20', len(subjects))
    for idx, subject in enumerate(subjects):
        subject_data = pain_data[pain_data['record_id'] == subject]
        print(subject_data)
        x_labels = ["run-1", "run-2", "run-3"]
        pain_scores = [
            subject_data['imaging_aim1_sc_func_run_1_pain'].values[0],
            subject_data['imaging_aim1_sc_func_run_2_pain'].values[0],
            subject_data['imaging_aim1_sc_func_run_3_pain'].values[0]
        ]
        plt.plot(x_labels, pain_scores, width, marker="o", markersize=4, alpha=0.7, color=cmap(idx)) #, color=color)
    # Calculate mean and std for each run across subjects
    means = []
    sds = []
    x_labels = ["run-1", "run-2", "run-3"]
    for run in [1, 2, 3]:
        run_col = f'imaging_aim1_sc_func_run_{run}_pain'
        run_scores = []
        for subject in subjects:
            subject_data = pain_data[pain_data['record_id'] == subject]
            if not subject_data.empty:
                run_scores.append(subject_data[run_col].values[0])
        means.append(pd.Series(run_scores).mean())
        sds.append(pd.Series(run_scores).std())
    plt.errorbar(x_labels, means, yerr=sds, color=(0,0,0), marker=None, linewidth=2, elinewidth=2, capsize=4, markeredgewidth=2)
    # Add linear fit and p-value to the plot
    # Annotate means and std below each run
    for idx, (x, mean, sd) in enumerate(zip(x_labels, means, sds)):
        plt.text(
            idx, - 2.0,
            f"{mean:.2f}±{sd:.2f}",
            ha='center',
            va='top',
            fontsize=8,
            color='black'
        )

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

    plt.title(f'Pain Ratings across runs')
    plt.ylabel('Pain Rating')
    plt.ylim(-0.5, 10)
    plt.grid(False)
    plt.ticklabel_format(axis='y', style='sci', scilimits=(-3,3))
    plt.savefig(os.path.join(path_out, f'subject_pain_ratings.png'), dpi=300, bbox_inches='tight')
    plt.close()
    # Paired t-tests between all pairs of runs for pain ratings

    run_labels = ['run-1', 'run-2', 'run-3']
    run_cols = [
        'imaging_aim1_sc_func_run_1_pain',
        'imaging_aim1_sc_func_run_2_pain',
        'imaging_aim1_sc_func_run_3_pain'
    ]
    n_runs = len(run_labels)
    # Collect pain ratings for included subjects
    pain_matrix = []
    for subject in subjects:
        subject_data = pain_data[pain_data['record_id'] == subject]
        if not subject_data.empty:
            pain_matrix.append([
                subject_data[run_cols[0]].values[0],
                subject_data[run_cols[1]].values[0],
                subject_data[run_cols[2]].values[0]
            ])
    pain_matrix = np.array(pain_matrix)
    print('Mean pain ratings per run:', np.nanmean(pain_matrix, axis=0))
    print('SD pain ratings per run:', np.nanstd(pain_matrix, axis=0))
    # Paired t-tests
    for i in range(n_runs):
        for j in range(i + 1, n_runs):
            run_i = run_labels[i]
            run_j = run_labels[j]
            ratings_i = pain_matrix[:, i]
            ratings_j = pain_matrix[:, j]
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

            outname = f"pain_rating_{run_i}_vs_{run_j}_paired_ttest.txt"
            with open(os.path.join(path_out, outname), "w") as text_file:
                print(result, file=text_file)


if __name__ == "__main__":
    main()

