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
    parser.add_argument('-type', default="monophasic", required=False, type=str,
                        help="biphasic or monophasic")
    parser.add_argument('-stim_f', default=100, required=False, type=int,
                        help="Stimulation frequency in Hz")
    parser.add_argument('-stim_pw', default=0.00015, required=False, type=float,
                        help="Stimulation pulse width in seconds")
    parser.add_argument('-stim_duration', default=5, required=False, type=int,
                        help="Duration of stimulation block in seconds.")
    parser.add_argument('-no_stim_duration', default=2, required=False, type=int,
                    help="Duration of no stimulation block in seconds.")
    parser.add_argument('-stim_amps', default='0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,2.0,2.1,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,3.0', required=False, type=str,
                        help="Comma separated amplitudes of BIOPAC stim file in Volts. For example: '0.2,0.4,0.6,0.8,1.0'")
    parser.add_argument('-samp_f', default=100000, required=False, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    return parser

def main():
    parser = get_parser()
    args = parser.parse_args()

    amps=args.stim_amps.split(',')

    n_stim_blocks=len(amps)

    #Create vector of zeros length of stimulation experiment
    stim_vector = np.zeros( ((n_stim_blocks*args.stim_duration) + ((n_stim_blocks+1)*args.no_stim_duration)) *args.samp_f)

    #phase of stimulation wave default is 0
    phase=0

    #create time vector for stim_block
    time=np.arange(0,args.stim_duration, 1/args.samp_f)+phase


    #Raise erorr if pulse width is greater than sampling period
    if args.stim_pw/(1/args.stim_f) > 1:
        raise ValueError('Pulse width greater than sampling period. Reduce pulse width for this sampling frequency')
    
    stim_index=0
    for block in np.arange(1, (n_stim_blocks)+1):
        #pw/1/sampling_f = duty cycle
        if args.type.lower() == 'biphasic':
            stim_block=float(amps[block-1])*(square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f))) 
        elif args.type.lower() == 'monophasic':
            stim_block=float(amps[block-1])*((square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f)) + 1)/2)
        else:
            raise ValueError('Biphasic or monophasic not specified correctly.')

        block_start=(block*args.samp_f*args.no_stim_duration) + ((block-1)*args.samp_f*args.stim_duration)
        stim_vector[block_start:block_start+(args.stim_duration*args.samp_f)]=stim_block
        stim_index+=1

    filename = args.type + '_stim_f_' + \
        str(args.stim_f) + 'hz_stim_pw_' + \
        str(args.stim_pw) + 's_stim_duration_' + \
        str(args.stim_duration) + 's_no_stim_duration_'+ \
        str(args.no_stim_duration)  + 's_samp_f_' + \
        str(args.samp_f) + 'hz'
   
    plt.plot(np.arange(0,len(stim_vector)/args.samp_f, 1/args.samp_f), stim_vector, linewidth=0.01)
    plt.savefig(filename + '.pdf')
    plt.close()

    np.savetxt(filename + '.tsv', stim_vector, fmt='%.1f\n', newline='')

if __name__ == '__main__':
    main()
    