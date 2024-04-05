#!/bin/bash
# 
#
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

function usage()
{
cat << EOF

DESCRIPTION
  Brain preprocessing script for Dermatomal Mapping R01
  Requires that ANTs and FSL are installed.
  
USAGE
  `basename ${0}` -f <folder> -s <subject> -x <session>

MANDATORY ARGUMENTS
  -f <folder>               Path to BIDS sourcedata folder (BIDS/sourcedata)
  -s <subject>              Subject Study ID (sub-DMAim1HC###, or sub-DMAim2HC###)
  -v <stim_vectors>         Path to FSL stim vectors folder
  -x <session>              Optional argument to specify a session (Default=Blank)

EOF
}

if [ ! ${#@} -gt 0 ]; then
    usage `basename ${0}`
    exit 1
fi

#Initialization of variables

scriptname=${0}
folder=
subject=
stim=
session=

while getopts “hf:s:v:x:” OPTION
do
  case $OPTION in
  h)
    usage
    exit 1
    ;;
  f)
    folder=$OPTARG
    ;;
  s)
    subject=$OPTARG
    ;;
  v)
    stim=$OPTARG
    ;;
  x)
    session=$OPTARG
    ;;
  ?)
     usage
     exit
     ;;
  esac
done

script_path=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# # Check the parameters

if [[ -z ${folder} ]]; then
   echo "ERROR: Folder not specified. Exit program."
     exit 1
fi

if [[ -z ${subject} ]]; then
     echo "ERROR: Subject not specified. Exit program."
     exit 1
fi

if [[ -z ${stim} ]]; then
     echo "ERROR: FSL stim vector folder not specified. Exit program."
     exit 1
fi

folder=`readlink -f ${folder}`
stim=`readlink -f ${stim}`

if [[ ! -d ${stim} ]]; then
     echo "ERROR: ${stim} does not exist. Exit program."
     exit 1
fi

if [[ ! -d ${folder}/${subject} ]]; then
     echo "ERROR: ${folder}/${subject} does not exist. Exit program."
     exit 1
fi

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

if [[ -f ${HOME}/anaconda3/etc/profile.d/conda.sh ]]; then
  source ${HOME}/anaconda3/etc/profile.d/conda.sh
elif [[ -f ${HOME}/Miniconda3/etc/profile.d/conda.sh ]]; then
  source ${HOME}/Miniconda3/etc/profile.d/conda.sh
else
  echo Python not installed. Exit program.
  exit 1
fi

#Activate conda environment
source ${HOME}/anaconda3/etc/profile.d/conda.sh
#eval "$(conda shell.bash hook)"
conda activate Dermatomal_Mapping_R01

#Setup output path
output_path=`pwd`

temp_folder=${subject}_preprocess_brain_temp`date +%Y%m%d%H%M%S`
analysis_path=${HOME}/${temp_folder}
mkdir -p ${analysis_path}

cp -rf ${folder}/${subject}/ses-brain* ${analysis_path}

cd ${analysis_path}

coils=(21Ch)
for coil in ${coils[@]}; do

  ###########################################################################################
  #T1w
  ###########################################################################################

  if [[ -f ${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w.nii.gz ]]; then

    cd ${analysis_path}/ses-brain${coil}${session}/anat

    antsBrainExtraction.sh -d 3 -a ${subject}_ses-brain${coil}${session}_T1w.nii.gz -m ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz  -e ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz -o T1w_brain
    immv T1w_brainBrainExtractionBrain ${subject}_ses-brain${coil}${session}_T1w_brain
    immv T1w_brainBrainExtractionMask ${subject}_ses-brain${coil}${session}_T1w_brain_seg

    #Get bounding box coordinates slightly larger than brain and apply to T1w
    fslmaths ${subject}_ses-brain${coil}${session}_T1w_brain_seg -dilD -dilD -dilD temp
    bounding_box=`fslstats temp -w`
    imrm temp

    fslroi ${subject}_ses-brain${coil}${session}_T1w ${subject}_ses-brain${coil}${session}_T1w ${bounding_box}
    fslroi ${subject}_ses-brain${coil}${session}_T1w_brain ${subject}_ses-brain${coil}${session}_T1w_brain ${bounding_box}
    fslroi ${subject}_ses-brain${coil}${session}_T1w_brain_seg ${subject}_ses-brain${coil}${session}_T1w_brain_seg ${bounding_box}

    #Segment brain with fast

    fast ${subject}_ses-brain${coil}${session}_T1w_brain
    fslmaths ${subject}_ses-brain${coil}${session}_T1w_brain_pve_0 -thr 0.5 -bin ${subject}_ses-brain${coil}${session}_T1w_brain_csf_seg
    fslmaths ${subject}_ses-brain${coil}${session}_T1w_brain_pve_2 -thr 0.5 -bin ${subject}_ses-brain${coil}${session}_T1w_brain_wm_seg
    
  fi

  ###########################################################################################
  #Functional Run 1
  ###########################################################################################
  runs=(1)
  for run in ${runs[@]}; do
    if [[ -f ${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w_brain.nii.gz ]] && [[ -f ${analysis_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.nii.gz ]]; then

      cd ${analysis_path}/ses-brain${coil}${session}/func

      cp -rf ${stim} ./
      
      #Remove dummy volumes
      fslroi ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold 3 -1
      
      #Get dims
      number_of_volumes=`fslval ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold dim4`
      tr=`fslval ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold pixdim4`
   
      #Run motion correction
      moco_ref_volume=`echo "scale=0; ${number_of_volumes}/2" | bc`

      fslroi ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_ref ${moco_ref_volume} 1

      mcflirt -in ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold -out ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco -mats -plots -reffile ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_ref -rmsrel -rmsabs

      fslmaths ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco -Tmean ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_mean
      fslmaths ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco -Tstd ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_std
      fslmaths ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_mean -div ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_std ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_tsnr

      bet ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_mean ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_brain_seg
      fslmaths ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_brain_seg -bin ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_brain_seg

      fsl_motion_outliers -i ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco -m ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_brain_seg --dvars --nomoco -o ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_motion_outliers.txt

      if [[ -f ${analysis_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz ]]; then

        #Run topup
        fslroi ${analysis_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold_ref 1 1
        fslroi ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-PA_bold_ref ${moco_ref_volume} 1
        flirt -in ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold_ref -ref ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-PA_bold_ref -out ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold_ref
        fslmerge -t ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_topup ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-PA_bold_ref ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold_ref

        rm -f acq_param.txt
        echo "0 1 0 1" >> acq_param.txt
        echo "0 -1 0 1" >> acq_param.txt

        topup --imain=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_topup --datain=acq_param.txt --config=b02b0.cnf --out=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_topup
        applytopup --imain=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco --inindex=1 --datain=acq_param.txt --topup=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_topup --out=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_topup --method=jac
        func_data=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco_topup
  
      else

        echo No ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz!
        echo Skipping topup for ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.nii.gz!
        func_data=${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold_moco

      fi

      #Create white matter and csf masks in functional space
      fslmaths ${func_data} -Tmean ${func_data}_mean
      epi_reg --epi=${func_data}_mean --t1=${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w --t1brain=${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w_brain --out=${func_data}_example_func2highres --wmseg=${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w_brain_wm_seg.nii.gz
      convert_xfm -inverse -omat ${func_data}_highres2example_func.mat ${func_data}_example_func2highres.mat
      flirt -in ${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w_brain_wm_seg.nii.gz -ref ${func_data}_mean -out ${func_data}_wm_seg -applyxfm -init ${func_data}_highres2example_func.mat -interp nearestneighbour
      flirt -in ${analysis_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w_brain_csf_seg.nii.gz -ref ${func_data}_mean -out ${func_data}_csf_seg -applyxfm -init ${func_data}_highres2example_func.mat -interp nearestneighbour
      
      fslmeants -i ${func_data} --eig -m ${func_data}_csf_seg -o ${func_data}_csf.txt
      fslmeants -i ${func_data} --eig -m ${func_data}_wm_seg -o ${func_data}_wm.txt

      #Process physio
      if [[ -f ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio.physio ]] && [[ -f ${script_path}/create_FSL_physio_text_file.py ]]; then
        
        echo starting physio

        python ${script_path}/create_FSL_physio_text_file.py -i ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio.physio -TR ${tr} -number-of-volumes ${number_of_volumes}
        python ${script_path}/detect_peak_pnm.py -i ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio.txt -o ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio_peak.txt

        # Run PNM using manual peak detections in derivatives
        popp -i ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio_peak.txt -o physio -s 100 --tr=${tr} --smoothcard=0.1 --smoothresp=0.1 --resp=2 --cardiac=5 --trigger=3 -v --pulseox_trigger
        pnm_evs -i ${func_data} -c physio_card.txt -r physio_resp.txt -o physio --tr=${tr} --oc=4 --or=4 --multc=2 --multr=2 --sliceorder=interleaved_up --slicedir=z

        rm -rf ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio
        mkdir ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio

        mv physio* ./${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio

      fi

      region=brain
      export analysis_path subject coil session run func_data region tr number_of_volumes
	    envsubst < "${script_path}/physio_evlist.txt" > "${func_data}_physio_evlist.txt"
      envsubst < "${script_path}/brain_pnm.fsf" > "${func_data}_pnm.fsf"
	    feat ${func_data}_pnm.fsf

      fslmaths ${func_data}_pnm.feat/stats/res4d.nii.gz -add ${func_data}_pnm.feat/mean_func.nii.gz ${func_data}_pnm
      func_data=${func_data}_pnm

      #Run slicetime correction
      slicetimer -i ${func_data} -o ${func_data}_stc --odd

      applywarp -i ${func_data}_stc -o ${func_data}_stc2standard -w ${func_data}.feat/reg/example_func2standard_warp -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain
      func_data=${func_data}_stc2standard

      #Run first-level analysis
      region=brain

      #Get stim parameters
      stim_file=./fsl_stim_vectors/*_stim_amp_1.txt
      stim_parameters=`echo ${stim_file} | awk -F 'fsl_stim_vector_' '{print $2}' | awk -F '_stim_amp' '{print $1}'`

      stim_params=./fsl_stim_vectors/*_stim_amp_1.txt
      export analysis_path subject coil session run func_data region tr number_of_volumes stim_parameters
      envsubst < "${script_path}/first_level.fsf" > "${func_data}_first_level.fsf"
	    feat ${func_data}_first_level.fsf

      #Run registration for first level analysis
      cd ${analysis_path}/ses-brain${coil}${session}/func/${func_data}_first_level.feat
      mkdir reg
      fslmaths mean_func -bin mask
      imcp mean_func ./reg/example_func
      cd reg
      cp ${FSLDIR}/etc/flirtsch/ident.mat example_func2highres.mat
      cp ${FSLDIR}/etc/flirtsch/ident.mat highres2standard.mat
      imcp ../mean_func highres
      imcp ../mean_func standard
      cd ..
      updatefeatreg .

      cd ${analysis_path}/ses-brain${coil}${session}/func

      #Run first-level trialwise analysis
      region=brain
      export analysis_path subject coil session run func_data region tr number_of_volumes stim_parameters
      envsubst < "${script_path}/first_level_trialwise.fsf" > "${func_data}_first_level_trialwise.fsf"
	    feat ${func_data}_first_level_trialwise.fsf

      #Run registration for first level trialwise analysis
      cd ${analysis_path}/ses-brain${coil}${session}/func/${func_data}_trialwise.feat
      mkdir reg
      fslmaths mean_func -bin mask
      imcp mean_func ./reg/example_func
      cd reg
      cp ${FSLDIR}/etc/flirtsch/ident.mat example_func2highres.mat
      cp ${FSLDIR}/etc/flirtsch/ident.mat highres2standard.mat
      imcp ../mean_func highres
      imcp ../mean_func standard
      cd ..
      updatefeatreg .

      cd ${analysis_path}/ses-brain${coil}${session}/func

      #Run second-level trialwise analysis
      region=brain
      export analysis_path subject coil session run func_data region tr number_of_volumes stim_parameters
      envsubst < "${script_path}/second_level_trialwise.fsf" > "${func_data}_second_level_trialwise.fsf"
	    feat ${func_data}_second_level_trialwise.fsf
      
    else

      echo Error!
      echo Skipping ${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.nii.gz!

    fi

  done
done



exit 0