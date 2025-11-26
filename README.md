# Dermatomal_Mapping_R01

## Table of content
* [1.Dependencies](#1dependencies)
* [2.Installation](#2installation-of-python-requirements)

## 1.Dependencies

* SCT v6.0
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

## 3. Peak detection

~~~
sct_run_batch -script detect_peak_batch.sh -script-arg "Sandrine Bedard" -path-data /Volumes/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata -path-out /Users/sandrinebedard/processed_data/DM_peakdetection -jobs 1 -exclude ses-brain
~~~

## 4. Spinal cord preprocessing

~~~
sct_run_batch -script preprocess_spinal_cord.sh -path-data ~/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata/ -exclude ses-brain -include-list sub-DMAim1HC001 -path-out ~/dermatomal_mapping_proprocessing_2025-02-07
~~~

```
sct_run_batch -script preprocess_spinal_cord.sh -path-data ~/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata/ -exclude ses-brain -include-list sub-DMAim1HC004 sub-DMAim1HC006 sub-DMAim1HC007 sub-DMAim1HC015 sub-DMAim1HC018 sub-DMAim1HC020 sub-DMAim1HC030 sub-DMAim1HC033 sub-DMAim1HC005 sub-DMAim1HC016 sub-DMAim1HC017 sub-DMAim1HC022 
sub-DMAim1HC023 sub-DMAim1HC027 sub-DMAim1HC025 sub-DMAim1HC035 sub-DMAim1HC008 sub-DMAim1HC031 sub-DMAim1HC032 sub-DMAim1HC034 sub-DMAim1HC019 sub-DMAim1HC037 sub-DMAim1HC028 sub-DMAim1HC038 sub-DMAim1HC039 sub-DMAim1HC009 sub-DMAim1HC045 sub-DMAim1HC002 sub-DMAim1HC047 sub-DMAim1HC029 sub-DMAim1HC036 sub-DMAim1HC046 sub-DMAim1HC042 sub-DMAim1HC003 sub-DMAim1HC053 sub-DMAim1HC052 sub-DMAim1HC051 sub-DMAim1HC013 -jobs 1  -path-out ~/dermatomal_mapping_proprocessing_no-wm_2025-11-24/
```

### 4.1. First level on Sherlock

### 4.2. First level average across runs

## 5. Statistical Analysis

### ROI analysis

Create plots:
```
python analysis_plot_subject_level.py -metrics ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics.txt -path-out ~/Projects/Dermatomal_Mapping_R01/manuscripts/plots_run-average -metrics-roi ~/Projects/Dermatomal_Mapping_R01/manuscripts/results_n40_spinalcord_Sandrine/subject_metrics_rois.txt
```

### 5.1. Sample Size calculation

1. Create lists of subjects for monte carlo experiments
```
python create_lists.py -include ~/codes/Dermatomal_Mapping_R01/include_n40.yml -o ~/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/sample_size/
```
Copy lists to sherlock:

2. Copy data to sherlock
```
```

