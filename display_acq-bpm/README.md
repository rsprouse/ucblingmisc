display_acq-bpm
==============

This is a precompiled version of display_acq ready to be installed into the BPM.
It requires Matlab MCR 8.4 (for 2014b) to run.

Untar into /usr/local/bin to install.

It runs with:

  run_display_acq.sh /opt/matlab/2014b/v84/ acqname.mat

Where the first argument is the MCR root directory, and acqname.mat is a Matlab
file containing a daqsession acquisition object.
