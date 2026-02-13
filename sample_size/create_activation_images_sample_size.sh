#!/bin/sh
# 
#

#Initialization of parameters
data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/manuscripts/sample_size/sample_size_iter_1000/
data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/manuscripts/sample_size/sample_size_iter_1000_run-1_test/
output_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/manuscripts/figures/sample_size_run-average
output_path=/home/sbedard/Projects/Dermatomal_Mapping_R01/manuscripts/figures/sample_size_run-1_test
spinal_cord_slices=(98 108 113 123 133 143)
sample_size=(10 15 20 25 28 30 35 39)
#sample_size=(39)
min=0.05
max=1

mkdir -p ${output_path}

for n in ${sample_size[@]}; do
# n38_freq_map.nii.gz
	# Crop PAM50 T2s and T2w
	fslroi ${SCT_DIR}/data/PAM50/template/PAM50_t2.nii.gz PAM50_t2_crop.nii.gz 32 75 34 75 691 263
	fslroi ${SCT_DIR}/data/PAM50/template/PAM50_t2s.nii.gz PAM50_t2s_crop.nii.gz 32 75 34 75 691 263

	overlay 0 1 PAM50_t2s_crop.nii.gz 300 800 ${data_path}/n${n}_freq_map.nii.gz $min $max n${n}_overlay
	overlay 0 1 PAM50_t2_crop.nii.gz 0 3000 ${data_path}/n${n}_freq_map.nii.gz  $min $max n${n}_overlay_t2
	#overlay 0 1 ${data_path}/masks/template_t2s_cropped_cord.nii.gz 300 800 ${data_path}/ses-spinalcord_task-${task}_N28_age_sex_cov2.3_fixed_corrected_masked.gfeat/${cope}.feat/thresh_zstat1.nii.gz 2.3 6.8 ${data_path}/ses-spinalcord_task-${task}_N28_age_sex_cov2.3_fixed_corrected_masked.gfeat/${cope}.feat/thresh_zstat2.nii.gz 2.3 6.8 ${cope}_overlay
	fslroi n${n}_overlay n${n}_overlay 15 47 22 32 0 -1
	fslroi n${n}_overlay_t2 n${n}_overlay_t2 12 51 0 -1 45 120

	# Create coronal slices y=36
	slicer n${n}_overlay_t2 -l renderjet -u -y -36  n${n}_y_36.png 
	#convert ${task}_${cope}_y_36.png -crop 33x20+1+122 crop.png

	for slice in ${spinal_cord_slices[@]}; do
		slicer n${n}_overlay -l renderjet -u -z -${slice} n${n}_z_${slice}.png
		#mv ${task}_${cope}_z_${slice}.png crop.png
		convert n${n}_z_${slice}.png -crop 47x36+0+111 crop.png
		mv crop.png n${n}_z_${slice}.png
	done

	pngappend n${n}_z_133.png - n${n}_z_133.png - n${n}_z_123.png - n${n}_z_113.png - n${n}_z_108.png - n${n}_z_98.png n${n}_axial.png


	rm n${n}_z*.png
	rm n${n}_overlay.nii.gz
	mv n${n}_axial.png ${output_path}/
	mv n${n}_y_36.png ${output_path}/

done
