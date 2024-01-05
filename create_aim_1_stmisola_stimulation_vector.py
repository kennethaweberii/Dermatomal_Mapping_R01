#!/usr/bin/env python
# -*- coding: utf-8

# For usage, type: python create_right_left_seg_mask.py -h

# Authors: Kenneth Weber

import os
import argparse
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import square
import tkinter as tk
from tkinter import simpledialog
from tkinter import filedialog

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
    parser.add_argument('-no_stim_duration', default=0, required=False, type=int,
                    help="Duration of no stimulation block in seconds.")
    parser.add_argument('-n_stim_amps', default=5, required=False, type=int,
                        help="Number of stimulation amplitudes")
    parser.add_argument('-n_stim_blocks', default=10, required=False, type=int,
                        help="Number of stimulation blocks per stimulation amplitude")
    parser.add_argument('-samp_f', default=100000, required=False, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    parser.add_argument('-filename', required=False, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    return parser

def main():
    parser = get_parser()
    args = parser.parse_args()
    
    #Get directory for saving
    root = tk.Tk()
    root.attributes('-topmost', True)
    root.tk.eval(f'tk::PlaceWindow {root._w} center')
    subject_id = simpledialog.askstring("Subject ID", "Enter subject ID (For example: sub-DMAim1HC000)")
    stim_amp_low = float(simpledialog.askstring("Stim Amp Low", "Enter Stim Amp Low to mA(For example: 0.1)"))
    stim_amp_high = float(simpledialog.askstring("Stim Amp High", "Enter Stim Amp High in mA (For example: 2.0)"))
    save_directory = filedialog.askdirectory()
    root.withdraw()
    
    #Raise error if stim_amp_high > 3.0
    if stim_amp_low > 3.0 or stim_amp_high > 3.0 or stim_amp_low < 0 or stim_amp_high < 0 or stim_amp_low > stim_amp_high or stim_amp_low == stim_amp_high:
        raise ValueError('Error with stim amp low or stim amp high.')
    
    os.makedirs(os.path.join(save_directory, subject_id), exist_ok=True)

    #Create vector of amplitudes
    stim_amps = np.linspace(stim_amp_low,stim_amp_high,args.n_stim_amps)
    amps=np.empty(((args.n_stim_amps+1)*args.n_stim_blocks)+1)

    rng = np.random.default_rng()

    for stim_block in np.arange(0,args.n_stim_blocks):
        np.random.seed(stim_block)
        amps[stim_block*(args.n_stim_amps+1):(stim_block*(args.n_stim_amps+1))+args.n_stim_amps+1] = np.concatenate([np.array([0]), rng.permutation(stim_amps)])

    #Create vector of zeros length of stimulation experiment
    stim_vector = np.zeros(((len(amps)*args.stim_duration)+((len(amps)-1)*args.no_stim_duration))*args.samp_f)
    fsl_stim_vector = np.zeros(((len(amps)*args.stim_duration)+((len(amps)-1)*args.no_stim_duration))*100) #Using 100 Hz sampling frequency for fsl vector
    

    #Phase of stimulation wave default is 0
    phase=0

    #create time vector for stim_block
    time=np.arange(0,args.stim_duration, 1/args.samp_f)+phase
    fsl_time=np.arange(0,args.stim_duration, 1/100)+phase #Using 100 Hz sampling frequency for fsl vector

    #Raise error if pulse width is greater than sampling period
    if args.stim_pw/(1/args.stim_f) > 1:
        raise ValueError('Pulse width greater than sampling period. Reduce pulse width for this sampling frequency')
    
    stim_index=0
    for block in np.arange(0, len(amps)):
        #pw/1/sampling_f = duty cycle
        if args.type.lower() == 'biphasic':
            stim_block=amps[block]*(square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f))) 
        elif args.type.lower() == 'monophasic':
            stim_block=amps[block]*((square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f)) + 1)/2)
        else:
            raise ValueError('Biphasic or monophasic not specified correctly.')
        
        
        block_start=((block*args.stim_duration) + (block*args.no_stim_duration))*args.samp_f
        stim_vector[block_start:block_start+(args.stim_duration*args.samp_f)]=stim_block
        
        fsl_stim_block=amps[block]*np.ones(len(fsl_time))
        fsl_block_start=((block*args.stim_duration) + (block*args.no_stim_duration))*100 #Using 100 Hz sampling frequency for fsl vector
        fsl_stim_vector[fsl_block_start:fsl_block_start+(args.stim_duration*100)]=fsl_stim_block #Using 100 Hz sampling frequency for fsl vector
        stim_index+=1
    
    try:
       filename
    except:
       filename = subject_id + '_' + \
          args.type + '_stim_f_' + \
          str(args.stim_f) + 'hz_stim_pw_' + \
          str(args.stim_pw) + 's_stim_duration_' + \
          str(args.stim_duration) + 's_no_stim_duration_'+ \
          str(args.no_stim_duration)  + 's_stim_amp_low_' + \
          str(stim_amp_low)  + 'ma_stim_amp_high_' + \
          str(stim_amp_high)  + 'ma_samp_f_' + \
          str(args.samp_f)  + 'hz'

    plt.plot(np.arange(0,len(stim_vector)/args.samp_f, 1/args.samp_f), stim_vector, linewidth=0.01)
    plt.savefig(os.path.join(save_directory, subject_id, filename + '_biopac_stim_vector.pdf'))
    plt.close()
    np.savetxt(os.path.join(save_directory, subject_id, filename + '_biopac_stim_vector.txt'), stim_vector, fmt='%.1f\n', newline='')

    for stim_amp in np.arange(1, len(stim_amps)+1):
        fsl_vector = np.concatenate([np.arange(0,len(fsl_stim_vector)/100, 1/100).reshape((-1, 1)), (np.ones(len(fsl_stim_vector))/100).reshape(-1, 1), ((fsl_stim_vector == stim_amps[stim_amp - 1])*1).reshape(-1, 1)], axis=1)

        plt.plot(np.arange(0,len(fsl_stim_vector)/100, 1/100), ((fsl_stim_vector == stim_amps[stim_amp - 1])*1), linewidth=0.01)  #Using 100 Hz sampling frequency for fsl vector
        plt.savefig(os.path.join(save_directory, subject_id, filename + '_stim_amp_' + str(stim_amp) + '.pdf'))
        plt.close()
        np.savetxt(os.path.join(save_directory, subject_id, filename + '_stim_amp_' + str(stim_amp) + '.txt'), fsl_vector, fmt='%.2f\t%.2f\t%d\n', newline='')
        
if __name__ == '__main__':
    main()
    
