example usage:

1. create a dedispersed time series with presto, 

     e.g. 'prepdata myobservation.fits -dm 500 -nobary -o topocentric_timeseries'

2. convert dedispersed time series .dat and .inf files to a einstein@home .binary, 

     e.g. 'presto2einstein ./topocentric_timeseries'

3. run the einstein@home client in standalone mode against the new topocentric_timeseries.binary 
   file -

     - download the einstein@home binary radio pulsar (BRP) stand alone client from 
       http://einstein.phys.uwm.edu/download/
        
        - The latest non-gpu linux client at the time of this writing was at:
          http://einstein.phys.uwm.edu/download/einsteinbinary_BRP4_1.22_i686-pc-linux-gnu__BRP4SSE
          
        - It's a little tricky to get the BOINC build to produce command line help, but it appears to 
          accept all the arguments none-the-less.  Here is the command line help, taken from the 
          demod_binary.c source:
          
Usage: <executable> [options], options are:"
-h, --help				boolean		Print this message
-i, --input_file		string		The name of the input file.
-o, --output_file		string		The name of the candidate output file.
-t, --template_bank		string		The name of the random template bank.
-c, --checkpoint_file	string		The name of the checkpoint file.
-l, --zaplist_file		string		The name of the zaplist file.
-f, --f0				float		The maximum signal frequency (in Hz)
-A, --false_alarm		float		False alarm probability.
-P, --padding			float		The frequency over-resolution factor.
-W, --whitening			boolean		Switch for power spectrum whitening and line zapping.
-B, --box				int			Window width for the running median in frequeny bins.
-D, --device			integer		The GPU device ID to be used.
-U, --username			string		Name of the BOINC user running the current instance.
-H, --host-cpid			int			Identifier of the BOINC host running the current instance.
-z, --debug				boolean		Run program in debug mode.


An example usage, taken from the source's Makefile test is:
	
einsteinBRP -t ./stochastic_full.bank -A 0.04 -P 3.0 -i ./topocentric_timeseries.binary  \
	-l ./zap.txt -c status -o results -z -W   
	
Results are output to 'results' in the cwd.


The three columns in the orbit template bank are:

P: 		orbital period of the binary in seconds
tau: 	lighttravel time for projected binary semi-major axis
Psi0: 	initial orbital phase
      
	
The columns in the output file are (I think):

f: 			frequency in Hz
P_b:		period of the binary in seconds
tau: 		light travel time for the projected semi-major axis
Psi: 		initial orbital phase
Power: 		signal strength in stddev
fA:    		false alarm probability in some unkown units
n_harm: 	number of harmonics summed

