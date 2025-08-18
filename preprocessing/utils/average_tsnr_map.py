#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Creates an avreage tSNR map from native space and an include list

import matplotlib.pyplot as plt
import pandas as pd
import argparse
import yaml
import numpy as np
import logging
import sys
import os
import glob
FNAME_LOG = 'log_stats.txt'

# Initialize logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)  # default: logging.DEBUG, logging.INFO
hdlr = logging.StreamHandler(sys.stdout)
logging.root.addHandler(hdlr)


def get_parser():
    parser = argparse.ArgumentParser(
        description="Path data_processed where the tSNR maps are stored.")
    parser.add_argument('-path-in', required=True, type=str,
                        help="Input .csv file with CSA computed perslice.")
    parser.add_argument('-include', required=False, type=str,
                        default='include.yml',
                        help="Path output results image.")
    parser.add_argument('-o', required=False, type=str,
                        default='csa.png',
                        help="Path output results image.")

    return parser


def main():

    args = get_parser().parse_args()
    # Get input arguments
    input_folder = os.path.abspath(args.path_in)
    include_file = os.path.abspath(args.include)
    output_folder = os.path.abspath(args.o)
    # Create output folder if does not exist.
    if not os.path.exists(output_folder):
        os.mkdir(output_folder)
    os.chdir(output_folder)

    # Dump log file there
    if os.path.exists(FNAME_LOG):
        os.remove(FNAME_LOG)
    fh = logging.FileHandler(os.path.join(FNAME_LOG))
    logging.root.addHandler(fh)
    # Create a list with subjects to exclude if input .yml config file is passed
    if args.include is not None:
        # Check if input yml file exists
        if os.path.isfile(args.include):
            fname_yml = args.include
        else:
            sys.exit("ERROR: Input yml file {} does not exist or path is wrong.".format(args.include))
        with open(fname_yml, 'r') as stream:
            try:
                include = list(yaml.safe_load(stream))
            except yaml.YAMLError as exc:
                logger.error(exc)
    else:
        include = []
    logger.info(include)

    # Find tSNR maps
    #tsnr_maps = glob.glob(os.path.join(input_folder, '*/*/*/*/*mc2_tsnr.nii.gz'))
   # logger.info("Found tSNR maps: {}".format(tsnr_maps))
    # Remove subjects not in include list
    if include:
        for sub in include:
            tsnr_maps = glob.glob(os.path.join(input_folder, sub, 'ses-spinalcord', 'func', 'run-*', '*mc2_tsnr.nii.gz'))
            logger.info("Found tSNR maps for {}: {}".format(sub, tsnr_maps))
            # Warp tSNR maps to PAM50 template space
            for tsnr_map in tsnr_maps:
if __name__ == "__main__":
    main()
