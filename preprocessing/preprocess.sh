#!/bin/sh
# 
#
path_script=~/codes/Dermatomal_Mapping_R01/preprocessing
PATH_DATA=${SCRATCH}/dmr01/derivatives/nordic_param_fe1.5/DM_R01/
PATH_SEGMANUAL=${SCRATCH}/dmr01/derivatives/labels
output_path=${SCRATCH}/dmr01/nordic_param_fe1.5_preprocessing_2026-02-26
subjects=(sub-DMAim1HC004 sub-DMAim1HC006 sub-DMAim1HC007 sub-DMAim1HC015 sub-DMAim1HC018 sub-DMAim1HC020 sub-DMAim1HC030 sub-DMAim1HC033 sub-DMAim1HC001 sub-DMAim1HC005 sub-DMAim1HC016 sub-DMAim1HC017 sub-DMAim1HC022 sub-DMAim1HC023 sub-DMAim1HC027 sub-DMAim1HC025 sub-DMAim1HC035 sub-DMAim1HC008 sub-DMAim1HC031 sub-DMAim1HC032 sub-DMAim1HC034 sub-DMAim1HC019 sub-DMAim1HC037 sub-DMAim1HC028 sub-DMAim1HC038 sub-DMAim1HC039 sub-DMAim1HC009 sub-DMAim1HC045 sub-DMAim1HC002 sub-DMAim1HC047 sub-DMAim1HC029 sub-DMAim1HC036 sub-DMAim1HC046 sub-DMAim1HC042 sub-DMAim1HC003 sub-DMAim1HC053 sub-DMAim1HC052 sub-DMAim1HC051 sub-DMAim1HC054 sub-DMAim1HC013)
#subjects=(sub-DMAim1HC004) 
ses=ses-spinalcord
time_limit=35:00:00
memory=128000

mkdir -p ${output_path}
PATH_DATA_PROCESSED="${output_path}/data_processed"
PATH_RESULTS="${output_path}/results"
PATH_LOG="${output_path}/log"
PATH_QC="${output_path}/qc"
mkdir -p ${PATH_DATA_PROCESSED}
mkdir -p ${PATH_RESULTS}
mkdir -p ${PATH_LOG}
mkdir -p ${PATH_QC}

for subject in "${subjects[@]}"; do
    echo "Preprocessing data for subject: $subject"
    export subject path_script PATH_DATA SCRATCH output_path time_limit memory PATH_DATA PATH_DATA_PROCESSED PATH_RESULTS PATH_LOG PATH_QC ses PATH_SEGMANUAL
    envsubst '${subject} ${path_script} ${PATH_DATA} ${SCRATCH} ${output_path} ${time_limit} ${memory} ${PATH_DATA} ${PATH_DATA_PROCESSED} ${PATH_RESULTS} ${PATH_LOG} ${PATH_QC} ${ses}' < ${path_script}/preprocess.sbatch > preprocess_${subject}.sbatch
    sbatch preprocess_${subject}.sbatch
    rm preprocess_${subject}.sbatch
    sleep 10s
done
