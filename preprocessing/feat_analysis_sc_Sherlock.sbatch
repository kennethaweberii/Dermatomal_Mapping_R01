#!/bin/bash 
#
#all commands that start with SBATCH contain commands that are just used by SLURM for scheduling  
#################
#set a job name  
#SBATCH --job-name=${subject}_${region}_${run}
#################  
#a file for job output, you can check job progress
#SBATCH --output=${subject}_${region}_${run}.out
#################
# a file for errors from the job
#SBATCH --error=${subject}_${region}_${run}.errƒ
#################
#time you think you need; default is one hour
#in minutes in this case, hh:mm:ss
#SBATCH --time=${time_limit}
#################
#quality of service; think of it as job priority
#SBATCH --qos=normal
#################
#SBATCH --mem=${memory}
#################

module load biology
module load fsl/6.0.7.10

echo ${subject} ${region} "run" ${run}

analysis_path=${SCRATCH}/${subject}_${region}_run-${run}
mkdir -p ${analysis_path}
cd ${analysis_path}
mkdir -p ./ses-${region}/func/run-${run}/
cd ./ses-${region}/func/run-${run}/
mkdir -p fsl_stim_vectors

func_data=${subject}_ses-${region}_task-tens_run-${run}_bold_mc2_pnm_stc2template_smooth225
file_path=${data_path}/data/BIDS/derivatives/${subject}/ses-${region}/func/run-${run}
coil=""
stim_file=*_stim_amp_1.txt
file_outliers=${subject}_ses-${region}_task-tens_run-${run}_bold_motion_outliers.txt

#Copy functional
ret=1
c=0
until [ ${ret} = 0 ] || [ ${c} = 5 ]; do
    echo "copying ${file_path}/${func_data}.nii.gz"
	scp sbedard@anes-nil1000.stanford.edu:${file_path}/${func_data}.nii.gz ./
    scp sbedard@anes-nil1000.stanford.edu:${file_path}/fsl_stim_vectors/* ./fsl_stim_vectors
    scp sbedard@anes-nil1000.stanford.edu:${file_path}/${file_outliers} ./
	ret=$?
	((c++))
done 
stim_parameters=`echo ${stim_file} | awk -F 'fsl_stim_vector_' '{print $2}' | awk -F '_stim_amp' '{print $1}'`
echo "stim parameter"
#me
if [[ ! -f "$file_outliers" ]]; then
    confoundevs=0
else
    confoundevs=1
fi

number_of_volumes=$(fslval ${func_data} dim4)
echo "Number of volumes: $number_of_volumes"
tr=$(fslval ${func_data} pixdim4)
echo "TR: $tr"

export FSLDIR analysis_path subject coil session smoothing run func_data region tr number_of_volumes stim_parameters confoundevs
envsubst < "${scripts_path}/first_level.fsf" > "${func_data}_first_level.fsf"
feat ${func_data}_first_level.fsf

cd ${func_data}_first_level.feat
mkdir -p reg
cp ${FSLDIR}/etc/flirtsch/ident.mat reg/example_func2standard.mat
cp example_func.nii.gz reg/example_func.nii.gz
cp example_func.nii.gz reg/standard.nii.gz
updatefeatreg .

cd ${analysis_path}

export analysis_path subject coil session run func_data region tr number_of_volumes stim_parameters smoothing confoundevs
envsubst < "${scripts_path}/first_level_trialwise.fsf" > "${func_data}_first_level_trialwise.fsf"
feat ${func_data}_first_level_trialwise.fsf

cd ${func_data}_first_level_trialwise.feat

mkdir -p reg
cp ${FSLDIR}/etc/flirtsch/ident.mat reg/example_func2standard.mat
cp example_func.nii.gz reg/example_func.nii.gz
cp example_func.nii.gz reg/standard.nii.gz
updatefeatreg .

cd ${analysis_path}

#Run second-level trialwise analysis
export analysis_path subject coil session run func_data region tr number_of_volumes stim_parameters smoothing
envsubst < "${scripts_path}/second_level_trialwise.fsf" > "${func_data}_second_level_trialwise.fsf"
feat ${func_data}_second_level_trialwise.fsf


rm ${func_data}.nii.gz ${func_data}_first_level_trialwise.fsf ${func_data}_first_level.fsf ${func_data}_second_level_trialwise.fsf

cd ${SCRATCH}
tar -zcvf ${subject}_${region}_run-${run}.tar.gz ${subject}_${region}_run-${run}

ret=1
c=0
until [  ${ret} = 0 ] || [ ${c} = 5 ]; do
	scp ${subject}_${region}_run-${run}.tar.gz sbedard@anes-nil1000.stanford.edu:${data_path}/data/BIDS/derivatives/${subject}/ses-${region}/func/run-${run}/
	ret=$?
	((c++))
done

#Remove temp folder

rm -rf ${analysis_path}