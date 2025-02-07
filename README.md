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
sct_run_batch -script detect_peak_batch.sh -script-arg Sandrine Bedard -path-data /Volumes/Projects/Dermatomal_Mapping_R01/data/BIDS/sourcedata -path-out /Users/sandrinebedard/processed_data/DM_peakdetection -jobs 1 -exclude ses-brain21Ch
~~~
