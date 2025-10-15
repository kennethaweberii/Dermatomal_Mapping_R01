#!/bin/sh
# 
#
path_script=~/codes/Dermatomal_Mapping_R01/sample_size/
path_data=${SCRATCH}/dermatomal_mapping_R01/derivatives
path_list=${SCRATCH}/dermatomal_mapping_R01/lists/
iterations=100
#iterations=1
n_sample=(10 15 20 25 30 35)
n_sample=(15 20 25 30 35)
#n_sample=(10)


time_limit=08:00:00
memory=16000

for n in "${n_sample[@]}"; do
    for iter in $(seq 1 $iterations); do
        sub_list=${path_list}/sample_${n}/include_sample_${n}_${iter}.txt

        output_path=${path_data}/sample_size/n${n}/sample_size_${n}_iter_${iter}
        #mkdir -p ${output_path}
        subjects=($(< ${sub_list}))
        echo "${subjects[@]}"
        for i in "${!subjects[@]}"; do
            export sub${i}="${subjects[$i]}"
        done
        export path_script path_data SCRATCH time_limit memory output_path subjects n iter
        envsubst '${path_data} ${path_script} ${SCRATCH} ${time_limit} ${memory} ${output_path} ${subjects} ${n} ${iter}' < ${path_script}/feat_group_analysis_sample_size_sherlock.sbatch > feat_group_analysis_sample_size_sherlock_n${n}_iter${iter}.sbatch
        sbatch feat_group_analysis_sample_size_sherlock_n${n}_iter${iter}.sbatch
        rm feat_group_analysis_sample_size_sherlock_n${n}_iter${iter}.sbatch
        sleep 10s
    done
done