#!/bin/sh
# 
#
path_in=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives
path_out=${SCRATCH}/dermatomal_mapping_R01/derivatives
path_script=~/codes/Dermatomal_Mapping_R01


#Read include list yaml file
# TODO: check is installed
subjects=($(< "${path_script}/include_n40.txt"))

for subject in "${subjects[@]}"; do
    echo "Copying data for subject: $subject"
    mkdir -p ${path_out}/${subject}/ses-spinalcord/func/
    cd ${path_out}/${subject}/ses-spinalcord/func/
    file_path="${path_in}/${subject}/ses-spinalcord/func/${subject}_ses-spinalcord_task-tens_run-average_bold_mc2_pnm_stc2template_smooth225_trialwise_second_level.gfeat"
    #Copy functional
    ret=1
    c=0
    until [ ${ret} = 0 ] || [ ${c} = 5 ]; do
        scp sbedard@anes-nil1000.stanford.edu:${file_path}/ .
        ret=$?
        ((c++))
    done
done