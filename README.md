# Spatial distribution of spinal cord fMRI activity with electrocutaneous stimulation

This repository contains the code and resources for a spinal cord fMRI study mapping segment-level sensory-evoked activity during electrocutaneous stimulation and evaluating how anatomical alignment, stimulus intensity, and repeated stimulation affect localization, magnitude, and reliability of responses.

## Table of content
* [1.Dependencies](#1dependencies)
* [2.Installation](#2installation-of-python-requirements)
* [3.Cardiac Peak detection](#3cardiac-peak-detection)
* [4.Spinal cord preprocessing](#4spinal-cord-preprocessing)
* [5.Statistical Analysis](#5statistical-analysis)

## 1.Dependencies

* SCT v6.0 --> version: git-master-d1c1cb248bfd153d9da454c21e49b72ec76152e8
* FSL 6.0
* Python 3.9

## 2.Installation of python requirements

* Create python environment
~~~
conda create --name Dermatomal_Mapping_R01 python==3.9
~~~

* Activate environment
~~~
conda activate Dermatomal_Mapping_R01
~~~

* Install requirements
~~~
pip install -r requirements.txt
~~~

## 3.Cardiac peak detection

~~~
sct_run_batch -script detect_peak_batch.sh -script-arg "Sandrine Bedard" -path-data /Volumes/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata -path-out /Users/sandrinebedard/processed_data/DM_peakdetection -jobs 1 -exclude ses-brain
~~~

## 4.Spinal cord preprocessing

~~~
sct_run_batch -script preprocess_spinal_cord.sh -path-data ~/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata/ -exclude ses-brain -include-list sub-DMAim1HC001 -path-out ~/dermatomal_mapping_proprocessing_2025-02-07
~~~

```
cd preprocessing
sct_run_batch -script preprocess_spinal_cord.sh -path-data ~/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata/ -exclude ses-brain -include-list sub-DMAim1HC004 sub-DMAim1HC006 sub-DMAim1HC007 sub-DMAim1HC015 sub-DMAim1HC018 sub-DMAim1HC020 sub-DMAim1HC030 sub-DMAim1HC033 sub-DMAim1HC005 sub-DMAim1HC016 sub-DMAim1HC017 sub-DMAim1HC022 
sub-DMAim1HC023 sub-DMAim1HC027 sub-DMAim1HC025 sub-DMAim1HC035 sub-DMAim1HC008 sub-DMAim1HC031 sub-DMAim1HC032 sub-DMAim1HC034 sub-DMAim1HC019 sub-DMAim1HC037 sub-DMAim1HC028 sub-DMAim1HC038 sub-DMAim1HC039 sub-DMAim1HC009 sub-DMAim1HC045 sub-DMAim1HC002 sub-DMAim1HC047 sub-DMAim1HC029 sub-DMAim1HC036 sub-DMAim1HC046 sub-DMAim1HC042 sub-DMAim1HC003 sub-DMAim1HC053 sub-DMAim1HC052 sub-DMAim1HC051 sub-DMAim1HC013 -jobs 1  -path-out ~/dermatomal_mapping_proprocessing_no-wm_2025-11-24/
```

## 5.Statistical Analysis

### 5.1.ROI analysis
Go into the figures folder:

~~~
cd ../figures
~~~

#### Create ROIS:
~~~
python create_roi.py -label ${SCT_DIR}/data/PAM50/ -mask ~/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/masks/mask_cord_N40.nii.gz -levels 6 7 8 -thr 0.5 -o-folder ~/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/masks/rois_n40/ 
~~~

#### Extract metrics within ROIS
~~~
bash extract_group_metrics_rois.sh

# Extract for each run:
bash extract_group_metrics_rois_perRun.sh

# Extract for withi run (per trial):
bash extract_group_metrics_rois_withinRun.sh
~~~

#### Create plots:
```
python analysis_plot_subject_level.py -metrics ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics.txt -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/plots_run-average -metrics-roi ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois.txt

# Per run:
python analysis_plot_subject_level_perRun.py -metrics-zscore ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois_perRun.txt -metrics-voxels ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois_perRun_voxels.txt -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/plots_across_runs_2026-01-16

# Per trial:
python analysis_plot_subject_level.py -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/plots_test_2025-10-01 -metrics-zscore subject_metrics_rois_withinRun1.txt-metrics-voxels ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois_withinRun1_voxels.txt -cope 4
```

### 5.2.Motion ouliers

~~~
bash get_motion_outliers.sh
python analyse_motino.py -file motion_outlier_columns_summary.txt -inlcude ~/Dermatomal_Mapping_R01/inlcude_n40.yml -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/motion_oulier_plot/
~~~

### 5.3.Pain ratings
~~~
python analyse_pain_ratings.py -pain-file ~/Projects/Dermatomal_Mapping_R01/manuscripts/pain_ratings/DermatomalMappingDMR-PainRatings_DATA_2025-10-01_1259.csv -include ~/codes/Dermatomal_Mapping_R01/include_n40.yml -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/pain_ratings/
~~~

### 5.4.TSNR
~~~
create_group_level_tsnr_plot.sh
~~~

### 5.5.Create activation images:

~~~
bash create_activation_images.sh
bash create_activation_images_per_run.sh
~~~

### 5.6.Intra-class correlation (ICC)

~~~
../icc
python extract_icc_runs.py 
~~~

### 5.7.Sample Size calculation

1. Create lists of subjects for monte carlo experiments
```
../sample_size
python create_lists.py -include ~/codes/Dermatomal_Mapping_R01/include_n40.yml -o ~/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/sample_size/
# Make sure to copy to sherlock in the same location
```
Copy lists to sherlock:

2. Copy data to sherlock
```
# Connect to sherlock and run: 
bash cp_data_2_shelock.sh
```

3. Run the analysis:
~~~
# This will loop across samples sizes and run the group level analysis with
bash feat_group_analysis_sample_size_sherlock.sh
~~~

4. Create figure
~~~
bash create_activation_images_sample_size
~~~

