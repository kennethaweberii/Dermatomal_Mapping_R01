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
  Convert dcm to bids format for Dermatomal Mapping R01
  Requires that dcm2niix and FSL are installed.
  Requires fix_pixdim_and_affine.sh
  
USAGE
  `basename ${0}` -f <folder> -s <subject>

MANDATORY ARGUMENTS
  -f <folder>               Dicom folder from scanner (E#####)
  -s <subject>              Subject Study ID (sub-DMAim1HC###, or sub-DMAim2HC###, or sub-DMAim3HC###, or sub-DMAim3CR###)
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
session=
while getopts “hf:s:x:” OPTION
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

#Setup output path
output_path=`pwd`
output_path=${output_path}/${subject}

mkdir -p ${output_path}

mkdir -p ${output_path}/ses-brain21Ch${session}
mkdir -p ${output_path}/ses-brain21Ch${session}/anat
mkdir -p ${output_path}/ses-brain21Ch${session}/func
mkdir -p ${output_path}/ses-brain21Ch${session}/fmap

mkdir -p ${output_path}/ses-spinalcord21Ch${session}
mkdir -p ${output_path}/ses-spinalcord21Ch${session}/anat
mkdir -p ${output_path}/ses-spinalcord21Ch${session}/dwi
mkdir -p ${output_path}/ses-spinalcord21Ch${session}/func
mkdir -p ${output_path}/ses-spinalcord21Ch${session}/fmap

mkdir -p ${output_path}/ses-brain56Ch${session}
mkdir -p ${output_path}/ses-brain56Ch${session}/anat
mkdir -p ${output_path}/ses-brain56Ch${session}/func
mkdir -p ${output_path}/ses-brain56Ch${session}/fmap

mkdir -p ${output_path}/ses-spinalcord56Ch${session}
mkdir -p ${output_path}/ses-spinalcord56Ch${session}/anat
mkdir -p ${output_path}/ses-spinalcord56Ch${session}/dwi
mkdir -p ${output_path}/ses-spinalcord56Ch${session}/func
mkdir -p ${output_path}/ses-spinalcord56Ch${session}/fmap

cd ${folder}
data_path=`pwd`

# Copy data to home directory for analysis
temp_folder=${subject}_temp`date +%Y%m%d%H%M%S`
analysis_path=${HOME}/${temp_folder}/${folder}
mkdir -p ${analysis_path}

rsync -avz --exclude="*.h5" ${data_path}/* ${analysis_path}/

#Convert anat files
cd ${analysis_path}

if [ -d ${analysis_path}/anat ]; then
  cd ${analysis_path}/anat
  echo Converting ${analysis_path}/anat to NIFTI
  for dir in */ ; do
    echo Converting ${dir} to NIFTI
    rm -rf ${analysis_path}/nii_${dir}
    mkdir ${analysis_path}/nii_${dir}
    dcm2niix -b y  -f %s -z y -x n -v y -o ${analysis_path}/nii_${dir} ./${dir}
  done
else
  echo Skipping ${analysis_path}/anat. Folder does not exist.
fi

#Convert func files

cd ${analysis_path}
echo Converting ${analysis_path}/data to NIFTI
for dir in e${folder:1}*/ ; do
  echo Converting ${dir} to NIFTI
  rm -rf ${analysis_path}/nii_${dir}
  mkdir ${analysis_path}/nii_${dir}
  dcm2niix -b y -f %s -z y -x n -v y -o ${analysis_path}/nii_${dir} ./${dir}/matlabDicoms
done

cd ${analysis_path}

for dir in nii_*/ ; do
  echo ${dir}
  cd ${analysis_path}/${dir}
  for file in *.json; do
    
    echo ${file}
    filename=${file::-5}
    
    if [ -f ${filename}.json ]; then
      series=`grep 'SeriesDescription' ${filename}.json`
      if [[ ${series} == *"21-Ch"* ]]; then
        coil=21Ch
      elif [[ ${series} == *"56-Ch"* ]]; then
        coil=56Ch
      else
        coil=
      fi

    else
      series="No *json file in ${dir}"
      
    fi

    echo $series
        
    ###########################################################################################
    #T1w
    ###########################################################################################

    if [[ ${series} == *"Ch_T1w"* ]] && [[ ${series} != *"ORIG"* ]]; then

      cp ${filename}.json ${output_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w.json
      cp ${filename}.nii.gz ${output_path}/ses-brain${coil}${session}/anat/${subject}_ses-brain${coil}${session}_T1w.nii.gz

    
    ###########################################################################################
    #T2w
    ###########################################################################################

    elif [[ ${series} == *"T2w"* ]] && [[ ${series} != *"ORIG"* ]]; then
      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_T2w.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_T2w.nii.gz

    ###########################################################################################
    #Functional Scans
    ###########################################################################################

    ###########################################################################################
    #Brain Functional Scans
    ###########################################################################################

    elif ([[ ${series} == *"run-1"* ]] || [[ ${series} == *"run-2"* ]]) && [[ ${dir} != "nii_e"* ]] && [[ ${series} == *"brain"* ]]  && [[ ${series} != *"pepolar"* ]]; then

      if [[ ${series} == *"run-1"* ]]; then
        run=1
      elif [[ ${series} == *"run-2"* ]]; then
        run=2
      else
        run=
      fi
      
      cp ${filename}.json ${output_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.json
      cp ${filename}.nii.gz ${output_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.nii.gz
      
      physio_file=`ls ${analysis_path}/*S$(printf "%03d" ${filename})P*`

      cp ${analysis_path}/Data_${folder:1}/P${physio_file: -8:6}.physio ${output_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_physio.physio
      sed -i 's/"ConversionSoftwareVersion"/"PhaseEncodingDirection": "j",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.json
      sed -i 's/"SAR"/"TaskName": "'"tens"'",\n\t"SAR"/' ${output_path}/ses-brain${coil}${session}/func/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_bold.json

    ###########################################################################################
    #Brain pepolar
    ###########################################################################################

    elif ([[ ${series} == *"run-1_pepolar"* ]] || [[ ${series} == *"run-2_pepolar"* ]]) && [[ ${dir} != "nii_e"* ]] && [[ ${series} == *"brain"* ]] && [[ ${series} == *"pepolar"* ]]; then
      
      if [[ ${series} == *"run-1"* ]]; then
        run=1
      elif [[ ${series} == *"run-2"* ]]; then
        run=2
      else
        run=
      fi
      
      cp ${filename}.json ${output_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      cp ${filename}.nii.gz ${output_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz

      sed -i 's/"ConversionSoftwareVersion"/"PhaseEncodingDirection": "j-",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      sed -i 's/"ConversionSoftwareVersion"/"IntendedFor": "ses-brain${coil}${session}\/func\/'${subject}'_ses-brain${coil}${session}_task-tens_run-${run}_bold.nii.gz",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      sed -i 's/"SAR"/"TaskName": "'"tens"'",\n\t"SAR"/' ${output_path}/ses-brain${coil}${session}/fmap/${subject}_ses-brain${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
    
    ###########################################################################################
    #SC Functional Scans
    ###########################################################################################

    elif ([[ ${series} == *"run-1"* ]] || [[ ${series} == *"run-2"* ]]) && [[ ${dir} == "nii_e"* ]] && [[ ${series} == *"SC"* ]]  && [[ ${series} != *"pepolar"* ]]; then

      if [[ ${series} == *"run-1"* ]]; then
        run=1
      elif [[ ${series} == *"run-2"* ]]; then
        run=2
      else
        run=
      fi

      series_folder=`echo ${dir} | cut -d "_" -f2`
      recon_json_file=${analysis_path}/${series_folder}/*.json
      pfile=`grep 'Pfile_name' ${recon_json_file} | cut -d ' ' -f3 | cut -d ',' -f1`
      #Add leading zeros to pfile
      pfile=$(printf "%05d" ${pfile})
      
      # calculate TotalReadoutTime 
      # if PartialFourer=1, TotalReadoutTime = EffectiveEchoSpacing * (rdb_hdr_rc_yres / ksepi_multishot_control / 2 + kynover / ksepi_multishot_control)
      # if PartialFourer=0, TotalReadoutTime = EffectiveEchoSpacing * rdb_hdr_rc_yres / ksepi_multishot_control 
      EES=`grep 'EffectiveEchoSpacing' ${recon_json_file} | cut -f3 -d ' '`
      Ny=`grep 'rdb_hdr_rc_yres' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      R=`grep 'ksepi_multishot_control' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      kynover=`grep 'kynover' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      PartialFourier=0
      if [[ ${PartialFourier} -eq 1 ]]; then
        TotalReadoutTime=`echo "$EES*$Ny/$R/2+$EES*$kynover/$R" | bc -l`
      else
        TotalReadoutTime=`echo "$EES*$Ny/$R" | bc -l`
      fi
      echo "EES=$EES, Ny=$Ny, R=$R, kynover=$kynover, TotalReadoutTime=$TotalReadoutTime"
      
      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.nii.gz
      
      cp ${analysis_path}/Data_${folder:1}/P${pfile}.physio ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_physio.physio
      sed -i 's/"ConversionSoftwareVersion"/"PhaseEncodingDirection": "j",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.json
      sed -i 's/"SAR"/"TaskName": "'"tens"'",\n\t"SAR"/' ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.json
      sed -i 's/"SAR"/"TotalReadoutTime": "'"${TotalReadoutTime}"'",\n\t"SAR"/' ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.json

    ###########################################################################################
    #SC pepolar
    ###########################################################################################

    elif ([[ ${series} == *"run-1_pepolar"* ]] || [[ ${series} == *"run-2_pepolar"* ]]) && [[ ${dir} == "nii_e"* ]] && [[ ${series} == *"SC"* ]] && [[ ${series} == *"pepolar"* ]]; then
      
      if [[ ${series} == *"run-1"* ]]; then
        run=1
      elif [[ ${series} == *"run-2"* ]]; then
        run=2
      else
        run=
      fi
      
      series_folder=`echo ${dir} | cut -d "_" -f2`
      recon_json_file=${analysis_path}/${series_folder}/*.json

      # calculate TotalReadoutTime 
      # if PartialFourer=1, TotalReadoutTime = EffectiveEchoSpacing * (rdb_hdr_rc_yres / ksepi_multishot_control / 2 + kynover / ksepi_multishot_control)
      # if PartialFourer=0, TotalReadoutTime = EffectiveEchoSpacing * rdb_hdr_rc_yres / ksepi_multishot_control 
      EES=`grep 'EffectiveEchoSpacing' ${recon_json_file} | cut -f3 -d ' '`
      Ny=`grep 'rdb_hdr_rc_yres' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      R=`grep 'ksepi_multishot_control' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      kynover=`grep 'kynover' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      PartialFourier=0
      if [[ ${PartialFourier} -eq 1 ]]; then
        TotalReadoutTime=`echo "$EES*$Ny/$R/2+$EES*$kynover/$R" | bc -l`
      else
        TotalReadoutTime=`echo "$EES*$Ny/$R" | bc -l`
      fi
      echo "EES=$EES, Ny=$Ny, R=$R, kynover=$kynover, TotalReadoutTime=$TotalReadoutTime"

      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz

      sed -i 's/"ConversionSoftwareVersion"/"PhaseEncodingDirection": "j-",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      sed -i 's/"ConversionSoftwareVersion"/"IntendedFor": "ses-spinalcord${coil}${session}\/func\/'${subject}'_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.nii.gz",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      sed -i 's/"SAR"/"TaskName": "'"tens"'",\n\t"SAR"/' ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
      sed -i 's/"SAR"/"TotalReadoutTime": "'"${TotalReadoutTime}"'",\n\t"SAR"/' ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.json
    
    ###########################################################################################
    #highres
    ###########################################################################################

    elif [[ ${series} == *"highres"* ]] && [[ ${dir} == "nii_e"* ]] && [[ ${series} == *"SC"* ]]; then
      
      series_folder=`echo ${dir} | cut -d "_" -f2`
      recon_json_file=${analysis_path}/${series_folder}/*.json

      # calculate TotalReadoutTime
      # if PartialFourer=1, TotalReadoutTime = EffectiveEchoSpacing * (rdb_hdr_rc_yres / ksepi_multishot_control / 2 + kynover / ksepi_multishot_control)
      # if PartialFourer=0, TotalReadoutTime = EffectiveEchoSpacing * rdb_hdr_rc_yres / ksepi_multishot_control 
      EES=`grep 'EffectiveEchoSpacing' ${recon_json_file} | cut -f3 -d ' '`
      Ny=`grep 'rdb_hdr_rc_yres' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      R=`grep 'ksepi_multishot_control' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      kynover=`grep 'kynover' ${recon_json_file} | cut -f3 -d ' ' | cut -f1 -d ','`
      PartialFourier=0
      if [[ ${PartialFourier} -eq 1 ]]; then
        TotalReadoutTime=`echo "$EES*$Ny/$R/2+$EES*$kynover/$R" | bc -l`
      else
        TotalReadoutTime=`echo "$EES*$Ny/$R" | bc -l`
      fi
      echo "EES=$EES, Ny=$Ny, R=$R, kynover=$kynover, TotalReadoutTime=$TotalReadoutTime"

      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.nii.gz

      sed -i 's/"ConversionSoftwareVersion"/"PhaseEncodingDirection": "j",\n\t"ConversionSoftwareVersion"/' ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.json
      sed -i 's/"SAR"/"TotalReadoutTime": "'"${TotalReadoutTime}"'",\n\t"SAR"/' ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.json

    ###########################################################################################
    #SC_DWI
    ###########################################################################################

    elif [[ ${series} == *"DWI"* ]]; then
        cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/dwi/${subject}_ses-spinalcord${coil}${session}_dwi.json
        cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/dwi/${subject}_ses-spinalcord${coil}${session}_dwi.nii.gz
        cp ${filename}.bval ${output_path}/ses-spinalcord${coil}${session}/dwi/${subject}_ses-spinalcord${coil}${session}_dwi.bval
        cp ${filename}.bvec ${output_path}/ses-spinalcord${coil}${session}/dwi/${subject}_ses-spinalcord${coil}${session}_dwi.bvec

    ###########################################################################################
    #MERGE
    ###########################################################################################

    elif [[ ${series} == *"MERGE"* ]] && [[ ${series} != *"ORIG"* ]]; then
        cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_T2star.json
        cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_T2star.nii.gz
    
    ###########################################################################################
    #MT
    ###########################################################################################

    elif [[ ${series} == *"GRE-T1w"* ]] && [[ ${series} != *"ORIG"* ]]; then
      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-T1w_MTS.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-T1w_MTS.nii.gz

    elif [[ ${series} == *"GRE-MT1"* ]] && [[ ${series} != *"ORIG"* ]]; then
      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-MTon_MTS.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-MTon_MTS.nii.gz

    elif [[ ${series} == *"GRE-MT0"* ]] && [[ ${series} != *"ORIG"* ]]; then
      cp ${filename}.json ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-MToff_MTS.json
      cp ${filename}.nii.gz ${output_path}/ses-spinalcord${coil}${session}/anat/${subject}_ses-spinalcord${coil}${session}_acq-MToff_MTS.nii.gz
    

    else 
      echo Skipping ${series}
    fi

  done

done

###########################################################################################
#Run fix_pixdim_and_affine.sh using highres
###########################################################################################
echo ${script_path}

coils=(21Ch 56Ch)
runs=(1 2)
for coil in ${coils[@]}; do
  for run in ${runs[@]}; do

    if [ -f ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.nii.gz ] && [ -f ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.nii.gz ] && [ -f ${script_path}/fix_pixdim_and_affine.sh ]; then
      echo Fixing pixdim and affine for ${coil}_SC_run-${run}
      bash ${script_path}/fix_pixdim_and_affine.sh -i ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.nii.gz -r ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.nii.gz -p 1,1,4.00  -o ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_bold.nii.gz

    else  
      echo Skipping pixdim and affine for ${coil}_SC_run-${run}
    fi
  done
done

coils=(21Ch 56Ch)
runs=(1 2)
for coil in ${coils[@]}; do
  for run in ${runs[@]}; do

    if [ -f ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz ] && [ -f ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.nii.gz ] && [ -f ${script_path}/fix_pixdim_and_affine.sh ]; then
      echo Fixing pixdim and affine for for ${coil}_SC_run-${run}_pepolar
      bash ${script_path}/fix_pixdim_and_affine.sh -i ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz -r ${output_path}/ses-spinalcord${coil}${session}/func/${subject}_ses-spinalcord${coil}${session}_acq-highres_bold.nii.gz -p 1,1,4.00  -o ${output_path}/ses-spinalcord${coil}${session}/fmap/${subject}_ses-spinalcord${coil}${session}_task-tens_run-${run}_dir-AP_bold.nii.gz

    else  
      echo Skipping pixdim and affine for ${coil}_SC_run-${run}_pepolar
    fi 
  
  done
done

exit 0