#!/bin/sh
# 
#

data_path=/home/sbedard/Projects/Dermatomal_Mapping_R01
scripts_path=${HOME}/codes/Dermatomal_Mapping_R01/preprocessing


subjects=(sub-DMAim1HC006)

regions=(spinalcord)
runs=(1 2 3)
runs=(2)

for subject in ${subjects[@]}; do
    for run in ${runs[@]}; do  #consider moving this loop to other
        for region in ${regions[@]}; do

            echo ${subject} ${region} "run " ${run}
            
            if [ ${region} == brain ]; then
                time_limit=04:00:00
                memory=8000
                smoothing=5
            else
                time_limit=08:00:00
                memory=16000
                smoothing=0
            fi

            export data_path scripts_path SCRATCH subject region run time_limit memory smoothing
            envsubst '${data_path} ${scripts_path} ${SCRATCH} ${subject} ${region} ${run} ${time_limit} ${memory} ${smoothing}' < ${scripts_path}/feat_analysis_sc_Sherlock.sbatch > feat_analysis_sc_Sherlock_${subject}_${region}_${run}.sbatch
            sbatch feat_analysis_sc_Sherlock_${subject}_${region}_${run}.sbatch
            rm feat_analysis_sc_Sherlock_${subject}_${region}_${run}.sbatch
            sleep 10s

        done
        # # Run average across runs
        # time_limit=08:00:00
        # memory=16000
        # smoothing=0
        # export data_path scripts_path SCRATCH subject region run time_limit memory smoothing
        # envsubst '${data_path} ${scripts_path} ${SCRATCH} ${subject} ${region} ${run} ${time_limit} ${memory} ${smoothing}' < ${scripts_path}/feat_analysis_sc_Sherlock_average.sbatch > feat_analysis_sc_Sherlock_${subject}_${region}_${run}_average.sbatch
        # sbatch feat_analysis_sc_Sherlock_${subject}_${region}_${run}_average.sbatch
        # rm feat_analysis_sc_Sherlock_${subject}_${region}_${run}_average.sbatch
        # sleep 10s

    done
done
