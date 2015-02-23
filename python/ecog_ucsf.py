#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Quick-n-dirty loading of UCSF ecog data.
"""

# Authors: Ronald L. Sprouse (ronald@berkeley.edu)
# 
# Copyright (c) 2015, The Regents of the University of California
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the University of California nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

from __future__ import division
import numpy as np
import scipy.signal
import htkmfc
import os

def int2wavname(n):
    '''Convert an integer in the range 1 to 256 to the ECOG file naming
convention where channel 1 is '11' and Channel 256 is '464'.'''
    return "Wav{:d}{:d}.htk".format(
        int(np.ceil(n/64)),
        int(np.mod(n-1, 64) + 1)
    )

def get_bad_channels(ddir, subdir='Artifacts', fname='badChannels.txt'):
    '''Return an array of bad channel numbers in ddir.'''
    with open(os.path.join(ddir, subdir, fname)) as f:
        return [int(n) for n in f.readline().strip().split()]
    
def load_block(ddir, subdir):
    '''Load all the Wav*.htk channel data in a block subdir into an ndarray.
Return the data, sample rate, and bad channels.'''
    # Electrodes (channels) are numbered starting with 1.
    badchan = get_bad_channels(ddir)
    htk = htkmfc.open(os.path.join(ddir, subdir, int2wavname(1)))
    rate = htk.sampPeriod * 1E-3
    c1 = htk.getall()
    dc1 = scipy.signal(decimate, c1)
    cdata = np.empty((256, dc1.shape[0], dc1.shape[1])) * np.nan
    if 1 not in badchan:
        cdata[0,:,:] = dc1
    for idx in range(2, 257):
        if idx not in badchan:
            htk = htkmfc.open(os.path.join(ddir, subdir, int2wavname(idx)))
            cdata[idx-1,:,:] = scipy.signal.decimate(htk.getall(), 10)
    return (cdata, rate, badchan)
