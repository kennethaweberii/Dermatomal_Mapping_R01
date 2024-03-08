#!/bin/bash
#
# Analayses spinal cord data for the Neuromuscular signature R01 project.
#
# Usage:
#     sct_run_batch -c <PATH_TO_REPO>/etc/config_process_data.json  # TODO
#
# The following global variables are retrieved from the caller sct_run_batch
# but could be overwritten by uncommenting the lines below:
# PATH_DATA_PROCESSED="~/data_processed"
# PATH_RESULTS="~/results"
# PATH_LOG="~/log"
# PATH_QC="~/qc"
#
#
#
# Manual segmentations or labels should be located under:
# PATH_DATA/derivatives/labels/SUBJECT/ses-0X/anat/
#
#
#
# Authors: Sandrine Bédard and Kenneth Weber
#

# Uncomment for full verbose
set -x

# Immediately exit if error
#set -e -o pipefail  # comment to not skip

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Print retrieved variables from sct_run_batch to the log (to allow easier debug)
echo "Retrieved variables from from the caller sct_run_batch:"
echo "PATH_DATA: ${PATH_DATA}"
echo "PATH_DATA_PROCESSED: ${PATH_DATA_PROCESSED}"
echo "PATH_RESULTS: ${PATH_RESULTS}"
echo "PATH_LOG: ${PATH_LOG}"
echo "PATH_QC: ${PATH_QC}"
# Get path derivatives
path_source=$(dirname $PATH_DATA)
PATH_DERIVATIVES="${path_source}/derivatives/labels"
PATH_MODEL="${path_source}/derivatives/"
# Get path of script repository
PATH_SCRIPTS=$PWD

# CONVENIENCE FUNCTIONS
# ======================================================================================================================
segment_if_does_not_exist() {
  ###
  #  This function checks if a manual spinal cord segmentation file already exists, then:
  #    - If it does, copy it locally.
  #    - If it doesn't, perform automatic spinal cord segmentation
  #  This allows you to add manual segmentations on a subject-by-subject basis without disrupting the pipeline.
  ###
  local file="$1"
  local contrast="$2"
  local segmentation_method="$3"  # deepseg or propseg
  local subfolder="$4"
  # Update global variable with segmentation file name
  FILESEG="${file}_seg"
  FILESEGMANUAL="${PATH_DERIVATIVES}/${SUBJECT}/${subfolder}/${FILESEG}.nii.gz"
  echo
  echo "Looking for manual segmentation: $FILESEGMANUAL"
  if [[ -e $FILESEGMANUAL ]]; then
    echo "Found! Using manual segmentation."
    rsync -avzh $FILESEGMANUAL ${FILESEG}.nii.gz
    sct_qc -i ${file}.nii.gz -s ${FILESEG}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -qc-subject ${SUBJECT}
    # Rename manual seg to seg name
    #mv ${FILESEG}.nii.gz ${file}_seg.nii.gz
  else
    echo "Not found. Proceeding with automatic segmentation."
    # Segment spinal cord
    if [[ $segmentation_method == 'deepseg' ]];then
        #sct_deepseg_sc -i ${file}.nii.gz -c ${contrast} -qc ${PATH_QC} -qc-subject ${SUBJECT}
        python $PATH_SCRIPTS/contrast-agnostic-seg-model/run_inference_single_image.py --path-img ${file}.nii.gz --path-out . --chkp-path "$PATH_MODEL/contrast-agnostic-seg-model/nnunet_nf=32_DS=1_opt=adam_lr=0.001_AdapW_CCrop_bs=2_64x192x320_20230918-2253"
        sct_maths -i ${file}_pred.nii.gz -bin 0.5 -o ${file}_pred_bin.nii.gz
        sct_qc -i ${file}.nii.gz -s ${file}_pred_bin.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -qc-subject ${SUBJECT}
        mv ${file}_pred_bin.nii.gz ${file}_seg.nii.gz
    elif [[ $segmentation_method == 'propseg' ]]; then
        sct_propseg -i ${file}.nii.gz -c ${contrast} -qc ${PATH_QC} -qc-subject ${SUBJECT} -CSF
    fi
  fi
}


label_if_does_not_exist(){
  ###
  #  This function checks if a manual labels exists, then:
  #    - If it does, copy it locally and use them to initialize vertebral labeling
  #    - If it doesn't, perform automatic vertebral labeling
  ###
  local file="$1"
  local file_seg="$2"
  # Update global variable with segmentation file name
  FILELABEL="${file}_labels-disc"
  FILELABELMANUAL="${PATH_DERIVATIVES}/${SUBJECT}/anat/${FILELABEL}-manual.nii.gz"
  echo "Looking for manual label: $FILELABELMANUAL"
  if [[ -e $FILELABELMANUAL ]]; then
    echo "Found! Using manual labels."
    rsync -avzh $FILELABELMANUAL ${FILELABEL}.nii.gz
    # Generate labeled segmentation from manual disc labels
    sct_label_vertebrae -i ${file}.nii.gz -s ${file_seg}.nii.gz -discfile ${FILELABEL}.nii.gz -c t2 -qc ${PATH_QC} -qc-subject ${SUBJECT}
  else
    echo "Not found. Proceeding with automatic labeling."
    # Generate vertebral labeling
    sct_label_vertebrae -i ${file}.nii.gz -s ${file_seg}.nii.gz -c t2 -qc ${PATH_QC} -qc-subject ${SUBJECT}
  fi
}

# Retrieve input params and other params
SUBJECT=$1
tasks="${@:2}"
echo "Tasks:"
echo $tasks

# get starting time:
start=`date +%s`


# SCRIPT STARTS HERE
# ==============================================================================
# Display useful info for the log, such as SCT version, RAM and CPU cores available
sct_check_dependencies -short

# Go to folder where data will be copied and processed
cd $PATH_DATA_PROCESSED

# Copy source images
# Note: we use '/./' in order to include the sub-folder 'ses-0X'
rsync -Ravzh $PATH_DATA/./$SUBJECT .

cd ${SUBJECT}/anat

# Define variables
# We do a substitution '/' --> '_' in case there is a subfolder 'ses-0X/'
file="${SUBJECT//[\/]/_}"

# Get session
SES=$(basename "$SUBJECT")
# get subject name without session
sub_id=$(dirname "$SUBJECT")

# Only include spinal cord sessions
if [[ $SES == *"spinalcord"* ]];then
    # -------------------------------------------------------------------------
    # T2w
    # -------------------------------------------------------------------------

    # Add suffix corresponding to contrast
    file_t2w=${file}_T2w
    # Check if T2w image exists
    if [[ -f ${file_t2w}.nii.gz ]];then
        # Create directory for T2w results
        mkdir -p ${PATH_DATA_PROCESSED}/${SUBJECT}/anat/T2w
        cp ${file_t2w}.nii.gz ${PATH_DATA_PROCESSED}/${SUBJECT}/anat/T2w
        cd T2w
        
        # Spinal cord segmentation
        # Note: For T2w images, we use sct_deepseg_sc with 2 kernel. Generally, it works better than sct_propseg and sct_deepseg_sc with 3d kernel.
        segment_if_does_not_exist ${file_t2w} 't2' 'deepseg' 'anat'
        file_t2_seg="${file_t2w}_seg"

        # Vertebral labeling 
        label_if_does_not_exist ${file_t2w} ${file_t2w}_seg
        file_t2_labels="${file_t2w}_seg_labeled"
        file_t2_labels_discs="${file_t2w}_seg_labeled_discs"

        # Extract dics 1 to 10 for registration to template (C1 to T2-T3)
        sct_label_utils -i ${file_t2_labels_discs}.nii.gz -keep 1,2,3,4,5,6,7,8,9,10 -o ${file_t2_labels_discs}_1to10.nii.gz
        file_t2_labels_discs="${file_t2w}_seg_labeled_discs_1to10"

        sct_register_to_template -i ${file_t2w}.nii.gz -s ${file_t2_seg}.nii.gz -ldisc ${file_t2_labels_discs}.nii.gz -c t2 -qc ${PATH_QC} -qc-subject ${SUBJECT}

        cd ..
    else
        echo Skipping T2w
    fi

    # -------------------------------------------------------------------------
    # FUNC
    # -------------------------------------------------------------------------
    cd ../func
    file_task_rest="${file}_task-rest_bold"
    file_task_finger="${file}_task-FingerTap_bold"
    file_task_percent="${file}_task-ForcePercent_bold"
    file_task_abs="${file}_task-ForceAbs_bold"

    contrasts=($file_task_finger $file_task_percent $file_task_abs $file_task_rest) # 
    if [ -z "$tasks" ]
    then
          echo "\$tasks is empty"
          tasks="FingerTap ForcePercent ForceAbs rest"
    else
          echo "\$tasks"
    fi
    for file_task in "${contrasts[@]}";do
      if [[ -f ${file_task}.nii.gz ]];then
          # Create directory for task results
            # Find contrast to do compute CSA
          if [[ $file_task == *"rest"* ]];then
            task="rest"
          elif [[ $file_task == *"FingerTap"* ]];then
            task="FingerTap"
          elif [[ $file_task == *"ForcePercent"* ]];then
            task="ForcePercent"
          elif [[ $file_task == *"ForceAbs"* ]];then
            task="ForceAbs"
          fi
          echo ${task}
          if [[ "$tasks" == *"$task"* ]];then

            # TODO maybe add intensity norm??
            mkdir -p ${PATH_DATA_PROCESSED}/${SUBJECT}/func/$task
            cp ${file_task}.nii.gz ${PATH_DATA_PROCESSED}/${SUBJECT}/func/$task/
            cd $task
            mkdir -p ${PATH_DATA_PROCESSED}/${SUBJECT}/func/$task/PNM_$task/  # Create PNM folder
            # Delete first 2 volumes
            # Check number of volumes, if 354, remove first 2
            tdimi=`fslval ${file_task} dim4`
            if [[ $tdim=="354" ]]; then
              fslroi ${file_task} ${file_task} 2 352
            fi
            # Compute mean image
            sct_maths -i ${file_task}.nii.gz -mean t -o ${file_task}_mean.nii.gz
            file_task_mean="${file_task}_mean"
            
            # Create mask if doesn't exist:
            FILE_MASK="${PATH_DERIVATIVES}/${SUBJECT}/func/${file_task_mean}_mask.nii.gz"
            echo
            echo "Looking for manual spinal mask: $FILE_MASK"
            if [[ -e $FILE_MASK ]]; then
              echo "Found! Using manual segmentation."
              rsync -avzh $FILE_MASK "${file_task_mean}_mask.nii.gz"
            else
              # Segment the spinal cord
              segment_if_does_not_exist ${file_task_mean} 't2s' 'propseg' 'func'
              # Create a spinal canal mask
              sct_maths -i ${file_task_mean}_seg.nii.gz -add ${file_task_mean}_CSF_seg.nii.gz -o ${file_task_mean}_SC_canal_seg.nii.gz
              # Dilate the spinal canal mask
              # check dilating
              sct_maths -i ${file_task_mean}_SC_canal_seg.nii.gz -dilate 5 -shape disk -o ${file_task_mean}_mask.nii.gz -dim 2

              # Qc of Spinal canal segmentation
              sct_qc -i ${file_task_mean}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s ${file_task_mean}_SC_canal_seg.nii.gz -qc-subject ${SUBJECT}
            fi
            # Qc of mask
            sct_qc -i ${file_task_mean}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s ${file_task_mean}_mask.nii.gz -qc-subject ${SUBJECT}

            if [[ ! -f ${file_task}_mc2.nii.gz ]]; then
              # --------------------
              # 2D Motion correction
              # --------------------
              # Step 1 of 2D motion correction using mid volume
              # Select mid volume
              fslroi ${file_task} ${file_task}_mc1_ref 177 1
              # Apply motion correction
              ${PATH_SCRIPTS}/motion_correction/2D_slicewise_motion_correction.sh -i ${file_task}.nii.gz -r ${file_task}_mc1_ref.nii.gz -m ${file_task_mean}_mask.nii.gz -o mc1
              
              # Step 2 of 2D motion correction using mean of mc1 as ref
              # Create mask if doesn't exist:
              FILE_MASK="${PATH_DERIVATIVES}/${SUBJECT}/func/mc1_mask.nii.gz"
              echo
              echo "Looking for manual spinal mask: $FILE_MASK"
              if [[ -e $FILE_MASK ]]; then
                echo "Found! Using manual segmentation."
                rsync -avzh $FILE_MASK "mc1_mask.nii.gz"
              else
              # Segment the spinal cord
                segment_if_does_not_exist mc1_mean 't2s' 'propseg' 'func'
                # Create a spinal canal mask
                sct_maths -i mc1_mean_seg.nii.gz -add mc1_mean_CSF_seg.nii.gz -o mc1_mean_SC_canal_seg.nii.gz
                # Dilate the spinal canal mask
                # check dilating
                sct_maths -i mc1_mean_SC_canal_seg.nii.gz -dilate 5 -shape disk -o mc1_mask.nii.gz -dim 2
                # Qc of Spinal canal segmentation
                sct_qc -i mc1_mean.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s mc1_mean_SC_canal_seg.nii.gz -qc-subject ${SUBJECT}
                # Qc of mask
                sct_qc -i  mc1_mean.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s mc1_mask.nii.gz -qc-subject ${SUBJECT}
              fi
              # Apply motion correction step 2
              ${PATH_SCRIPTS}/motion_correction/2D_slicewise_motion_correction.sh -i mc1.nii.gz -r mc1_mean.nii.gz -m mc1_mask.nii.gz -o mc2

              mv mc2.nii.gz ${file_task}_mc2.nii.gz
              mv mc2_mean.nii.gz ${file_task}_mc2_mean.nii.gz
              mv mc2_tsnr.nii.gz ${file_task}_mc2_tsnr.nii.gz
              mv mc2_mat.tar.gz ${file_task}_mc2_mat.tar.gz

              # Move motion regressors to .PNM
              mv Rz.nii.gz ./PNM_$task
              mv Tx.nii.gz ./PNM_$task
              mv Ty.nii.gz ./PNM_$task
            fi
            # Create spinal cord mask and spinal canal mask
            file_task_mc2=${file_task}_mc2
            file_task_mc2_mean=${file_task}_mc2_mean

            FILE_SPINAL_CANAL_SEG="${PATH_DERIVATIVES}/${SUBJECT}/func/${file_task_mc2_mean}_SC_canal_seg.nii.gz"
            echo
            echo "Looking for manual spinal canal segmentation: $FILE_SPINAL_CANAL_SEG"
            if [[ -e $FILE_SPINAL_CANAL_SEG ]]; then
              echo "Found! Using manual segmentation."
              rsync -avzh $FILE_SPINAL_CANAL_SEG "${file_task_mc2_mean}_SC_canal_seg.nii.gz"
            else
              echo "No manual spinal canal segmentation found in the derivatives. Running automatic segmentation."
              segment_if_does_not_exist ${file_task_mc2_mean} 't2s' 'propseg' 'anat'
              sct_maths -i ${file_task_mc2_mean}_seg.nii.gz -add ${file_task_mc2_mean}_CSF_seg.nii.gz -o ${file_task_mc2_mean}_SC_canal_seg.nii.gz

            fi

            # Qc of Spinal canal segmentation
            sct_qc -i ${file_task_mc2_mean}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s ${file_task_mc2_mean}_SC_canal_seg.nii.gz -qc-subject ${SUBJECT}

            # Create segmentation using sct_deepseg_sc          
            FILE_SEG="${PATH_DERIVATIVES}/${SUBJECT}/func/${file_task_mc2_mean}_seg.nii.gz"
            echo
            echo "Looking for manual spinal cord segmentation: $FILE_SEG"
            if [[ -e $FILE_SEG ]]; then
              echo "Found! Using manual segmentation."
              rsync -avzh $FILE_SEG "${file_task_mc2_mean}_seg.nii.gz"
              sct_qc -i ${file_task_mc2_mean}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s ${file_task_mc2_mean}_seg.nii.gz -qc-subject ${SUBJECT}
            else
              python $PATH_SCRIPTS/contrast-agnostic-seg-model/run_inference_single_image.py --path-img ${file_task_mc2_mean}.nii.gz --path-out . --chkp-path "$PATH_MODEL/contrast-agnostic-seg-model/nnunet_nf=32_DS=1_opt=adam_lr=0.001_AdapW_CCrop_bs=2_64x192x320_20230918-2253"
              sct_maths -i ${file_task_mc2_mean}_pred.nii.gz -bin 0.5 -o ${file_task_mc2_mean}_pred_bin.nii.gz
              sct_qc -i ${file_task_mc2_mean}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -s ${file_task_mc2_mean}_pred_bin.nii.gz -qc-subject ${SUBJECT}
              mv ${file_task_mc2_mean}_pred_bin.nii.gz ${file_task_mc2_mean}_seg.nii.gz
            fi
            file_task_mc2_mean_seg="${file_task_mc2_mean}_seg"

            # QC for motion correction
            sct_qc -i ${file_task_mc2}.nii.gz -p sct_fmri_moco -qc ${PATH_QC} -s ${file_task_mc2_mean_seg}.nii.gz -d  ${file_task}.nii.gz -qc-subject ${SUBJECT}

            # Register to T2w image
            sct_register_multimodal -i ${SCT_DIR}/data/PAM50/template/PAM50_t2.nii.gz -iseg ${SCT_DIR}/data/PAM50/template/PAM50_cord.nii.gz -d ${file_task_mc2_mean}.nii.gz -dseg ${file_task_mc2_mean_seg}.nii.gz -param step=1,type=seg,algo=centermass:step=2,type=seg,algo=bsplinesyn,metric=MeanSquares,slicewise=1,iter=3:step=3,type=im,algo=syn,metric=CC,iter=1,slicewise=1 -initwarp ../../anat/T2w/warp_template2anat.nii.gz -initwarpinv ../../anat/T2w/warp_anat2template.nii.gz -qc ${PATH_QC} -qc-subject ${SUBJECT}
            
            # Warp to template (do we want the spinal levels ?? if so add -s 1)
            sct_warp_template -d ${file_task_mc2_mean}.nii.gz -w warp_PAM50_t22${file_task_mc2_mean}.nii.gz -qc ${PATH_QC} -qc-subject ${SUBJECT}

            # Create CSF regressor
            file_task_mc2=${file_task}_mc2  # to remove
            # Create CSF mask form spinal cord seg and spinal canal seg
            fslmaths ${file_task_mc2}_mean_seg -binv temp_mask
            fslmaths ${file_task_mc2}_mean_SC_canal_seg -mul temp_mask ${file_task_mc2}_csf_mask
            rm temp_mask.nii.gz
            # TODO: switch to eig value
            ${PATH_SCRIPTS}/utils/create_slicewise_regressor_from_mask.sh -i ${file_task_mc2}.nii.gz -m ${file_task_mc2}_csf_mask.nii.gz -o csf_regressor
            mv ${file_task_mc2}_csf_regressor.nii.gz ./PNM_$task

            # Create WM regressor
            fslmaths ./label/template/PAM50_wm.nii.gz -thr 0.9 -bin ${file_task_mc2}_wm_mask
            ${PATH_SCRIPTS}/utils/create_slicewise_regressor_from_mask.sh -i ${file_task_mc2}.nii.gz -m ${file_task_mc2}_wm_mask.nii.gz -o wm_regressor
            mv ${file_task_mc2}_wm_regressor.nii.gz ./PNM_$task

    
            # Look inside derivatives for evs
            #Get session number
            ses_num=${SES%"spinalcord"}
            PATH_EVS="${PATH_MODEL}/${sub_id}/${ses_num}brain/func/PNM_$task"  # TODO replace spinalcord in session by brain
            echo " Path with spinal cord EVS : $PATH_EVS"
            echo "Looking for spinal cord EVS"
            if [[ -d $PATH_EVS ]]; then
              echo "Found! Using existing EVS."
              rsync -avzh $PATH_EVS/physio_spinalcord* ./PNM_$task/
              ls ${PWD}/PNM_$task/*.nii.gz > ./PNM_$task/cord_evlist.txt # Create ev list
            else
              echo "No evs found. exiting"
              #exit
            fi

            cp ${PATH_SCRIPTS}/utils/denoise.fsf ./
            export PATH_DATA_PROCESSED SUBJECT file_task task
            envsubst < "denoise.fsf" > "denoise_${file_task}.fsf"
            # Remove existing feat repo if already exists
            if [[ -d "${file_task_mc2}_pnm.feat" ]]; then
              rm -r "${file_task_mc2}_pnm.feat"
            fi
            feat denoise_${file_task}.fsf

            # Create denoised image
            fslmaths ./${file_task_mc2}_pnm.feat/stats/res4d.nii.gz -add ./${file_task_mc2}_pnm.feat/mean_func.nii.gz ${file_task_mc2}_pnm
            tr=`fslval ${file_task_mc2} pixdim4` # Get TR of volumes
            fslsplit ${file_task_mc2}_pnm vol -t
            v=vol????.nii.gz
            fslmerge -tr ${file_task_bold_mc2}_pnm ${v} ${tr}
            rm $v

            # Find motion outliers
            fsl_motion_outliers -i ${file_task_mc2} -m ${file_task_mc2_mean_seg} --dvars --nomoco -o ${file_task_mc2}_dvars_motion_outliers.txt

            # Warp each volume to the template
            fslsplit ${file_task_mc2}_pnm vol -t
            tr=`fslval ${file_task_mc2}_pnm pixdim4` # Get TR of volumes
            tdimi=`fslval ${file_task_mc2}_pnm dim4` # Get the number of volumes
            last_volume=$(echo "scale=0; $tdimi-1" | bc) # Find index of last volume
            for ((k=0; k<=$last_volume; k++));do
                vol="$(printf "vol%04d" ${k})"
                sct_apply_transfo -i ${vol}.nii.gz -d ${SCT_DIR}/data/PAM50/template/PAM50_t2.nii.gz -w warp_${file_task_mc2_mean}2PAM50_t2.nii.gz -o ${vol}2template.nii.gz -x spline
                fslmaths ${vol}2template.nii.gz -mul ${SCT_DIR}/data/PAM50/template/PAM50_cord.nii.gz ${vol}2template.nii.gz
                fslroi ${vol}2template.nii.gz ${vol}2template.nii.gz 32 75 34 75 691 263
            done
            v="vol????2template.nii.gz"
            fslmerge -tr ${file_task_mc2}_pnm2template $v $tr # Merge warped volumes together
            rm $v
            v=vol????.nii.gz
            rm $v

            #Remove outside voxels based on spinal cord mask z limits
            sct_apply_transfo -i ${file_task_mc2_mean_seg}.nii.gz -d ${SCT_DIR}/data/PAM50/template/PAM50_t2.nii.gz -w warp_${file_task_mc2_mean}2PAM50_t2.nii.gz -o ${file_task_mc2_mean_seg}2template.nii.gz -x nn
            fslroi ${file_task_mc2_mean_seg}2template.nii.gz ${file_task_mc2_mean_seg}2template.nii.gz 32 75 34 75 691 263
            fslmaths ${file_task_mc2_mean_seg}2template.nii.gz -kernel 2 -dilD -dilD -dilD -dilD -dilD temp_mask
            fslmaths ${file_task_mc2}_pnm2template -mul temp_mask ${file_task_mc2}_pnm2template
            rm temp_mask.nii.gz
            #Smoothing 2x2x5 mm
            #sigma= 2mm/2.354 = | sigma = 5m/2.354 for 2mm and 5 mm of full width at half maximum (FWHM)
            fslmaths ${file_task_mc2}_pnm2template.nii.gz -s 0.85,0.84,2.124 ${file_task_mc2}_pnm2template_smooth.nii.gz
            cd ..
          fi
      else
          echo "Skipping $task"
      
      fi
    done

fi


# Verify presence of output files and write log file if error
# ------------------------------------------------------------------------------
FILES_TO_CHECK=(
  "FingerTap/${file_task_finger}_mc2_pnm2template_smooth.nii.gz"
  "ForcePercent/${file_task_percent}_mc2_pnm2template_smooth.nii.gz"
  "ForceAbs/${file_task_abs}_mc2_pnm2template_smooth.nii.gz"
  #"rest/${file_task_rest}_mc2_pnm2template_smooth.nii.gz" # To uncomment
)
pwd
for file in ${FILES_TO_CHECK[@]}; do
  if [[ ! -e $file ]]; then
    echo "${SUBJECT}/func/${file} does not exist" >> $PATH_LOG/_error_check_output_files.log
  fi
done

# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "SCT version: `sct_version`"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"
