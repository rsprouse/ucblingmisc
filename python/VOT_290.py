#!/usr/bin/env python
'''VOT_290.py

VOT_290.py  - measure VOT in all of the stops in a given sound file (as
              found in files used by ling290 fall 2015).

Usage: VOT_290.py soundfile_name

Arguments:
  soundfile_name   a soundfile to be analyzed.
  
Assumption
    there is also a file soundfile_name.TextGrid that has a phone tier and a word tier
    
'''

# Authors: Keith Johnson (keithjohnson@berkeley.edu)
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

import os, sys
import subprocess
import audiolabel
import re
import math

#-----------------------------
# This script uses the following functions from the ESPS library for speech processing
#   - hditem: get information from a wav or fea file header
#   - fft: spectral analysis, producing a single spectrum or a spectrogram
#   - melspec: convert an fft spectrum into a "Mel transformed" auditory spectrum
#   - pplain: print values from fea files (spectra) to plain text

# Read about these and other ESPS routines in the Berkeley Phonetics Machine 
# using the 'man' command.   For example:
#       > man fft 
# will show the manual page for the fft routine
#-------------------------

w_score = [0.0,0.0,0.0]
s_score = [0.0,0.0,0.0]
w_time = [0.0,0.0,0.0]
s_time = [0.0,0.0,0.0]
step = 0.005  # 5 ms steps

def usage():
    print sys.exit(__doc__)

def polarity(d=[]):
    neg_peak = 0
    pos_peak = 0
    
    for i in range(len(d)):
        if d[i] < neg_peak:
            neg_peak = d[i]
        if d[i] > pos_peak:
            pos_peak = d[i]
    if -neg_peak > pos_peak:
        return -1
    else:
        return 1
        
def is_peak(i,j,k):
    return ((i<j) & (j>k))

def is_valley(i,j,k):
    return ((i>j) & (j<k))

def wave_burst(t,sf,pol, d=[]):
    global w_score
    w_score[:] = [0.0,0.0,0.0]
    global w_time
    w_time[:] = [0.0,0.0,0.0]
    
    for loc in range(t,len(d)-2):
        if ((pol>0 and is_peak(d[loc],d[loc+1],d[loc+2])) or 
            (pol<0 and is_valley(d[loc],d[loc+1],d[loc+2]))):
                ave=0
                for i in range(t,1,-1):
                    ave += math.fabs(d[loc-i] - d[loc-(i+1)])
                ave /= t
                change = math.fabs(d[loc]-d[loc+1])/ave
                for i in range(3):
                    if change > w_score[i]:
                        if (i<2):
                            w_score[2] = w_score[1]
                            w_time[2] = w_time[1]
                        if (i<1):
                            w_score[1] = w_score[0]
                            w_time[1] = w_time[0]
                        w_score[i] = change
                        w_time[i] = float(loc)/sf
                        break
                        
def spec_burst (s,e,sf,sd):
    w = sf*step
    
    global s_score 
    s_score[:] = [0,0,0]
    global s_time
    s_time[:] = [0,0,0]
    diff = []
    nyquist = sf/2
    
    ret=subprocess.call("fft -z -wHamming -l{} -S{} -r{}:{} {} temp1.fea".format(w,w,s,e,sd).split())            
    ret=subprocess.call("melspec -H300:{} -n60 temp1.fea temp2.fea".format(nyquist).split())
    ret=subprocess.call("nodiff -o1 -fre_spec_val temp2.fea nodiff.fea".split())  # spectral change
    diffstring = subprocess.check_output(["pplain","-fre_spec_val_d1","nodiff.fea"])
    lines = diffstring.rstrip().split('\n')    # break the string into separate values
    for l in lines:
        line = map(float,l.split())           # convert array from string to floating point number
        diff.append(sum(line))

    for loc in range(len(diff)):
        d = diff[loc]
        for i in range(3):
            if d > s_score[i]:
                if (i<2):
                    s_score[2] = s_score[1]
                    s_time[2] = s_score[1]
                if (i<1):
                    s_score[1] = s_score[0]
                    s_time[1] = s_time[0]
                s_score[i] = d
                s_time[i] = float(loc)*w/sf
                break

            
stops = re.compile("^(P|B|T|D|K|G)$")
vowels = re.compile(
         "^(?P<vowel>AA|AE|AH|AO|AW|AXR|AX|AY|EH|ER|EY|IH|IX|IY|OW|OY|UH|UW|UX)(?P<stress>\d)?$"
      )

try:
    soundfile = sys.argv[1]
except IndexError:
    usage()
    sys.exit(2)

tg = os.path.splitext(soundfile)[0]+'.TextGrid'  # expect a TextGrid file

try:
    pm = audiolabel.LabelManager(from_file=tg,from_type="praat")
except:
    usage()
    sys.exit(2)
    
f0name = os.path.splitext(soundfile)[0]+'.f0'  # expect a TextGrid file
if (not os.path.isfile(f0name)):  # create f0 file if it doesn't already exist
    ret = subprocess.call("get_f0 -i {} {} {}".format(step,soundfile, f0name).split())
    
sf=16000
ret=subprocess.call("sox {} temp.wav rate {}".format(soundfile,sf).split())            
ret=subprocess.call("wav2sd temp.wav".format(soundfile,sf).split())            
sd="temp.sd"

# find a vowel and measure the "polarity" of the waveform 
(vowel,match) = pm.tier('phone').search(vowels,  return_match=True)[0]
s_samp = int(vowel.t1*sf)
e_samp = int(vowel.t2*sf)
dstring = subprocess.check_output("pplain -i -r{}:{} {}".format(s_samp,e_samp,sd).split())
data = map(int,dstring.rstrip().split())

pol = polarity(data)   # determine the polarity of the waveform for wave_burst

t=int(step*sf)

# loop through all of the labels on the "phone" tier that match the set of stops
for phone in pm.tier('phone').search(stops):
    
    word = pm.tier('word').label_at(phone.center).text
    # step one in VOT measurement - find the location of the stop release burst
    start = phone.t1
    s_samp = int(start*sf)
    end = phone.t2
    e_samp = int(end*sf)
    
    dstring = subprocess.check_output("pplain -i -r{}:{} {}".format(s_samp,e_samp,sd).split())
    data = map(int,dstring.rstrip().split())

    wave_burst(t,sf,pol,data)
    spec_burst(s_samp,e_samp,sf,sd)
    
    cand = {}
    
    for w in range(3):
        for s in range(3):
            if math.fabs(w_time[w] - s_time[s]) < 0.004:
                cand[w]=s
    maxb = -2
    for (w,s) in cand.items():  
        # burst score - derived from lda over timit bursts
        b = -1.814 + 0.618*math.log(w_score[w]) + 0.003*s_score[s]
        if (b>maxb): 
            maxb = b
            loc = w_time[w] + start
            best = w
    
    burst_location = loc
    burst_frame = int(round(loc/step))
    start_frame = int(round(start/step))
    
    # step 2 find out when voicing starts relative to the burst
    # read in get_f0 data  -e2 is the voicing decision
    f0_string = subprocess.check_output("pplain -e2 {}".format(f0name).split())
    f0 = map(int,f0_string.rstrip().split())

    # search back from burst - is the closure voiceless?  no get neg VOT time and stop
    if (f0[burst_frame-1] == 1):
        i=1
        while ((burst_frame-i > start_frame) and f0[burst_frame-i]==1):
            i += 1
        VOT = -i*step
    # search forward from burst - report time of voice onset as positive VOT
    else:
        i=0
        while (f0[burst_frame+i]==0):
            i+=1
        VOT = i*step
        
    print("{} {} {} {}".format(soundfile,word,phone.text,str(VOT)))
