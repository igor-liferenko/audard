# py/pyext - python script objects for PD and MaxMSP

"""
http://grrrr.org/research/software/py/
* py loads Python modules and allows to execute functions therein.
* pyext uses Python classes to represent full-featured message objects.
* pym: object-oriented object... Python methods for any object type (readme.txt)
* (pyx?)

NOTE: even with detach (1 or 2), this's processSequenceList() script will cause clicks/interruptions of DSP audio in Pure Data! .pyo is autogenerated for the script... Maybe the clicks will be less if using [table] in PureData instead of [garray] (so they don't have to update the graphics in GUI...)
* In fact, by rendering to "extern"/temporary/scratch "clean" arrays ctvL, ctvR first, and then simply assigning the pyext.Buffers tvL, tvR to ctvL, ctvR (so that ammount of dirty()-ing, and possibly graphic re-rendering, is reduced) - audio clicks are *greatly* reduced; but not eliminated! also, besides clicks, running the processSequenceList() seems to slow PD's time down (try clicking quickly multiple times while playing, it will slow down...)


Note; print() - and sys.stdout.write() AND sys.stderr.write() - is redirected to PD console! AND it is truncated for long printouts;
"""

"""
  on "anything" in next to leftmost, inlet 2: expecting sequence string
  for each track: if track 1:
    set track from track fader volume (eventually)
    for each lane: for each step:
      if velo > 2, start mixing 16th note into the other buf (from curbuf)
      elseif 9 < velo <= 1, continue mixing 16th note into other buf
      else (velo == 0), stop/skip mixing
    if track 2: (will need pitching here too).
  NOTE: separate backbuffers for tracks (1 and 2) - since we want to mix them separately
  possibly (initiate) save newly mixed buffer to file (for screenshot)
  switch curbuf to newly rendered buf (if the two tracks are to be independent, we need two curbuf variables - but if they are re-rendered each time nonetheless, it doesn't matter if it's only one) - and output message
  ... or... for faster:
    for each step: for each lane: add samples accordingly, write into mix
"""

import sys
import os
#~ import pprint # dbg
#~ import inspect # dbg
#~ import Queue

print("Hello from seqaudiorender.py; initializing.")

try:
  import pyext
except:
  print("ERROR: This script must be loaded by the PD/Max py/pyext external")

try:
  # numpy is assumed here... numeric and numarray are considered deprecated
  import numpy as np # N
except:
  print("Failed importing numpy module:",sys.exc_value)

def isNumber(value):
  import types
  #~ if type(value) in (types.FloatType, types.IntType, types.LongType):
  if isinstance(value, (int, float, long)): # ok
  #~ if isinstance(value, int) or isinstance(value, float) or isinstance(value, double): # nowork
    return 1
  else:
    return 0

#################################################################

class SAR(pyext._class): # Seq. Audio Render
  """SAR (Seq. Audio Render): Class that performs sequence audio rendering, based on settings"""

  # number of inlets and outlets
  _inlets=3
    # 1 (second): sequence list
    # 2 (third):  sequence loop length in samples
    # 3 (fourth): bang on clear sequence
  _outlets=1
    # 1 (second): current buffer index

  # needed vars - don't prepend with self. here
  nSteps = 16
  nNotes = 5
  seqLoopLenSmps = 0
  seqLoopLenSmpsI = 0
  seq16thLenSmps = 0
  seq16thLenSmpsI = 0
  curbuf = 0 # 0: bbuf-1, 1: bbuf-2
  # bbufs[deck][track][chL/R+2*curbuf]
  bbufs = ( (("bbuf-1-1-1L", "bbuf-1-1-1R", "bbuf-1-1-2L", "bbuf-1-1-2R"),
            ("bbuf-1-2-1L", "bbuf-1-2-1R", "bbuf-1-2-2L", "bbuf-1-2-2R")),
            (("bbuf-2-1-1L", "bbuf-2-1-1R", "bbuf-2-1-2L", "bbuf-2-1-2R"),
            ("bbuf-2-2-1L", "bbuf-2-2-1R", "bbuf-2-2-2L", "bbuf-2-2-2R")) )
  fsout = None
  pifs = (2**(-2./12), 2**(-1./12), 2**0, 2**(1./12), 2**(2./12)) # pitch factors for track 2;
  deckid0 = 0 # deck id, 0-based - set from init args
  deckid1 = 1 # deck id, 1-based (deckid0+1) - set from init args
  #~ # threads advertise to this queue when they're waiting
  #~ wait_queue = Queue.Queue()
  #~ # threads get their task from this queue
  #~ task_queue = Queue.Queue()
  isSizing = False # a mutex
  isProcSequing = False
  lastSequence = None
  # sample fade in and out - 5 samples only doesn't have much effect?
  # actually, these need to be applied when a sample is cut at a step, not necessarily at the sample buffers! Even in that case (and using fade out only), 20 samples only still leaves clicks, 100 (2.26 ms) is OK (no clicks), 50 leaks a bit of a click; 80 is OK too...
  sFdIn = np.linspace(0, 1, 80)
  sFdOut = np.linspace(1, 0, 80)

  # constructor
  # now instantiate as [pyext seqaudiorender SAR 0 @detach 1], arg is deckid0
  def __init__(self,*args):
    if len(args) > 0:
      #print(type(args[0])) # <type 'int'>
      if isNumber(args[0]):
        self.deckid0 = int(args[0])
        self.deckid1 = self.deckid0+1
      else:
        print("SAR.__init__: Error - expected numeric first argument, got '{0}'".format(args[0]))
      if len(args) > 1:
        print("SAR.__init__: Warning - expected one argument, got {0}; ignoring the rest.".format(len(args)))
    self.fsout = open('/dev/stdout','w')
    if self._isthreaded:
      print("  Threading is on (possible)?!") # this prints even for @detach 0!
      #self._detach(1) # maybe start with detach=1, to guarantee that sizing finishes before running processing of sequence (with detach=2 they might run in parallel?) ; drop this
    # allow first thread to pass
    #~ self.task_queue.put("proceed")
    print("SAR.__init__ deckid0: {0}; ({1}; {2}; {3})".format(self.deckid0, args, len(args), self._isthreaded)) # if no arguments in PD [pyext ...] object box - args is empty tuple () ; also if [... @detach 1]

  def __del__(self):
    """Class destructor"""
    if self.fsout: self.fsout.close()

  # methods
  def wprint(self, input):
    if self.fsout: self.fsout.write(str(input) + "\n")

  # methods for first (actually, second) inlet

  #def _anything_1(self,*args):
  def list_1(self,*args):
    """  on "anything" in next to leftmost, inlet 2: expecting sequence string as list ;
    if _anything_1, receives the same tuple, regardless if the message has had a [prepend list] or not; still, keep the [prepend list] in PD;
    if list_1, args are the same as for _anything_1; but if without [prepend list] in PD, getting 'pyext - no matching method found for '00v' into inlet 1'
    so just in case, will go with list_1 """
    # args are like:  (<Symbol 00v>, 0, 0, 0, 0, 0, 2.759999990463257,
    #sys.stderr.write(" SAR:list_1: Some other message into first (actually, second) inlet: {0}\n".format(args))
    while (self.isSizing): time.sleep(0.001)
    self.isProcSequing = True
    #self.lastSequence = *args
    self.lastSequence = map(lambda x: str(x) if (isinstance(x, pyext.Symbol)) else x, args)
    self._isthreaded = True; self._detach(1) # detach/isthreaded does not matter here, really?
    self.processSequenceList() #(*args)
    self._isthreaded = False; self._detach(0)
    self.isProcSequing = False

 # methods for second (actually, third) inlet

  def float_2(self,f):
    """ receives seq. loop length in samples/frames; calcs 16th note lenght in samples/frames, and resizes backbuffer garray/tables/lists/buffers accordingly """
    self.ResizeGarrays(f)
    # since now we're using lastSequence; call processSequenceList (it will bail out early if lastSequence is none - to re-render the loop, and adjust the tempo to the new length
    self.processSequenceList()

 # methods for third (actually, fourth) inlet

  def bang_3(self):
    """ receives bang when sequence should be cleared/emptied """
    self.ClearGarrays()


  def ClearGarrays(self):
    # out here, we should clear the other backbuffers only, and then
    # like processSequenceList, set curbuf to otherbuf
    otherbuf = 1 if (self.curbuf == 0) else 0 # ternary
    tvbs = ( ( pyext.Buffer(self.bbufs[self.deckid0][0][2*otherbuf]),
              pyext.Buffer(self.bbufs[self.deckid0][0][2*otherbuf+1]) ),
             ( pyext.Buffer(self.bbufs[self.deckid0][1][2*otherbuf]),
              pyext.Buffer(self.bbufs[self.deckid0][1][2*otherbuf+1]) ) )
    if ( (tvbs[0][0]) and (tvbs[0][1]) and (tvbs[1][0]) and (tvbs[1][1]) ):
      for itrbufs in tvbs:
        for itbuf in itrbufs:
          itbuf[:] = np.zeros(self.seqLoopLenSmpsI, dtype=np.float32)
      self.curbuf = otherbuf # set other buf as current
      self._outlet(1,self.curbuf)
    else: # couldn't get tvL, tvR -  now (tvbs[0][0]) ..
      print(" SAR:ClearGarrays: Couldn't get garrays {0}, {1}, {2}, {3}".format(self.bbufs[self.deckid0][0][2*otherbuf], self.bbufs[self.deckid0][0][2*otherbuf+1], self.bbufs[self.deckid0][1][2*otherbuf], self.bbufs[self.deckid0][1][2*otherbuf+1]))


  def ResizeGarrays(self,f):
    """ receives seq. loop length in samples/frames; calcs 16th note lenght in samples/frames, and resizes backbuffer garray/tables/lists/buffers accordingly """
    self.seqLoopLenSmps = f
    self.seqLoopLenSmpsI = int(self.seqLoopLenSmps)
    self.seq16thLenSmps = self.seqLoopLenSmps/16.0
    self.seq16thLenSmpsI = int(self.seq16thLenSmps)
    #~ print(" SAR:float_2: got into second (actually, third) inlet: seqLoopLenSmps {0} seq16thLenSmps {1} /{2}".format(self.seqLoopLenSmps, self.seq16thLenSmpsI, self.curbuf))
    # bbufs[deck][track][chL/R+2*curbuf]
    # getting segfaults - try limit resizes only to otherbufs?
    otherbuf = 1 if (self.curbuf == 0) else 0 # ternary
    #~ tvL = pyext.Buffer(self.bbufs[self.deckid0][track][2*otherbuf])
    #~ tvR = pyext.Buffer(self.bbufs[self.deckid0][track][2*otherbuf+1])
    procnames = "" ; oldszs = "" ; newszs = "" ;
    for trackbufnms in self.bbufs[self.deckid0]:
      #~ for ibname in (trackbufnms[2*otherbuf], trackbufnms[2*otherbuf+1]): # only others, separate
      for ibname in trackbufnms: # all
        #~ print(ibname, trackbufnms)
        a = pyext.Buffer(ibname)
        #print(ibname, a, len(a)) # len works here
        oldlen = len(a)
        if (oldlen != self.seqLoopLenSmpsI):
          #~ print("Oldsize of {0}: {1} samples".format(ibname, oldlen))
          procnames += ibname+", "; oldszs += str(oldlen)+", ";
          # resize in buffer-2.pd: [py pyext.Buffer @py 1] -> [pym 2 resize @py 1]
          # readme.txt: Buffer.resize(frames,keep=1,zero=1) method
          a.resize(self.seqLoopLenSmpsI) #; a.dirty()
          #~ while(a.getdirty()): time.sleep(0.001) # was hack
          #~ print("  Newsize of {0}: {1} samples".format(ibname, len(a)))
          newszs += str(len(a))+", ";
    print("Resized garrays (%s): oldsize (%s) -> newsize (%s)"%(procnames, oldszs, newszs))

  def processSequenceList(self): #,*args):
    #sys.stderr.write(" SAR:processSequenceList: Some other message into first (actually, second) inlet: {0}\n".format(args))
    """   on "anything" in leftmost inlet 1: expecting sequence string
  for each track: if track 1:
    set track from track fader volume (eventually)
    for each lane: for each step:
      if velo > 2, start mixing 16th note into the other buf (from curbuf)
      elif 0 < velo <= 1, continue mixing 16th note into other buf
      else (velo == 0), stop/skip mixing
    if track 2: (will need pitching here too).
  possibly (initiate) save newly mixed buffer to file (for screenshot)
  swith curbuf to newly rendered buf - and output message
  ... or... for faster:
    for each step: for each lane: add samples accordingly, write into mix
    """
    # check first if lastSequence has been set; if not, do not perform and exit early - this definitely happens once at start, where first the arrays are sized, and only after does the first sequence come in
    if self.lastSequence is None:
      print("Have no sequence; bailing out")
      return
    #print(type(args[0]), type(args[0])==pyext.Symbol, isinstance(args[0], pyext.Symbol)) # ok
    # clean args: make Symbol into strings first - now above
    #cargs = map(lambda x: str(x) if (isinstance(x, pyext.Symbol)) else x, args)
    cargs = self.lastSequence
    #song = 1 # for now - no more, now have self.deckid0/1
    otherbuf = 1 if (self.curbuf == 0) else 0 # ternary
    # bbufs[deck][track][chL/R+2*curbuf]
    #~ itrack = 0 # for now
    # if the two bufs exist for track 0, presumably the ones for the other track also exist in the PD patch?
    #~ tvL = pyext.Buffer(self.bbufs[self.deckid0][itrack][2*otherbuf])
    #~ tvR = pyext.Buffer(self.bbufs[self.deckid0][itrack][2*otherbuf+1])
    # now going with all - make track "v?" buffers array, per-track:
    tvbs = ( ( pyext.Buffer(self.bbufs[self.deckid0][0][2*otherbuf]),
              pyext.Buffer(self.bbufs[self.deckid0][0][2*otherbuf+1]) ),
             ( pyext.Buffer(self.bbufs[self.deckid0][1][2*otherbuf]),
              pyext.Buffer(self.bbufs[self.deckid0][1][2*otherbuf+1]) ) )
    #~ if ( (tvL) and (tvR) ):
    if ( (tvbs[0][0]) and (tvbs[0][1]) and (tvbs[1][0]) and (tvbs[1][1]) ):

      # much less clicks if we off-render into ctvL, ctvR first - and then assing tvL, tvR in one go
      ctvL = np.zeros(self.seqLoopLenSmpsI, dtype=np.float32) ; ctvR = np.zeros(self.seqLoopLenSmpsI, dtype=np.float32) #, dtype=np.float32
      totarglen = len(cargs)
      alllaneslist = [] ; last_delim = 0
      for key, value in enumerate(cargs):
        if (value == "|"):
          # split off part here - use Python list splicing: if 2nd val is 4, then last included index is 3
          lanepart = cargs[last_delim:key] #{unpack(atoms, last_delim, key-1)}
          alllaneslist.append(lanepart) ; last_delim = key+1

      # this condition should always be satisfied due to the way Python .joins, but still:
      if (last_delim < totarglen):
        alllaneslist.append(cargs[last_delim:totarglen])
      #self.wprint(alllaneslist) # [(<Symbol 00v>, 0, 0, 0, 0,  ...

      # now loop through alllaneslist, separate per tracks (since different algos)
      pertracklist = [[], []]
      for key, tlanelist in enumerate(alllaneslist):
        tlabel = tlanelist[0]
        tlchars = list(tlabel) # split string to chars
        foundsndbufs = 0
        #self.wprint((tlabel, tlchars))
        trckind = int(tlchars[0]) # make 0-based, no +1 here
        tlind = int(tlchars[1])
        if trckind==0:
          sndtabnameL = "snd%d-%d-%dL"%(self.deckid1, trckind+1, tlind+1) # names are 1-based
          sndtabnameR = "snd%d-%d-%dR"%(self.deckid1, trckind+1, tlind+1)
        else: # trckind==1 (track 2): all same samples, but pitched
          sndtabnameL = "snd%d-2-1L"%(self.deckid1) ; sndtabnameR = "snd%d-2-1R"%(self.deckid1)
        sbL = pyext.Buffer(sndtabnameL)
        # note: if(sbL) check passes always, and has the right ('symbol', <Symbol snd1-2-1L>) property
        # only check for existence is len(sbL): 0; PD will allow you to set a table to len 0, but it will auto re-set it to 1 - so "real" len 0 is impossible
        if (len(sbL)==0): sbL = None
        else: foundsndbufs = foundsndbufs + 1 #
        sbR = pyext.Buffer(sndtabnameR)
        if (len(sbR)==0): sbR = None
        else: foundsndbufs = foundsndbufs + 1
        #if key == len(alllaneslist)-1:
        #  #self.wprint(inspect.getmembers(sbL)) # nothing much
        #  self.wprint("sbl len: {0}".format(len(sbL))) # nothing much
        # throw in tlchars, so we don't have to parse again; also find the sample buffers and add them
        pertracklist[trckind].append( (tlchars, tlanelist, foundsndbufs, (sbL, sbR) ) )
      #self.wprint(pprint.pformat(pertracklist))

      # do render: track 1 (itrack = 0)
      for itrack in (0,1):
        laststeplanevelos = []
        # reference for track 2 "pitched"-resized buffers of the sample (create on demand); unused for track 1
        tr2pbs = [None]*self.nNotes # [None, None, None, None, None]
        for i in xrange(0,self.nSteps): # 0-15
          lanevelos = []
          for tnote, tlanearr in enumerate(pertracklist[itrack]): # track 1
            if (tlanearr[2] == 2): # foundsndbufs
              ovel = tlanearr[1][2+i] # origvelo at this step; skip label and zero w [2+i]
              trig = 1 if (ovel >= 2) else 0 # working ternary
              nvel = ovel - 2*trig
              # if trig==1, start copying from sample buffer at 0; else continue from previous!
              soffs = -1 ;
              if (trig == 1): soffs = 0 # note started
              elif ((nvel > 0)): # note continues
                if len(laststeplanevelos)>0 and laststeplanevelos[tnote][1][2]>-1:
                  soffs = laststeplanevelos[tnote][1][2] + self.seq16thLenSmpsI # 0-based offset!
                  if (soffs > (len(tlanearr[3][0])-1)): soffs = -1 # offset bigger than sample length
              # end # if trig
              # NOTE: python .insert does NOT insert empty elements in list if they don't exist: z=[]; z.insert(3, -2) is [-2]! (so we might as well use append here)
              #~ lanevelos.insert( tnote, (trig, nvel, soffs)) # at position tnote
              lanevelos.append( (tnote, (trig, nvel, soffs)) ) # save position tnote
            #end # if foundsndbufs
          #end # for tnote, tlanearr
          # now do this snippet's sample mixing
          # (none of this sample by sample: ...
          """
          outind = -1
          for j in xrange(0,self.seq16thLenSmpsI):
            mixvalL, mixvalR = 0, 0
            for tnote, tinfarr in enumerate(lanevelos):
              if tinfarr[2]>-1: # soffs
                smpind = tinfarr[2]+j
                if smpind < len(pertracklist[0][tnote][3][0]): # one (sbL) check only: sbL and sbR should have same lengths
                  # note: vectorize this operation; leaving as reminder only
                  mixvalL = mixvalL + tinfarr[1]*pertracklist[0][tnote][3][0][smpind] # sbL
                  mixvalR = mixvalR + tinfarr[1]*pertracklist[0][tnote][3][1][smpind] # sbR
                #end # if smpind<
              #end # if tinfarr[3]>-1 # soffs
            #end # for tnote, tinfarr
            outind = i*self.seq16thLenSmpsI+j
                # ******
            #tvL:set(outind, mixvalL)
            #tvR:set(outind, mixvalR)
          #end # for j = 1,self.seq16thLenSmpsI
          """
          # ... vectorize instead for sample mixing):
          tmpbL = np.zeros(self.seq16thLenSmpsI) # length of self.seq16thLenSmpsI
          tmpbR = np.zeros(self.seq16thLenSmpsI)
          # NB: i is still numstep here;
          for tind, tinfarrfull in enumerate(lanevelos):
            #~ print(tinfarrfull) #
            tnote = tinfarrfull[0]
            tinfarr = tinfarrfull[1]
            if tinfarr[2]>-1: # soffs
              sbL = pertracklist[itrack][tnote][3][0] ; sbR = pertracklist[itrack][tnote][3][1] # should work for both itrack 0 and 1, in terms of direct sample buffers
              """
              if itrack == 1:
              # actually, don't pre-shift; some samples may be "insanely" long, pointless for them to wait to be pitched; instead, just find the right indexes for the stretched slice - and then stretch only the slice!?
                if (tr2pbs[tnote] is None):
                  # do "pitching" - resize with linear interpolation stretch
                  # tuck into tuple directly - a bit difficult to read:
                  tr2pbs[tnote] = ( \
                    np.interp(np.linspace(0,(len(sbL)-1)*self.pifs[tnote],len(sbL)*self.pifs[tnote])*(1.0/self.pifs[tnote]), np.linspace(0,len(sbL)-1,len(sbL)), sbL, left=0, right=0), \
                    np.interp(np.linspace(0,(len(sbR)-1)*self.pifs[tnote],len(sbR)*self.pifs[tnote])*(1.0/self.pifs[tnote]), np.linspace(0,len(sbR)-1,len(sbR)), sbR, left=0, right=0) \
                  )
                sbL = tr2pbs[tnote][0]; sbR = tr2pbs[tnote][1]
              # end # if itrack == 1:
              """
              sbLc = sbL ; sbRc = sbR # without fade in/out
              #~ sbLc = np.hstack((sbL[:self.sFdIn.size]*self.sFdIn, sbL[self.sFdIn.size:-self.sFdOut.size], sbL[-self.sFdOut.size:]*self.sFdOut)) ; sbRc = np.hstack((sbR[:self.sFdIn.size]*self.sFdIn, sbR[self.sFdIn.size:-self.sFdOut.size], sbR[-self.sFdOut.size:]*self.sFdOut)) # with fade in/out - but for the entire sample buffer; while we need these when the sequence is cut!
              sbLsz = len(sbLc) ; sbRsz = len(sbRc) # was len(sbL), len(sbR)
              sampind1 = tinfarr[2] ; sampind2 = tinfarr[2]+self.seq16thLenSmpsI
              # here sz because the slicing will do -1
              sampind2L = sbLsz if (sampind2 > sbLsz) else sampind2
              sampind2R = sbRsz if (sampind2 > sbRsz) else sampind2
              #self.wprint("  tL {0} tR {0} sL {1} sR {2}".format(len(tmpbL), len(tmpbR), sampind2L-sampind1, sampind2R-sampind1))
              # older numpy (1.5.1) doesn't have .pad ; so to avoid messing:
              # reinstantiate new zero temps, and slice the existing into them:
              slcL = np.zeros(self.seq16thLenSmpsI) ; slcR = np.zeros(self.seq16thLenSmpsI)
              tsbLc = sbLc[ sampind1:sampind2L ] ; tsbRc = sbRc[ sampind1:sampind2R ]
              if itrack == 1: # 16th slice-wise pitching:
                pf = self.pifs[tnote]; si1p, si2Lp, si2Rp, s16p = int(sampind1/pf), int(sampind2L/pf), int(sampind2R/pf), int(self.seq16thLenSmpsI/pf)
                # these take still too much time (more than with previous approach with pitched prerender)? (plus pitch was opposite when mult *pf); even if it should interpolate a slice only, it looks like it walks/stretches the entire source array, thereby consuming time?
                #~ tsbLc = np.interp( np.linspace(si1p, si2Lp, sampind2L-sampind1), np.linspace(0,len(sbLc)-1,len(sbLc)), sbLc, left=0, right=0 ) ; tsbRc = np.interp( np.linspace(si1p, si2Rp, sampind2R-sampind1), np.linspace(0,len(sbRc)-1,len(sbRc)), sbRc, left=0, right=0 )
                # try here to slice before interpolating - but using pitched indexes for the extracted ranges:
                """ # later - more accurate?
                ttLc = np.zeros(s16p) ; ttRc = np.zeros(s16p)
                print(ttLc.shape, si1p, si2Lp, si2Lp-si1p, s16p) # buffer has no shape (sbLc.shape); shape mismatch if si2Lp-si1p=7535, and s16p=7534
                ttLc[0:(si2Lp-si1p)] = sbLc[si1p:si2Lp] #; ttRc[0:(si2Rp-si1p)] = sbRc[si1p:si2Rp] # indices auto cast to integer? but gives "TypeError: sequence index must be integer, not 'slice'" -- which is fixed by int(); so must be explicitly int
                """
                # this "simple slice-only interpolation" also works (for some reason - can't see now how the indexes match) - generally well actually (except for bass, can hear some chops at 16th notes when its long) - but eventually probably better to make something like above, to also better handle edge cases
                ttLc = sbLc[si1p:si2Lp] ; ttRc = sbRc[si1p:si2Rp]
                LttLc = len(ttLc); LttRc = len(ttRc); # also sbLsz, sbRsz
                tsbLc = np.interp( np.linspace(0, si2Lp-si1p, sampind2L-sampind1), np.linspace(0,LttLc-1,LttLc), ttLc, left=0, right=0 ) ; tsbRc = np.interp( np.linspace(0, si2Rp-si1p, sampind2R-sampind1), np.linspace(0,LttRc-1,LttRc), ttRc, left=0, right=0 )
              # end # if itrack == 1:
              slcL[0:(sampind2L-sampind1)] = tsbLc ; slcR[0:(sampind2R-sampind1)] = tsbRc # was: sbL[], sbR[]
              # check fade out:
              nextvelo = pertracklist[0][tnote][1][i+1] if (i<self.nSteps-1) else 0
              if nextvelo==0:
                slcL = np.hstack((slcL[:-self.sFdOut.size], slcL[-self.sFdOut.size:]*self.sFdOut))
                slcR = np.hstack((slcR[:-self.sFdOut.size], slcR[-self.sFdOut.size:]*self.sFdOut))
              # final mix with fader factor:
              tmpbL += tinfarr[1]*slcL
              tmpbR += tinfarr[1]*slcR
          # end for tnote
          #self.wprint("  pre")
          tvind1 = i*self.seq16thLenSmpsI ; tvind2 = (i+1)*self.seq16thLenSmpsI
          # MUST cast explicitly to dtype=N.float32 when going to pyext.Buffer; else segfault!
          ctvL[tvind1:tvind2] = tmpbL[:] #np.array(tmpbL, dtype=np.float32)
          ctvR[tvind1:tvind2] = tmpbR[:] #np.array(tmpbR, dtype=np.float32)
          #self.wprint("  tvL,R {0} {1} {2}".format(tvind1, tvind2, tvind2-tvind1))
          laststeplanevelos = lanevelos
          # ends: [(0, 0, -1), (0, 0, -1)] 106680 113791 (same as lua)
          #self.wprint("{0} {1}".format(laststeplanevelos, i*self.seq16thLenSmpsI) )# , outind) )
        #end # for i = 1,self.nSteps
        # if "(no explicit assignment occurred);
        # must mark buffer content as dirty to update graph"
        # but here we do have explicit assignment - so dirty are not needed
        #tvL.dirty() ; tvR.dirty()
        tvL = tvbs[itrack][0] ; tvR = tvbs[itrack][1]
        tvL[:] = np.array(ctvL, dtype=np.float32)
        tvR[:] = np.array(ctvR, dtype=np.float32)
      #end # for itrack in (0,):
      # just before finishing, prepare messages for wav saving;
      # command for [soundfiler] - to which the send symbol
      # (rimage00, rimage10) for the rwav in Gripd is added
      #~ thisdir = os.path.dirname(os.path.realpath(__file__)) + os.sep # full path
      thisdir = "" # this works too, current dir
      # NOTE: -bytes 4 will use 32-bit float (it is not specifically for stereo)!
      # use -bytes 2 for 16-bit wav! (which can be correctly rendered by `wav2png` used by Gripd's image)
      msg1 = "write -wave -bytes 2 %sd%d-t1-bb%d.wav %s %s rimage0%d"%(thisdir, self.deckid0, otherbuf, self.bbufs[self.deckid0][0][2*otherbuf], self.bbufs[self.deckid0][0][2*otherbuf+1], self.deckid0)
      msg2 = "write -wave -bytes 2 %sd%d-t2-bb%d.wav %s %s rimage1%d"%(thisdir, self.deckid0, otherbuf, self.bbufs[self.deckid0][1][2*otherbuf], self.bbufs[self.deckid0][1][2*otherbuf+1], self.deckid0)
      sendname = "rwavsvc%d"%(self.deckid0)
      self._send(sendname, msg1) # like this it is symbol, use [fromsymbol] to work w unpack/[soundfiler]!
      self._send(sendname, msg2) #
      self.curbuf = otherbuf # set other buf as current
      self._outlet(1,self.curbuf)
    else: # couldn't get tvL, tvR -  now (tvbs[0][0]) ..
      print(" SAR:processSequenceList: Couldn't get garrays {0}, {1}, {2}, {3}".format(self.bbufs[self.deckid0][0][2*otherbuf], self.bbufs[self.deckid0][0][2*otherbuf+1], self.bbufs[self.deckid0][1][2*otherbuf], self.bbufs[self.deckid0][1][2*otherbuf+1]))

