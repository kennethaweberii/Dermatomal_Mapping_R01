#!/bin/bash
# 
#
# Created by Sandrine Bédard on 11/19/2023.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

#

function usage()
{
cat << EOF

DESCRIPTION
  Run spinal cord first level analysis.
  Requires that FSL is installed. This was last updated using FSL Version 6.0.
  
USAGE
  `basename ${0}` -i <input> -d <Path Derivatives>

MANDATORY ARGUMENTS
  -i <subject ID>      		  subject id. Example: sub-NSPilot007
  -d <output>                 Path to derivatives
EOF
}

if [ ! ${#@} -gt 0 ]; then
    usage `basename ${0}`
    exit 1
fi

# Get path of script repository
PATH_SCRIPTS=$PWD
path_source=$(dirname $PATH_SCRIPTS)
#Initialization of variables
scriptname=${0}
sub=
derivatives_path=

while getopts "hi:d:" OPTION; do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        i)
            sub=$OPTARG
            ;;
        d)
            derivatives_path=$OPTARG
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done


# Check the parameters
if [[ -z ${sub} ]]; then
	 echo "ERROR: Subject ID not specified. Exit program."
     exit 1
fi
if [[ -z ${derivatives_path} ]]; then
    echo "ERROR: path derivatives not specified. Exit program."
    exit 1
fi


# get starting time:
start=`date +%s`
for subject in $sub;do
    echo  "Analysing $subject ..."
    region="spinalcord"
    smoothing=0
    coil=""
    session=""
    analysis_path="${derivatives_path}/${subject}/"
    cd "${derivatives_path}/${subject}/ses-${region}/func/"
    export analysis_path subject coil session region smoothing
    echo ""${PATH_SCRIPTS}/first_level_average.fsf""
    envsubst < "${PATH_SCRIPTS}/first_level_average.fsf" > "${subject}_${region}_first_level_average.fsf"
    echo "Running first level average"
    feat ${subject}_${region}_first_level_average.fsf

    #trialwise average
    export analysis_path subject coil session region smoothing
    envsubst < "${PATH_SCRIPTS}/second_level_trialwise_average.fsf" > "${subject}_${region}_second_level_trialwise_average.fsf"
    feat ${subject}_${region}_second_level_trialwise_average.fsf
    cd ..
    cd ..
done



# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"