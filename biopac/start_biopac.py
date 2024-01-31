import socket
import sys
import time

# Make it so NDT packages available
sys.path.insert(1, 'C:/Program Files/BIOPAC Systems, Inc/AcqKnowledge 5.0/Network Data Transfer Examples/Python 3/source')

import biopacndt

'''
connects to Aqknowledge and then sets up Python server, waiting to connect to
e-prime socket. main() will run once the e-prime experiment begins
'''
# Connects to Acqknowledge server socket via NDT
# Positioned before socket creation because the function is a bit faulty and requires multiple tries
# but once the NDT connection has been made, everything else should go smoothly
acqServer = biopacndt.AcqNdtQuickConnect() # defines acqknowledge server
print('Connection with Acqknowledge server established')
print('----------------------------------------------------------------------')

# Python doesn't create its own server socket until after connection to Acqknowledge has been made
s = socket.socket()
print('Socket Created')

# s.bind((ipv4 address of computer python is running on, any 5 digits))
s.bind(('171.65.34.71',12345)) 
print('Socket bound to server IP and port')

s.listen(1) # listening for one client to connect to (E-prime client)
print('waiting for connections') 

# following lines doe not execute until e-prime experiment has started running
c, addr = s.accept()
print("Connected with", addr)
print('----------------------------------------------------------------------')

def main():
    '''
    function that does all the setup for the acqknowledge data collection, such as
    creating defining the folders, connecting to the various channels, creating
    data folders for each channel. BUT this function does not begin actually 
    receiving and processing data until data acquisition is triggered by e-prime
    and then by the MRI. When the trigger does occur, the MRI will begin data acqusition
    on the MP160 at which point the if statement under the While True loop will become true
    and start_exp() will run.
    '''
    
    if not acqServer:
        print("No AcqKnowledge servers found!")
        sys.exit()
    
    # check what type of MP device is being used by AcqKnowledge.
    # our example graph template uses higher indexed analog and
    # digital channels that are not available for MP36.
    if acqServer.getMPUnitType() != 160:
        print("MP160 not connected")
        return
        
    # Send a template to AcqKnowledge.  We will send the template file
    # 'var-sample-no-base-rate.gtl' within the "resources" subdirectory.
    # First construct a full path to this file on disk.
    
    # COPIED FROM MULTICONNECT:
    # change data connection method to multiple.  This means that 
    # AcqKnowledge will open up an individual TCP connection per
    # channel to transfer the data.
    # When in 'multiple' mode, we will need to construct one 
    # AcqNdtDataServer object for each channel being delivered.
    if acqServer.getDataConnectionMethod() != "multiple":
        acqServer.changeDataConnectionMethod("multiple")
        print("Data Connection Method Changed to: multiple")
        
    
    # instruct AcqKnowledge to send us data for all of the channels being
    # acquired and retain the array of enabled channel objects.
    global enabledChannels # makes enabledChannels a global variable so that it can be called in multiConnectToScreen
    enabledChannels = acqServer.DeliverAllEnabledChannels()
    
    # COPIED FROM MULTICONNECT:
    # construct our AcqNdtDataServer and channel recorder objects for each
    	# channel.  Since we're in multiple mode, we need one per channel.
    global dataServers
    dataServers = []
    
    for eCH in enabledChannels:
        # check which TCP port AcqKnowledge is using to send the data for
    		# the channel
        chPort = acqServer.GetDataConnectionPort(eCH)
    		
    		# construct the data server to receive the data for this channel
    		# from AcqKnowledge.  Note that the constructor takes a list of
    		# channels, so we need to make a single-item list with the
    		# channel object being received.
        channels = [eCH];
        dserver = biopacndt.AcqNdtDataServer(chPort, channels)
        
        # Only send dyno data to multiConnectToScreen
        ch_index = eCH.Index
        # fifth channel aka ch_index 4 is dynamometer
        if ch_index == 4 and eCH.Type == 'analog':
            # only dyno data gets sent to eprime via multiConnectToScreen function
            dserver.RegisterCallback("OutputToScreen", multiConnectToScreen)
             
		# start the data server.  The data server will start listening for
		# AcqKnowledge to make the data connection for this channel and
		# start processing the channel's data.
		#
		# All AcqNdtDataServers must be started prior to initiating our
		# data acquisition.
		#
		# Note that each data server is running on its own independent
		# preemptive thread, so delivery and processing of the data
		# for each individual channel is not directly synchronized with
		# the ohters.  If sample-index multiple channel synchronization
		# is required, it will need to be implemented manually or,
		# alternatively, use the 'single' connection mode and break
		# apart each individual frame.
        
        dserver.Start()
		
		# track our allocated data servers for post-acquisition cleanup
        dataServers.append(dserver)
       
        
    
    # equivalent of pressing the start button on Acqknowledge, but DOES NOT
    # start data acquisition until the trigger is sent by e-prime
    acqServer.toggleAcquisition()
    
    # pauses the code and constantly checks if acquisition is in process 
    # aka if Acqknowledge has been triggered by the MRI
    
    print('Patient is reading instructions. Data acquisition has not begun.')
    while True:
        if acqServer.getAcquisitionInProgress():
            start_exp()
            break
    return

def start_exp():  
        """
        actually begins receiving and processing data until data acquisition is complete
        then closes all servers
        """
        
        print('Participant has completed instructions and Acqknowledge data aqusition has been triggered.')
        
    	# wait for AcqKnowledge to finish acquiring all of the data in the graph.
        acqServer.WaitForAcquisitionEnd()
		
        
        # give ourselves an additional 15 seconds to process any data that
        # may have been sent at the end of the acquisition or is waiting
        # in our data server queue.
        time.sleep(30)
	
        # stop all of the channel data servers now that all of the transmitted
        # information has been processed
        for ds in dataServers:
            ds.Stop()
		
        # closes socket made to connect to e-prime so that the same port can be used again in next run
        s.close() 

def multiConnectToScreen(index, frame, channelsInSlice):
        """Callback for use with an AcqNdtDataServer to display incoming channel data in the console.
        
        index:  hardware sample index of the frame passed to the callback.
                        to convert to channel samples, divide by the SampleDivider out
                        of the channel structure.
        frame:  a tuple of doubles representing the amplitude of each channel
                        at the hardware sample position in index.  The index of the
                        amplitude in this tuple matches the index of the corresponding
                        AcqNdtChannel structure in channelsInSlice
        channelsInSlice:        a tuple of AcqNdtChannel objects indicating which
                        channels were acquired in this frame of data.  The amplitude
                        of the sample of the channel is at the corresponding location
                        in the frame tuple.
        """
        
        # NOTE:  'index' is set to a hardware acquisition sample index.  In
        # our sample data file, our acquisition sampling rate is 1kHz.
        #
        # Our sample data file uses variable sampling rates, and every
        # channel is downsampled.  The highest channel sampling rate is
        # only 500 Hz.  Therefore, every odd-indexed hardware sample position
        # does not contain any data!
        #
        # If the frame would be empty at a particular hardware index, the
        # callback does get invoked.  As a result, we won't see any odd
        # values of 'index' in our callback.
        
        # sending to eprime as an integer:
        # take the amplitude value from the frame tuple (it is a string i think?)
        val ='{:.4f}'.format(frame[0]) 
        
        
        # convert str into a float because can't convert decimal string directly into int??
        flt_val = float(val)*1000 # multiplying by 500 to capture more decimals for higher accuracy/granulation
        
        
        if flt_val >= 0:
            # convert float into int because e-prime is set up to receive int (int is needed in the )
            int_val = int(flt_val)
            
            # convert str into bytes because information must be sent as bytes when using NDT
            # make sure to set socke to bigendian
            byte_val = int_val.to_bytes(2, 'big')
            
            # send the byte version of the string to e-prime
            c.send(byte_val)
        
        # sometimes the force value goes slightly negative, in which case, the value should just = 0
        else:
            # inte_val set to 0
            int_val = 0
            
            # convert str into bytes because information must be sent as bytes when using NDT
            # make sure to set socke to bigendian
            byte_val = int_val.to_bytes(2, 'big')
            
            # send the byte version of the string to e-prime
            c.send(byte_val)
                    
        # debugging
        print("%s | %s" % (index, frame))

            
            

if __name__ == '__main__':
	main()




