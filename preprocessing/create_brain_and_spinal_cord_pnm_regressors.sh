#!/bin/bash
# 
#
# Created by Kenneth Weber on 10/18/2023. Modified by Valeria Oliva on 10/24/2023 for the Neuromuscular Signature Pilot. 
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
  Create slicewise pnm regressors for simultaneous brain and spinal cord fMRI.
  Output is slicewise regressor NIFTI images to be used in FEAT as voxelwise regressors.
  Requires that FSL is installed. This was last updated using FSL Version 6.0.
  All brain slices are collected first followed by all spinal cord slices or vice versa.
  
USAGE

  `basename ${0}` -b <brain_image> -c <cord_image> -p <physio> -s <slice_timing> -o <order> -t <task>


MANDATORY ARGUMENTS
  -b <brain>                  Brain input image
  -c <cord>                   Spinal cord input image
  -p <physio>                 Physio text file
  -s <slice>                  Slice timing text file
  -o <order>                  Order (0 = brain volume collected first, 1 = spinal cord volume collected first) 
  -t <task>                   Task 

EOF
}

if [ ! ${#@} -gt 0 ]; then
    usage `basename ${0}`
    exit 1
fi

#Initialization of variables
scriptname=${0}
brain=
cord=
physio=
slice=
order=
task=

while getopts “hb:c:p:s:o:t:” OPTION
do
	case $OPTION in
	h)
		usage
		exit 1
		;;
	b)
		brain=$OPTARG
		;;
	c)
		cord=$OPTARG
		;;
	p)
		physio=$OPTARG
		;;
	s)
		slice=$OPTARG
		;;
	o)
		order=$OPTARG
		;;
	t)
		task=$OPTARG
		;;
	?)
		usage
		exit
		;;
	esac
done

# Check the parameters
if [[ -z ${brain} ]]; then
	 echo "ERROR: Brain image not specified. Exit program."
     exit 1
fi
if [[ -z ${cord} ]]; then
    echo "ERROR: Cord image not specified. Exit program."
    exit 1
fi
if [[ -z ${physio} ]]; then
    echo "ERROR: Physio file not specified. Exit program."
    exit 1
fi
if [[ -z ${slice} ]]; then
    echo "ERROR: Slice timing file not specified. Exit program."
    exit 1
fi
if [[ -z ${order} ]]; then
    echo "ERROR: Order not specified. Exit program."
    exit 1
fi
if [[ -t ${task} ]]; then
    echo "ERROR: Task not specified. Exit program."
    exit 1
fi
# Check if the input files exist and are readable
if [[ ! -a ${brain} ]]; then
     echo "ERROR: ${input} does not exist or is not readable. Exit program."
     exit 1
fi

if [[ ! -a ${cord} ]]; then
    echo "ERROR: ${cord} does not exist or is not readable. Exit program."
    exit 1
fi
if [[ ! -a ${physio} ]]; then
     echo "ERROR: ${physio} does not exist or is not readable. Exit program."
     exit 1
fi

if [[ ! -a ${slice} ]]; then
    echo "ERROR: ${slice} does not exist or is not readable. Exit program."
    exit 1
fi

#if [[ ! -a ${task} ]]; then
#    echo "ERROR: ${task} does not exist. Continuing program for the other tasks."
#    exit 1
#fi


#### debugging ####

#echo ${brain} "brain"
#echo ${cord} "cord"
#echo ${physio} "physio"
#echo ${slice} "slice timing file"


# Check extensions of the input files
if [[ ${brain} != *.nii.gz ]] && [[ ${brain} != *.nii ]] && [[ ${brain} != *.img ]] && [[ ${brain} != *.img.gz ]]; then
	 echo "ERROR: ${brain} does not have .nii.gz, .nii, .img, or .img.gz extension. Exit program."
	 exit 1
fi

if [[ ${cord} != *.nii.gz ]] && [[ ${cord} != *.nii ]] && [[ ${cord} != *.img ]] && [[ ${cord} != *.img.gz ]]; then
	 echo "ERROR: ${cord} does not have .nii.gz, .nii, .img, or .img.gz extension. Exit program."
	 exit 1
fi

if [[ ${order} != 0 ]] && [[ ${order} != 1 ]]; then
	 echo "ERROR: Order does not equal 0 or 1. Exit program."
	 exit 1
fi

#Remove extension from files
brain=`remove_ext ${brain}`
cord=`remove_ext ${cord}`


# Check if the time dimensions of files are the same
brain_tdim=`fslval ${brain} dim4`
cord_tdim=`fslval ${cord} dim4`
brain_tr=`fslval ${brain} pixdim4` # Calculate TR or sampling period for time series
cord_tr=`fslval ${cord} pixdim4` # Calculate TR or sampling period for time series

#Calcualte difference in tr's with bc because bash does not compare floats well
tr_diff=`echo "${brain_tr} - ${cord_tr}" | bc`

# Error if time dimension not the same between brain and cord images
if [[ ${brain_tdim} != ${cord_tdim} ]]; then
    echo "ERROR: Time dimension of brain and spinal cord images do not match. Exit program."
    exit 1
fi

# Error if TR not the same between brain and cord images
if [[ ${tr_diff} != 0 ]]; then
    echo "ERROR: Repetitiion time of brain and spinal cord images do not match. Exit program."
    exit 1
fi

# Check the $FSLOUTPUTTYPE and assign the extension extension
if [ ${FSLOUTPUTTYPE} == 'NIFTI_GZ' ]; then
  file_ext=nii.gz
elif [ ${FSLOUTPUTTYPE} == 'NIFTI' ]; then
  file_ext=nii
elif [ ${FSLOUTPUTTYPE} == 'NIFTI_PAIR_GZ' ]; then
  file_ext=img.gz
elif [ ${FSLOUTPUTTYPE} == 'NIFTI_PAIR' ]; then
  file_ext=img
elif [ ${FSLOUTPUTTYPE} == 'ANALYZE_GZ' ]; then
  file_ext=img.gz
elif [ ${FSLOUTPUTTYPE} == 'ANALYZE' ]; then
  file_ext=img
else
    echo "ERROR: ${FSLOUTPUTTYPE} is not supported. Exit program."
    exit 1
fi

# Move input files to temporary folder and enter temporary folder
tmp_folder=`mktemp -u tmp.XXXXXXXXXX`
mkdir ${tmp_folder}
imcp ${brain} ${cord} ./${tmp_folder}
cp ${physio} ${slice} ./${tmp_folder}
cd ${tmp_folder}

#Remove path from input files
brain=$(basename ${brain})
cord=$(basename ${cord})

#Calculate total number of slices across brain and spinal cord
brain_zdim=`fslval ${brain} dim3`
cord_zdim=`fslval ${cord} dim3`
total_slices=$((brain_zdim + cord_zdim))

fslcreatehd 1 1 ${total_slices} ${brain_tdim} 1 1 1 ${brain_tr} 0 0 0 8 temp.nii.gz

popp -i ${physio} -o ./physio -s 100 --tr=${brain_tr} --smoothcard=0.1 --smoothresp=0.1 --resp=2 --cardiac=5 --trigger=3 -v --pulseox_trigger


# Run PNM using manual peak detections in derivatives
pnm_evs -i temp.nii.gz -c physio_card.txt -r physio_resp.txt -o physio_ --tr=${brain_tr} --oc=4 --or=4 --multc=2 --multr=2 --slicetiming=${slice} --slicedir=z

for file in physio_ev???.nii.gz; do

	echo Processing ${file}
	postfix=`echo ${file} | cut -d "_" -f2`
	
	if [[ ${order} == 1 ]]; then
		
		fslroi ${file} physio_brain_${postfix} 0 -1 0 -1 0 ${brain_zdim} 
		fslroi ${file} physio_spinalcord_${postfix} 0 -1 0 -1 ${brain_zdim} -1
		
	elif [[ ${order} == 0 ]]; then
	
		fslroi ${file} physio_spinalcord_${postfix} 0 -1 0 -1 0 ${cord_zdim} 
		fslroi ${file} physio_brain_${postfix} 0 -1 0 -1 ${cord_zdim} -1
	fi

	rm ${file}
	
done


mkdir PNM_${task}
mv physio* ./PNM_${task}/
# mv ${physio} ${slice} ./PNM # commented this line out to avoid moving data 



cp -rf PNM_${task} ../

#Move up to parent directory
cd ..

ls ${PWD}/PNM_${task}/*brain*nii.gz > PNM_${task}/brain_evlist.txt

ls ${PWD}/PNM_${task}/*cord*nii.gz > PNM_${task}/cord_evlist.txt
#Delete temporary folder

rm -rf ${tmp_folder}

exit 0
