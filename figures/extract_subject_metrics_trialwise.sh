#!/bin/sh
# 
#

#Initialization of parameters
data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/group_level_spinal_cord/

tasks=(tens)
copes=(cope1 cope2 cope3)

subjects=(sub-DMAim1HC004 sub-DMAim1HC006 sub-DMAim1HC007 sub-DMAim1HC015 sub-DMAim1HC018 sub-DMAim1HC020 sub-DMAim1HC030 sub-DMAim1HC033 sub-DMAim1HC001 sub-DMAim1HC005 sub-DMAim1HC016 sub-DMAim1HC017 sub-DMAim1HC022 sub-DMAim1HC023 sub-DMAim1HC027 sub-DMAim1HC025 sub-DMAim1HC035 sub-DMAim1HC008 sub-DMAim1HC031 sub-DMAim1HC032 sub-DMAim1HC034 sub-DMAim1HC019 sub-DMAim1HC037 sub-DMAim1HC028 sub-DMAim1HC038 sub-DMAim1HC039 sub-DMAim1HC009 sub-DMAim1HC040 sub-DMAim1HC045 sub-DMAim1HC002 sub-DMAim1HC047 sub-DMAim1HC029 sub-DMAim1HC036 sub-DMAim1HC046 sub-DMAim1HC042 sub-DMAim1HC003 sub-DMAim1HC053 sub-DMAim1HC052 sub-DMAim1HC051 sub-DMAim1HC054 sub-DMAim1HC013)

rm -f subject_metrics_trialwise.txt
echo task cope subject trial zstat zscore_sc voxels_sc lr_sc zscore_brain voxels_brain lr_brain zscore_cerebrum voxels_cerebrum lr_cerebrum zscore_cerebellum voxels_cerebellum lr_cerebellum >> subject_metrics_trialwise.txt

for task in ${tasks[@]}; do
	for cope in ${copes[@]}; do
        for subject in ${subjects[@]}; do
            for trial in `seq 1 10`; do
                session=01
                if [ ${cope} == cope1 ]; then
                    zstat=`echo "scale=0; (${trial} + 0)" | bc -l`
                elif [ ${cope} == cope2 ]; then
                    zstat=`echo "scale=0; (${trial} + 10)" | bc -l`
                elif [ ${cope} == cope3 ]; then
                    zstat=`echo "scale=0; (${trial} + 20)" | bc -l`
                else
                    echo ERROR
                fi

                echo ${task} ${cope} ${subject} ${zstat}

                zscore_sc=`fslstats ${data_path}/${subject}_spinalcord_${task}/${subject}_ses-${session}spinalcord_task-${task}_bold_mc2_pnm2template_smooth_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/template_cropped_cord_combined_N28_mask.nii.gz -M`
                voxels_sc=`fslstats ${data_path}/${subject}_spinalcord_${task}/${subject}_ses-${session}spinalcord_task-${task}_bold_mc2_pnm2template_smooth_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/template_cropped_cord_combined_N28_mask.nii.gz -V | cut -d " " -f1`
                left_voxels_sc=`fslstats ${data_path}/${subject}_spinalcord_${task}/${subject}_ses-${session}spinalcord_task-${task}_bold_mc2_pnm2template_smooth_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/left_cord_combined_N28_mask.nii.gz -V | cut -d " " -f1`
                right_voxels_sc=`fslstats ${data_path}/${subject}_spinalcord_${task}/${subject}_ses-${session}spinalcord_task-${task}_bold_mc2_pnm2template_smooth_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/right_cord_combined_N28_mask.nii.gz -V | cut -d " " -f1`
                
                if [ "${left_voxels_sc}" -gt 0 ] || [ "${right_voxels_sc}" -gt 0 ]; then
                    lr_sc=`echo "scale=3; (${left_voxels_sc} - ${right_voxels_sc}) / (${left_voxels_sc} + ${right_voxels_sc})" | bc -l`
                else
                    lr_sc=0
                fi

                zscore_brain=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -M`
                voxels_brain=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -V | cut -d " " -f1`
                left_voxels_brain=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_brain_left_mask.nii.gz -V | cut -d " " -f1`
                right_voxels_brain=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k  ${data_path}/masks/MNI152_T1_2mm_brain_right_mask.nii.gz -V | cut -d " " -f1`
                
                if [ "${left_voxels_brain}" -gt 0 ] || [ "${right_voxels_brain}" -gt 0 ]; then
                    lr_brain=`echo "scale=3; (${left_voxels_brain} - ${right_voxels_brain}) / (${left_voxels_brain} + ${right_voxels_brain})" | bc -l`
                else
                    lr_brain=0
                fi

                zscore_cerebrum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebrum.nii.gz -M`
                voxels_cerebrum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebrum.nii.gz -V | cut -d " " -f1`
                left_voxels_cerebrum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebrum_left.nii.gz -V | cut -d " " -f1`
                right_voxels_cerebrum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k  ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebrum_right.nii.gz -V | cut -d " " -f1`
                
                if [ "${left_voxels_cerebrum}" -gt 0 ] || [ "${right_voxels_cerebrum}" -gt 0 ]; then
                    lr_cerebrum=`echo "scale=3; (${left_voxels_cerebrum} - ${right_voxels_cerebrum}) / (${left_voxels_cerebrum} + ${right_voxels_cerebrum})" | bc -l`
                else
                    lr_cerebrum=0
                fi

                zscore_cerebellum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebellum.nii.gz -M`
                voxels_cerebellum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebellum.nii.gz -V | cut -d " " -f1`
                left_voxels_cerebellum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebellum_left.nii.gz -V | cut -d " " -f1`
                right_voxels_cerebellum=`fslstats ${data_path}/${subject}_brain_${task}/${subject}_ses-${session}brain_task-${task}_bold_moco_topup_denoise2MNI_6dof_trialwise.feat/thresh_zstat${zstat}.nii.gz -k ${data_path}/masks/MNI152_T1_2mm_strucseg_cerebellum_right.nii.gz -V | cut -d " " -f1`
                
                if [ "${left_voxels_cerebellum}" -gt 0 ] || [ "${right_voxels_cerebellum}" -gt 0 ]; then
                    lr_cerebellum=`echo "scale=3; (${left_voxels_cerebellum} - ${right_voxels_cerebellum}) / (${left_voxels_cerebellum} + ${right_voxels_cerebellum})" | bc -l`
                else
                    lr_cerebellum=0
                fi

                echo ${task} ${cope} ${subject} ${trial} ${zstat} ${zscore_sc} ${voxels_sc} ${lr_sc} ${zscore_brain} ${voxels_brain} ${lr_brain} ${zscore_cerebrum} ${voxels_cerebrum} ${lr_cerebrum} ${zscore_cerebellum} ${voxels_cerebellum} ${lr_cerebellum}
                echo ${task} ${cope} ${subject} ${trial} ${zstat} ${zscore_sc} ${voxels_sc} ${lr_sc} ${zscore_brain} ${voxels_brain} ${lr_brain} ${zscore_cerebrum} ${voxels_cerebrum} ${lr_cerebrum} ${zscore_cerebellum} ${voxels_cerebellum} ${lr_cerebellum} >> subject_metrics_trialwise.txt
            done
        done
	done
done
