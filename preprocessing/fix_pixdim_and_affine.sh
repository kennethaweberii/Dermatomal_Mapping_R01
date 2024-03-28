#!/bin/bash
#
# Created by Sandrine Bédard on 10/20/2023.
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
  Change pix dimensions of input image while matching affine of reference image.
  Requires that FSL is installed. This was last updated using FSL Version 6.0.
  
USAGE
  `basename ${0}` -i <input> -r <ref_image> -p <pixdim>  -o <output>

MANDATORY ARGUMENTS
  -i <input>                  Input image to correct
  -r <ref_image>              Reference image with the correct affine
  -p <pixdim>                 New pixel dimension to use E.g.: 1.25,1.25,5
  -o <output>                 Output filename
EOF
}



if [ ! ${#@} -gt 0 ]; then
    usage `basename ${0}`
    exit 1
fi

#Initialization of variables
scriptname=${0}
input=
ref=
pixdim=
output=

while getopts “hi:r:p:o:” OPTION
do
  case $OPTION in
  h)
    usage
    exit 1
    ;;
  i)
    input=$OPTARG
    ;;
  r)
    ref=$OPTARG
    ;;
  p)
    pixdim=$OPTARG
    ;;
  o)
    output=$OPTARG
    ;;
  ?)
    usage
    exit
    ;;
  esac
done

# Check the parameters
if [[ -z ${input} ]]; then
   echo "ERROR: Input image not specified. Exit program."
     exit 1
fi
if [[ -z ${ref} ]]; then
    echo "ERROR: Ref not specified. Exit program."
    exit 1
fi
if [[ -z ${pixdim} ]]; then
    echo "ERROR: pixdim not specified. Exit program."
    exit 1
fi
if [[ -z ${output} ]]; then
    echo "ERROR: Output not specified. Exit program."
    exit 1
fi

# Check if the input files exist and are readable
if [[ ! -a ${input} ]]; then
     echo "ERROR: ${input} does not exist or is not readable. Exit program."
     exit 1
fi

if [[ ! -a ${ref} ]]; then
    echo "ERROR: ${ref} does not exist or is not readable. Exit program."
    exit 1
fi

# Check extensions of the input files
if [[ ${input} != *.nii.gz ]] && [[ ${input} != *.nii ]] && [[ ${input} != *.img ]] && [[ ${input} != *.img.gz ]]; then
   echo "ERROR: ${input} does not have .nii.gz, .nii, .img, or .img.gz extension. Exit program."
   exit 1
fi

if [[ ${ref} != *.nii.gz ]] && [[ ${ref} != *.nii ]] && [[ ${ref} != *.img ]] && [[ ${ref} != *.img.gz ]]; then
   echo "ERROR: ${ref} does not have .nii.gz, .nii, .img, or .img.gz extension. Exit program."
   exit 1
fi

#Remove extension from files
input=`remove_ext ${input}`
ref=`remove_ext ${ref}`

# Move input files to temporary folder and enter temporary folder
tmp_folder=`mktemp -u tmp.XXXXXXXXXX`
mkdir ${tmp_folder}
imcp ${input} ${ref} ./${tmp_folder}
cd ${tmp_folder}

#Remove path from input files
input=$(basename ${input})
ref=$(basename ${ref})

# Step 1 : change pixdim
########################
cp ${input}.nii.gz ${input}_pixdim.nii.gz
# fetch input pixdim
IFS=',' read -ra my_array <<< "$pixdim"
p1_new=${my_array[0]}
p2_new=${my_array[1]}
p3_new=${my_array[2]}
echo
echo "X pixdim: $p1_new Y pixdim: $p2_new Z pixdim: $p3_new"
echo $pixdim
fslchpixdim ${input}_pixdim.nii.gz $p1_new $p2_new $p3_new

# Step 2: get pixdim and affine of reference image:
ref_im_dim=`fslinfo ${ref}`
p1_ref=`echo ${ref_im_dim} | cut -f14 -d' '`
p2_ref=`echo ${ref_im_dim} | cut -f16 -d' '`
p3_ref=`echo ${ref_im_dim} | cut -f18 -d' '`
dim1_ref=`echo ${ref_im_dim} | cut -f4 -d' '`
dim2_ref=`echo ${ref_im_dim} | cut -f6 -d' '`
dim3_ref=`echo ${ref_im_dim} | cut -f8 -d' '`

sform=`fslorient -getsform ${ref}`

echo
echo "pixdim1 $p1_ref pixdim2 $p2_ref pixdim3 $p3_ref"
echo "dim1 $dim1_ref dim2 $dim2_ref dim3 $dim3_ref"
echo "sform $sform"

# Step 3 : convert affine
# Copmute Ratio bewteen ref pixdim and new pixdim
ratio_1=`echo "scale=10; $p1_ref / $p1_new" | bc`
echo $ratio_1
ratio_2=`echo "scale=10; $p2_ref / $p2_new" | bc`
echo $ratio_2
ratio_3=`echo "scale=10; $p3_ref / $p3_new" | bc`
echo $ratio_3

# Divide columns 1 to 2 from affine with ratio.
# Column 1:
sform11=`echo ${sform} | cut -f1 -d' '`
sform11_new=`echo "scale=10; $sform11 / $ratio_1" | bc`
sform21=`echo ${sform} | cut -f5 -d' '`
sform21_new=`echo "scale=10; $sform21 / $ratio_1" | bc`
sform31=`echo ${sform} | cut -f9 -d' '`
sform31_new=`echo "scale=10; $sform31 / $ratio_1" | bc`

# Column 2:
sform12=`echo ${sform} | cut -f2 -d' '`
sform12_new=`echo "scale=10; $sform12 / $ratio_2" | bc`
sform22=`echo ${sform} | cut -f6 -d' '`
sform22_new=`echo "scale=10; $sform22 / $ratio_2" | bc`
sform32=`echo ${sform} | cut -f10 -d' '`
sform32_new=`echo "scale=10; $sform32 / $ratio_2" | bc`

# Column 3:
sform13=`echo ${sform} | cut -f3 -d' '`
sform13_new=`echo "scale=10; $sform13 / $ratio_3" | bc`
sform23=`echo ${sform} | cut -f7 -d' '`
sform23_new=`echo "scale=10; $sform23 / $ratio_3" | bc`
sform33=`echo ${sform} | cut -f11 -d' '`
sform33_new=`echo "scale=10; $sform33 / $ratio_3" | bc`

# Compute translation
sform_a=`echo ${sform} | cut -f4 -d' '`
sform_b=`echo ${sform} | cut -f8 -d' '`
sform_c=`echo ${sform} | cut -f12 -d' '`

trans_a=`echo "scale=10; (($dim1_ref*$p1_ref) / 2) - (($dim1_ref*$p1_new) / 2)" | bc`
trans_b=`echo "scale=10; (($dim2_ref*$p2_ref) / 2) - (($dim2_ref*$p2_new) / 2)" | bc`
trans_c=`echo "scale=10; (($dim3_ref*$p3_ref) / 2) - (($dim3_ref*$p3_new) / 2)" | bc`  # need to check in which direction...

# Set new translation
sform_a_new=`echo "scale=10; $sform_a - $trans_a" | bc`
sform_b_new=`echo "scale=10; $sform_b + $trans_b" | bc`
extra_z_trans=`echo "scale=10; $trans_b*sqrt(1-($sform33_new/$p3_new)^2)" | bc`
sform_c_new=`echo "scale=10; $sform_c + $trans_c - $extra_z_trans" | bc` # TODO: check the sign, if matrix size smaller
# Set new sform:

cp ${input}_pixdim.nii.gz ${input}_pixdim_newheader.nii.gz
`fslorient -setsform $sform11_new $sform12_new $sform13_new $sform_a_new $sform21_new $sform22_new $sform23_new $sform_b_new $sform31_new $sform32_new $sform33_new $sform_c_new 0 0 0 1 ${input}_pixdim_newheader.nii.gz`
`fslorient -copysform2qform ${input}_pixdim_newheader.nii.gz`
mv ${input}_pixdim_newheader.nii.gz $output
# Copy files to parent directory
imcp ${output} ../

#Move up to parent directory
cd ..

#Delete temporary folder

rm -rf ${tmp_folder}

echo "Run the following to view the results:"
echo "fsleyes ${output} &"

exit 0