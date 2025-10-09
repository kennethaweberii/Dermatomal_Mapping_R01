import matplotlib.pyplot as plt
import pandas as pd
import argparse
import yaml
import numpy as np
import logging
import sys
import os
import glob
import nibabel as nib
import random
import csv

def get_parser():
    parser = argparse.ArgumentParser(
        description="Computes avreage tSNR map in PAM50 template space from native space tSNR maps.",)
    parser.add_argument('-sample', required=False, type=int, nargs="+", default=[10, 15, 20, 25, 30, 35, 40],
                        help="List of sample size.")
    parser.add_argument('-include', required=True, type=str,
                        default='include.yml',
                        help="Inlcude list .yml file with subjects to include. If not provided, all subjects found will be included.")
    parser.add_argument('-iterations', required=False, type=int,
                        default=100,
                        help="Number of iterations to perform.")

    parser.add_argument('-o', required=False, type=str,
                        help="Path output to put tsnr maps in PAM50 template space.")

    return parser

#file_format= /home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives/sub-DMAim1HC006/ses-spinalcord/func/sub-DMAim1HC006_ses-spinalcord_task-tens_run-average_bold_mc2_pnm_stc2template_smooth225_trialwise_second_level.gfeat/cope4.feat


def main():

    args = get_parser().parse_args()
    # Get input arguments
    samples = args.sample
    include = args.include
    output = args.o

    # Load list of subjects to include
    with open(include, 'r') as stream:
        try:
            include = list(yaml.safe_load(stream))
            print(f"Included subjects: {include}")
        except yaml.YAMLError as exc:
            print(f"Error loading YAML file: {exc}")
            sys.exit(1)
    # Create output folder if does not exist.

    if not os.path.exists(output):
        os.mkdir(output)
    os.chdir(output)

    for sample in samples:
        sample_dir = os.path.join(output, f'sample_{sample}')
        if not os.path.exists(sample_dir):
            os.mkdir(sample_dir)
        print(f"🔁 Generating {args.iterations} subsamples of size {sample}...")
        for i in range(args.iterations):
            # Randomly select 'sample' subjects from the include list
            selected_subjects = random.sample(include, sample)
            # Save the selected subjects to a new .txt file
            output_txt = os.path.join(sample_dir, f'include_sample_n{sample}_{i}.txt')
            with open(output_txt, 'w') as outfile:
                outfile.write("\n".join(selected_subjects))

if __name__ == "__main__":
    main()
