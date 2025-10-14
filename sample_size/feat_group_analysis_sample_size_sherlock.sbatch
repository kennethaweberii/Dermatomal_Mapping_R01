#!/bin/bash 
#
#all commands that start with SBATCH contain commands that are just used by SLURM for scheduling  
#################
#set a job name  
#SBATCH --job-name=${n}_${iter}
#################  
#a file for job output, you can check job progress
#SBATCH --output=${n}_${iter}.out
#################
# a file for errors from the job
#SBATCH --error=${n}_${iter}.err
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

echo 

mkdir -p ${path_data}/sample_size/n${n}/
cd ${path_data}/sample_size/n${n}/
echo subjects: ${subjects[@]}
for i in "${!subjects[@]}"; do
  export sub${i}="${subjects[$i]}"
done

export FSLDIR output_path subjects path_data
envsubst < "${path_script}/design_n${n}_amp4_randomise_2.3.fsf" > "design_n${n}_iter_${iter}_amp4_randomise_2.3.fsf"
feat "design_n${n}_iter_${iter}_amp4_randomise_2.3.fsf"

# TODO to adjust
rm "design_n${n}_iter_${iter}_amp4_randomise_2.3.fsf"
cd ${path_data}/sample_size/n${n}/
tar -zcvf n${n}_iter_${iter}_amp4_randomise_2.3.tar.gz sample_size_${n}_iter_${iter}.gfeat


ret=1
c=0
until [  ${ret} = 0 ] || [ ${c} = 5 ]; do
	#scp n${n}_iter_${iter}_amp4_randomise_2.3.tar.gz sbedard@anes-nil1000.stanford.edu:/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/sample_size/group_level/n${n}/n${n}_iter_${iter}_amp4_randomise_2.3.tar.gz
	scp -r sample_size_${n}_iter_${iter}.gfeat sbedard@anes-nil1000.stanford.edu:/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/sample_size/group_level/n${n}/sample_size_${n}_iter_${iter}.gfeat/
	ret=$?
	((c++))
done