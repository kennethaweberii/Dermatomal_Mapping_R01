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
import time

def get_parser():
    parser = argparse.ArgumentParser(
        description="Create Create 1D stimulation vector for BIOPAC stmisola. To run type: create_aim_1_stmisola_stimulation_vector.py -stim_amp_low #.# -stim_amp_high #.# -subject_id sub-DMAim1HC###")
    parser.add_argument('-type', default='monophasic', required=False, type=str,
                        help="biphasic or monophasic")
    parser.add_argument('-stim_f', default=100, required=False, type=int,
                        help="Stimulation frequency in Hz")
    parser.add_argument('-stim_pw', default=0.0002, required=False, type=float,
                        help="Stimulation pulse width in seconds")
    parser.add_argument('-stim_duration', default=15, required=False, type=int,
                        help="Duration of stimulation block in seconds.")
    parser.add_argument('-no_stim_duration', default=0, required=False, type=int,
                    help="Duration of no stimulation block in seconds.")
    parser.add_argument('-n_stim_amps', default=5, required=False, type=int,
                        help="Number of stimulation amplitudes")
    parser.add_argument('-n_stim_blocks', default=5, required=False, type=int,
                        help="Number of stimulation blocks per stimulation amplitude")
    parser.add_argument('-samp_f', default=5000, required=False, type=int,
                        help="Sampling frequency of stimulation vector in Hz")
    parser.add_argument('-filename', required=False, type=int,
                        help="Filename prefix of outputs")
    parser.add_argument('-save_directory', default=os.path.join('C:\\','Users','sdc','Documents','Users','Weber','Dermatomal_Mapping_R01','data'), required=False, type=str,
                        help="Default save directory")
    return parser

def main():
    parser = get_parser()
    args = parser.parse_args()
    
    #Get directory for saving
    root = tk.Tk()
    root.attributes('-topmost', True)
    root.tk.eval(f'tk::PlaceWindow {root._w} center')
    root.withdraw()
    subject_id = simpledialog.askstring("Subject ID", "Enter subject ID (For example: sub-DMAim1HC000)", initialvalue="sub-DMAim1")
    
    if os.path.isdir(args.save_directory):
        os.chdir(args.save_directory)
    else:
        args.save_directory = os.getcwd()
    args.save_directory = filedialog.askdirectory(initialdir=args.save_directory)
    
    stim_amp_low = float(simpledialog.askstring("Stim Amp Low", "Enter Stim Amp Low to mA(For example: 0.1)"))
    stim_amp_high = float(simpledialog.askstring("Stim Amp High", "Enter Stim Amp High in mA (For example: 2.0)"))
    
    #Raise error if stim_amp_high > 10.0
    if stim_amp_low > 10.0 or stim_amp_high > 10.0 or stim_amp_low < 0 or stim_amp_high < 0 or stim_amp_low > stim_amp_high or stim_amp_low == stim_amp_high:
        raise ValueError('Error with stim amp low or stim amp high.')
    
    os.makedirs(os.path.join(args.save_directory, subject_id), exist_ok=True)
    os.makedirs(os.path.join(args.save_directory, subject_id, 'fsl_stim_vectors'), exist_ok=True)

    #Create vector of amplitudes
    stim_amps = np.linspace(stim_amp_low,stim_amp_high,args.n_stim_amps)
    amps=np.empty(((args.n_stim_amps+1)*args.n_stim_blocks)+1)

    rng = np.random.RandomState()

    for stim_block in np.arange(0,args.n_stim_blocks):
        amps[stim_block*(args.n_stim_amps+1):(stim_block*(args.n_stim_amps+1))+args.n_stim_amps+1] = np.concatenate([np.array([0]), rng.permutation(stim_amps)])

    #Create vector of zeros length of stimulation experiment
    stim_vector = np.zeros(((len(amps)*args.stim_duration)+((len(amps)-1)*args.no_stim_duration))*args.samp_f)
    fsl_stim_vector = np.zeros(((len(amps)*args.stim_duration)+((len(amps)-1)*args.no_stim_duration))*100) #Using 100 Hz sampling frequency for fsl vector
    

    #Phase of stimulation wave default is 0
    phase=0

    #create time vector for stim_block
    #time=np.arange(0,args.stim_duration, 1/args.samp_f)+phase
    fsl_time=np.arange(0,args.stim_duration, 1/100)+phase #Using 100 Hz sampling frequency for fsl vector

    #Raise errors regarding pulse width
    if args.stim_pw/(1/args.stim_f) > 1:
        raise ValueError('Pulse width greater than sampling period. Reduce pulse width for this sampling frequency.')

    if args.stim_pw % (1/args.samp_f) != 0:
        raise ValueError('Pulse width needs to be multiple of sampling period. Adjust pulse width for this sampling frequency.')

    if (args.type.lower() == 'biphasic') & ((args.stim_pw * args.samp_f) % 2 != 0):
        raise ValueError('Duration of pulse width not possible with biphasic and current sampling frequency. Adjust pulse width or sampling frequency.')

    for block in np.arange(0, len(amps)):
        #pw/1/sampling_f = duty cycle
        if args.type.lower() == 'biphasic':
            #Noticed some interpolation erros with using square function, so rewrote not using square function
            #stim_block=float(amps[block])*(square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f))) 
            single_stim_block = np.zeros(int((1/args.stim_f)*args.samp_f))
            single_stim_block[:int(args.stim_pw/2*args.samp_f)] = 1
            single_stim_block[int(args.stim_pw/2*args.samp_f):int(args.stim_pw/2*args.samp_f)+int(args.stim_pw/2*args.samp_f)] = -1
            stim_block = float(amps[block])*np.tile(single_stim_block, args.stim_duration*args.stim_f)

        elif args.type.lower() == 'monophasic':
            #Noticed some interpolation erros with using square function, so rewrote not using square function
            #stim_block=float(amps[block])*((square((2 * np.pi * args.stim_f * time), args.stim_pw/(1/args.stim_f)) + 1)/2)
            single_stim_block = np.zeros(int((1/args.stim_f)*args.samp_f))
            single_stim_block[:int(args.stim_pw*args.samp_f)] = 1
            stim_block = float(amps[block])*np.tile(single_stim_block, args.stim_duration*args.stim_f)

        else:
            raise ValueError('Biphasic or monophasic not specified correctly.')
        
        block_start=((block*args.stim_duration) + (block*args.no_stim_duration))*args.samp_f
        stim_vector[block_start:block_start+(args.stim_duration*args.samp_f)]=stim_block
        
        fsl_stim_block=amps[block]*np.ones(len(fsl_time))
        fsl_block_start=((block*args.stim_duration) + (block*args.no_stim_duration))*100 #Using 100 Hz sampling frequency for fsl vector
        fsl_stim_vector[fsl_block_start:fsl_block_start+(args.stim_duration*100)]=fsl_stim_block #Using 100 Hz sampling frequency for fsl vector
    
    try:
       filename
    except:
       filename = args.type + '_f_' + \
          str(args.stim_f) + 'hz_pw_' + \
          str(args.stim_pw) + 's_stim_dur_' + \
          str(args.stim_duration) + 's_no_stim_dur_'+ \
          str(args.no_stim_duration)  + 's_low_' + \
          str(stim_amp_low)  + 'ma_high_' + \
          str(stim_amp_high)  + 'ma_samp_f_' + \
          str(args.samp_f)  + 'hz'

    #Change cwd to save directory because running into issues with long file name on some systems
    os.chdir(os.path.join(args.save_directory, subject_id))

    plt.plot(np.arange(0,len(stim_vector)/args.samp_f, 1/args.samp_f), stim_vector, linewidth=0.001)
    plt.xlabel("Seconds")
    plt.ylabel("mA")
    plt.savefig(subject_id + '_biopac_stim_vector_' + filename + '.pdf')
    plt.close()
    np.savetxt(subject_id + '_biopac_stim_vector_' + filename + '.txt', stim_vector, fmt='%.1f\n', newline='')

    #Change cwd to save directory because running into issues with long file name on some systems
    os.chdir(os.path.join(args.save_directory, subject_id, 'fsl_stim_vectors'))

    for stim_amp in np.arange(1, len(stim_amps)+1):
        fsl_vector = np.concatenate([np.arange(0,len(fsl_stim_vector)/100, 1/100).reshape((-1, 1)), (np.ones(len(fsl_stim_vector))/100).reshape(-1, 1), ((fsl_stim_vector == stim_amps[stim_amp - 1])*1).reshape(-1, 1)], axis=1)

        plt.plot(np.arange(0,len(fsl_stim_vector)/100, 1/100), ((fsl_stim_vector == stim_amps[stim_amp - 1])*1), linewidth=0.001)  #Using 100 Hz sampling frequency for fsl vector
        plt.xlabel("Seconds")
        plt.ylabel("AU")
        plt.savefig(subject_id + '_fsl_stim_vector_' + filename + '_stim_amp_' + str(stim_amp) + '.pdf')
        plt.close()
        np.savetxt(subject_id + '_fsl_stim_vector_' + filename + '_stim_amp_' + str(stim_amp) + '.txt', fsl_vector, fmt='%.2f\t%.2f\t%d\n', newline='')
        
        for stim_index in np.arange(1,len(np.where((fsl_vector[:,2][:-1]==0) & (fsl_vector[:,2][1:]==1))[0])+1):
            stim_starts = np.where((fsl_vector[:,2][:-1]==0) & (fsl_vector[:,2][1:]==1))[0] + 1
            stim_stops = np.where((fsl_vector[:,2][:-1]==1) & (fsl_vector[:,2][1:]==0))[0] + 1

            fsl_single_stim_vector = fsl_vector[:,2]*0
            fsl_single_stim_vector[stim_starts[stim_index-1]:stim_stops[stim_index-1]]=1

            fsl_single_stim_vector = np.concatenate([np.arange(0,len(fsl_stim_vector)/100, 1/100).reshape((-1, 1)), (np.ones(len(fsl_stim_vector))/100).reshape(-1, 1), fsl_single_stim_vector.reshape(-1, 1)], axis=1)

            plt.plot(np.arange(0,len(fsl_stim_vector)/100, 1/100), fsl_single_stim_vector[:,2], linewidth=0.001)  #Using 100 Hz sampling frequency for fsl vector
            plt.xlabel("Seconds")
            plt.ylabel("AU")
            plt.savefig(subject_id + '_fsl_stim_vector_' + filename + '_stim_amp_' + str(stim_amp) + '_stim_' + str(stim_index) + '.pdf')
            plt.close()
            np.savetxt(subject_id + '_fsl_stim_vector_' + filename + '_stim_amp_' + str(stim_amp) + '_stim_' + str(stim_index) + '.txt', fsl_single_stim_vector, fmt='%.2f\t%.2f\t%d\n', newline='')

if __name__ == '__main__':
    main()
    
