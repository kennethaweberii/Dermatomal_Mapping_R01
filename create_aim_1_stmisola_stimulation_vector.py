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
        description="Create Create 1D stimulation vector for BIOPAC stmisola. To run type: create_aim_1_stmisola_stimulation_vector.py -stim_amp_low #.# -stim_amp_high #.# -subject_id sub-DMAim1HC###")
    parser.add_argument('-type', default='monophasic', required=False, type=str,
                        help="biphasic or monophasic")
    parser.add_argument('-stim_f', default=100, required=False, type=int,
                        help="Stimulation frequency in Hz")
    parser.add_argument('-stim_pw', default=0.00015, required=False, type=float,
                        help="Stimulation pulse width in seconds")
    parser.add_argument('-stim_duration', default=15, required=False, type=int,
                        help="Duration of stimulation block in seconds.")
    parser.add_argument('-no_stim_duration', default=15, required=False, type=int,
                    help="Duration of no stimulation block in seconds.")
    parser.add_argument('-stim_amp_low', required=True, type=float,
                        help="Amplitude of low stimulation in mA. For example: 0.2")
    parser.add_argument('-stim_amp_high', required=True, type=float,
                        help="Amplitude of high stimulation in mA. For example: 0.2")
    parser.add_argument('-n_stim_amps', default=5, required=False, type=int,
                        help="Number of stimulation amplitudes")
    parser.add_argument('-n_stim_blocks', default=10, required=False, type=int,
                        help="Number of stimulation blocks per stimulation amplitude")
    parser.add_argument('-samp_f', default=1000, required=False, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    parser.add_argument('-subject_id', required=True, type=str,
                        help="Subject_id For example: sub-DMAim1HC###")
    return parser

def main():
    parser = get_parser()
    args = parser.parse_args()

    #Create vector of amplitudes
    stim_amps = np.linspace(args.stim_amp_low,args.stim_amp_high,args.n_stim_amps)
    amps=np.empty(args.n_stim_amps*args.n_stim_blocks)

    for stim_block in np.arange(0,args.n_stim_blocks):
        print(stim_block)
        np.random.seed(stim_block)
        np.random.shuffle(stim_amps)
        amps[stim_block*args.n_stim_amps:stim_block*args.n_stim_amps+args.n_stim_amps] = stim_amps

    #Create vector of zeros length of stimulation experiment
    stim_vector = np.zeros( ((args.n_stim_amps*args.n_stim_blocks*args.stim_duration) + ((args.n_stim_amps*args.n_stim_blocks+1)*args.no_stim_duration)) *args.samp_f)

    #phase of stimulation wave default is 0
    phase=0

    #create time vector for stim_block
    time=np.arange(0,args.stim_duration, 1/args.samp_f)+phase

    #Raise erorr if pulse width is greater than sampling period
    if args.stim_pw/(1/args.stim_f) > 1:
        raise ValueError('Pulse width greater than sampling period. Reduce pulse width for this sampling frequency')
    
    stim_index=0
    for block in np.arange(1, (args.n_stim_amps*args.n_stim_blocks)+1):
        #pw/1/sampling_f = duty cycle
        if args.type.lower() == 'biphasic':
            stim_block=amps[block-1]*(square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f))) 
        elif args.type.lower() == 'monophasic':
            stim_block=amps[block-1]*((square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f)) + 1)/2)
        else:
            raise ValueError('Biphasic or monophasic not specified correctly.')

        block_start=(block*args.samp_f*args.no_stim_duration) + ((block-1)*args.samp_f*args.stim_duration)
        stim_vector[block_start:block_start+(args.stim_duration*args.samp_f)]=stim_block
        stim_index+=1

    plt.plot(np.arange(0,len(stim_vector)/args.samp_f, 1/args.samp_f), stim_vector, linewidth=0.01)
    plt.savefig(args.subject_id + '.pdf')

    np.savetxt(args.filename, stim_vector, fmt='%.1f\n', newline='')

if __name__ == '__main__':
    main()