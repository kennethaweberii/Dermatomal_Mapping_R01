#!/bin/sh
# 
#

data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01
scripts_path=${HOME}/codes/Dermatomal_Mapping_R01/preprocessing

subjects=(sub-DMAim1HCHC004_testing_sherlock)

regions=(spinalcord)
runs=(1 2 3)

for run in ${runs[@]}; do  #consider moving this loop to other
    for subject in ${subjects[@]}; do
        for region in ${regions[@]}; do

            echo ${subject} ${region} ${run}
            
            if [ ${region} == brain ]; then
                time_limit=04:00:00
                memory=8000
                smoothing=5
            else
                time_limit=06:00:00
                memory=16000
                smoothing=0
            fi

            export data_path scripts_path SCRATCH subject region run time_limit memory smoothing
            envsubst '${data_path} ${scripts_path} ${SCRATCH} ${subject} ${region} ${run} ${time_limit} ${memory} ${smoothing}' < ${scripts_path}/preprocessing/feat_analysis_sc_Sherlock.sbatch > feat_analysis_sc_Sherlock_${subject}_${region}_${task}.sbatch
            sbatch feat_analysis_sc_Sherlock_${subject}_${region}_${run}.sbatch
            rm trialwise_analysis_sc_Sherlock_${subject}_${region}_${run}.sbatch
            # TODO: run average
            sleep 10s

        done
    done
done
