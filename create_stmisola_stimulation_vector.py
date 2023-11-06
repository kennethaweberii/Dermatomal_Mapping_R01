#!/usr/bin/env python
# -*- coding: utf-8

# For usage, type: python create_right_left_seg_mask.py -h

# Authors: Kenneth Weber

import argparse
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import square


def get_parser():
    parser = argparse.ArgumentParser(
        description="Create Create 1D stimulation vector for BIOPAC stmisola")
    parser.add_argument('-stim_f', required=True, type=int,
                        help="Stimulation frequency in Hz")
    parser.add_argument('-stim_pw', required=True, type=float,
                        help="Stimulation pulse width in seconds")
    parser.add_argument('-stim_duration', required=True, type=int,
                        help="Duration of stimulation block in seconds.")
    parser.add_argument('-stim_amp', required=True, type=float,
                        help="Amplitude of BIOPAC stim file in Volts.")
    parser.add_argument('-n_stim_blocks', required=True, type=int,
                        help="Number of stimulation blocks")
    parser.add_argument('-samp_f', required=True, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    parser.add_argument('-filename', required=True, type=str,
                        help="Filename of tab delimited stimulation vector file")
    return parser

def main():
    parser = get_parser()
    args = parser.parse_args()

    #Create vector of zeros length of stimulation experiment
    stim_vector = np.zeros((2*(args.n_stim_blocks)+1)*args.stim_duration*args.samp_f)

    #phase of stimulation wave default is 0
    phase=0

    #create time vector for stim_block
    time=np.arange(0,args.stim_duration, 1/args.samp_f)+phase


    #Raise erorr if pulse width is greater than sampling period
    if args.stim_pw/(1/args.stim_f) > 1:
        raise ValueError('Pulse width greater than sampling period. Reduce pulse width for this sampling frequency')
    
    #pw/1/sampling_f = duty cycle
    stim_block=args.stim_amp*(square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f))) 

    for block in np.arange(1, (args.n_stim_blocks*2)+1, 2):
        block_start=(block*args.samp_f*args.stim_duration)
        stim_vector[block_start:block_start+(args.stim_duration*args.samp_f)]=stim_block
    
    plt.plot(stim_vector)

    np.savetxt(args.filename, stim_vector, fmt='%.1f\n', newline='')

if __name__ == '__main__':
    main()