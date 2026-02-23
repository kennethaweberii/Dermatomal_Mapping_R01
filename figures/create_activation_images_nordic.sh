#!/bin/sh
# 
#

#Initialization of parameters
#data_path=/home/sbedard/dermatomal_mapping_proprocessing_2025-09-10_disc_reg_ALL/results/
data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/lindsay/BIDS/derivatives/data_processed/group_level_spinal_cord
output_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/lindsay/BIDS/derivatives/results/figures_trialwise_run-average/
spinal_cord_slices=(98 108 113 123 133 143)

task=tens
#copes=(amp_1 amp_2 amp_3 amp_4 linear)
copes=(amp_3 amp_4 linear)
type=randomize_corr2.3
min=2.3
max=3.5

for cope in ${copes[@]}; do

	echo ${task} ${cope}
	# Crop PAM50 T2s and T2w
	fslroi ${SCT_DIR}/data/PAM50/template/PAM50_t2.nii.gz PAM50_t2_crop.nii.gz 32 75 34 75 691 263
	fslroi ${SCT_DIR}/data/PAM50/template/PAM50_t2s.nii.gz PAM50_t2s_crop.nii.gz 32 75 34 75 691 263

	overlay 0 1 PAM50_t2s_crop.nii.gz 300 800 ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz $min $max ${cope}_overlay
	overlay 0 1 PAM50_t2_crop.nii.gz 0 3000 ${data_path}/GroupLevel_trialwise_${cope}_N40_${type}.gfeat/cope1.feat/thresh_zstat1.nii.gz $min $max ${cope}_overlay_t2
	#overlay 0 1 ${data_path}/masks/template_t2s_cropped_cord.nii.gz 300 800 ${data_path}/ses-spinalcord_task-${task}_N28_age_sex_cov2.3_fixed_corrected_masked.gfeat/${cope}.feat/thresh_zstat1.nii.gz 2.3 6.8 ${data_path}/ses-spinalcord_task-${task}_N28_age_sex_cov2.3_fixed_corrected_masked.gfeat/${cope}.feat/thresh_zstat2.nii.gz 2.3 6.8 ${cope}_overlay
	fslroi ${cope}_overlay ${cope}_overlay 15 47 22 32 0 -1
	fslroi ${cope}_overlay_t2 ${cope}_overlay_t2 12 51 0 -1 45 120

	# Create coronal slices y=36
	slicer ${cope}_overlay_t2 -u -y -36  ${cope}_y_36_${type}.png
	#convert ${task}_${cope}_y_36.png -crop 33x20+1+122 crop.png

	for slice in ${spinal_cord_slices[@]}; do
		slicer ${cope}_overlay -u -z -${slice} ${task}_${cope}_z_${slice}.png
		#mv ${task}_${cope}_z_${slice}.png crop.png
		convert ${task}_${cope}_z_${slice}.png -crop 47x36+0+111 crop.png
		mv crop.png ${task}_${cope}_z_${slice}.png
	done

	pngappend ${task}_${cope}_z_133.png - ${task}_${cope}_z_133.png - ${task}_${cope}_z_123.png - ${task}_${cope}_z_113.png - ${task}_${cope}_z_108.png - ${task}_${cope}_z_98.png ${cope}_${type}.png


	rm ${task}_${cope}_z*.png
	rm ${cope}_overlay.nii.gz
	mv ${cope}_${type}.png ${output_path}/
	mv ${cope}_y_36_${type}.png ${output_path}/

done
