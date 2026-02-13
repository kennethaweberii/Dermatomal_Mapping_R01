#!/bin/sh
# 
#

#Initialization of parameters
data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/group_level_spinal_cord/
#data_path=/home/sbedard/dermatomal_mapping_proprocessing_2025-09-10_disc_reg_ALL/results/
mask_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/masks
#/Volumes/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/group_level_spinal_cord/GroupLevel_trialwise_amp_4_N40_randomize_corr1.6.gfeat/cope1.feat
discs=""
type=randomize_corr2.3
task=tens
copes=(amp_1 amp_2 amp_3 amp_4 linear)
rois=(left_sc_gm_mask right_sc_gm_mask left_sc_mask right_sc_mask C6_left_sc_gm_mask C6_right_sc_gm_mask C7_left_sc_gm_mask C7_right_sc_gm_mask C8_left_sc_gm_mask C8_right_sc_gm_mask) # left_sc_vh_mask right_sc_vh_mask left_sc_vq_mask right_sc_vq_mask)

rm -f group_metrics_${type}_${discs}.txt
echo task cope roi zscore_sc voxels_sc lr_sc >> group_metrics_${type}_${discs}.txt

#GroupLevel_trialwise_amp_4_N40_randomize_corr1.6.gfeat

for cope in ${copes[@]}; do
    session=""
    roi=spinal_cord
    echo ${task} ${cope} ${roi} ${subject}
    echo ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz
    zscore_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/mask_cord_N40.nii.gz -M`
    voxels_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/mask_cord_N40.nii.gz -V | cut -d " " -f1`
    left_voxels_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/rois_n40/left_sc_mask.nii.gz -V | cut -d " " -f1`
    right_voxels_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/rois_n40/right_sc_mask.nii.gz -V | cut -d " " -f1`

    if [ "${left_voxels_sc}" -gt 0 ] || [ "${right_voxels_sc}" -gt 0 ]; then
            lr_sc=`echo "scale=3; (${left_voxels_sc} - ${right_voxels_sc}) / (${left_voxels_sc} + ${right_voxels_sc})" | bc -l`
    else
            lr_sc=0
    fi

    echo ${task} ${cope} ${roi} ${zscore_sc} ${voxels_sc} ${lr_sc} >> group_metrics_${type}_${discs}.txt
    for roi in ${rois[@]}; do
        voxels_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/rois_n40/${roi}.nii.gz -V | cut -d " " -f1`
        zscore_sc=`fslstats ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz -k ${mask_path}/rois_n40/${roi}.nii.gz -M`
        lr_sc=""
       # ${mask_path}/rois_n40/${roi}.nii.gz
        echo ${task} ${cope} ${roi} ${zscore_sc} ${voxels_sc} ${lr_sc} >> group_metrics_${type}_${discs}.txt

    done

done
