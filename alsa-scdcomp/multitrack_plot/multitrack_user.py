#!/usr/bin/env python
################################################################################
# multitrack_user.py                                                           #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# Sat Dec 14 00:22:15 CET 2013 ; Python 2.7.1+


print("importing")
# sys.path.append("/media/disk/work/AudioFPGA_git/driver_pc/snd_ftdi_audard-an16s/tests")
from multitrack_plot import *

# after the import, overload the setup data function for own plots;
# (overloading needs a separate function, was set_setupPlotData, now setGlobalFunc:)
#   http://stackoverflow.com/questions/2283210/python-function-pointer
#   http://stackoverflow.com/questions/4706879/global-variable-with-imports
#   http://stackoverflow.com/questions/20578942/overload-imported-function-that-uses-globals-in-python
# at the end main() is called (which is defined from the multitrack_plot import)


def setupPlotData():
  global data, status_txts, xgplots, indatfile, xmarkers
  global gps_preamble
  global zmxrange_history, zmxrange_current
  gps_preamble = '''set tics in border mirror;
  set grid xtics ytics front; # front affect the drawing order of the xtics, too
  set xtics offset 0,2; set ytics offset 2,0 left;
  set tmargin 0; set bmargin 0; set lmargin 0; set rmargin 0;
  #set lmargin at screen 0 ; set bmargin at screen 0 ; set rmargin at screen 0.99999 ; set tmargin at screen 0.99999 ;
  set autoscale xfix x2fix ykeepfix y2keepfix
  set x2tics format ""; set y2tics format "";
  set clip two
  #set key front # not documented, no complaints, but doesn't work (legend still under graph at times)
  '''

  if not(indatfile): # by default its ""
    #indatfile = "/media/disk/tmp/ftdi_prof/repztest.txt"
    #~ indatfile = "/media/disk/tmp/ftdi_prof/oldcapt01a/ftdiprof-2013-12-06-05-03-49_64/repz.txt"
    #~ indatfile = "/media/disk/tmp/ftdi_prof/oldcapt01/ftdiprof_first_256/repz.txt"
    indatfile = "/media/disk/tmp/ftdi_prof/ftdiprof-2014-01-03-12-08-57_64/repz.txt"
  print("User: Reading data from " + indatfile + "...")
  initStatusHist(indatfile)
  xgplots = []
  #np.setbufsize(1e7) # performance?
  indtype="float,float,int,int,int,int,int,int,int,int,int,int,int"
  innames=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt", "wrdlt", "wbps", "rbps"]
  hexconvertfunc = lambda x: int(x, 16)
  inconverters={"st0": hexconvertfunc, "st1": hexconvertfunc }
  pdata = NploadFromTxtCached(indatfile, indtype, innames, inconverters)
  data.orig_data_xrange = (0, np.max(pdata['ts']))
  print("orig_data_xrange", data.orig_data_xrange)

  print("ats1")
  ats1_wflds=['ts','tot','dlt','wbps']
  ats1=pdata[pdata['fid']==1][ats1_wflds] #[['ts','tot','dlt','wbps']]
  print("ats1 rearr")
  ats1=rearrangeNumpyArrFields(ats1, ats1_wflds)
  ats1.dtype.names = ('ts1','wtot1','wdlt1','wbps1') # now rename
  ats1dl = np.ediff1d( np.concatenate(([0.], ats1['ts1'] )) ) # timestamp 1 delta/diff
  ats1 = nprf.append_fields(ats1, names='ts1dl', data=ats1dl, dtypes=ats1.dtype['ts1'], usemask=False)

  print("ats2")
  ats2_wflds=['ts','tot','len','rbps', 'st1']
  ats2=pdata[pdata['fid']==2][ats2_wflds] #[['ts','tot','len','rbps', 'st1']]
  print("ats2 rearr")
  ats2=rearrangeNumpyArrFields(ats2, ats2_wflds)
  ats2.dtype.names = ('ts2','rtot2','rlen2','rbps2', 'st12')

  print("atsz")
  atsz=pdata[np.logical_or(pdata['fid']==1,pdata['fid']==2)][['ts','wrdlt']]
  atsz.dtype.names = ('tsz','wrdltz')
  # better to us fill_value = 0 here for out of bounds, because we need difference/subtraction?
  print "interp to atsz"
  wbpz, rbpz = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wbps1', ats2, 'ts2', 'rbps2', atsz, 'tsz')
  print "subtract"
  wrbpsz = np.subtract(wbpz['wbps1'], rbpz['rbps2']) # dtype/name is here lost
  print "atsz append_fields"
  atsz = nprf.append_fields(atsz, names='wrbpsz', data=wrbpsz, dtypes=wbpz.dtype['wbps1'], usemask=False)
  atsz = nprf.append_fields(atsz, names='wbpsz', data=wbpz['wbps1'], dtypes=wbpz.dtype['wbps1'], usemask=False)
  atsz = nprf.append_fields(atsz, names='rbpsz', data=rbpz['rbps2'], dtypes=rbpz.dtype['rbps2'], usemask=False)

  #
  # awk '{n=strtonum("0x" $6);if(and(rshift(n,1),1)){print;};}' repz.txt > rep2o.txt
  # overruns go to xmarkers
  print "atso2 - overruns"
  atso2 = ats2[ np.bitwise_and(np.right_shift(ats2['st12'],1), np.ones_like(ats2['st12'])).astype(bool) ]
  print(atso2)
  #
  #print np.unique( np.sort( np.ediff1d(np.concatenate(([0], ats2['ts2']))) ) )[::-1] # to find the max ts distance for threshold - sort descending (by sort, and reverse via [::-1]), also unique 'cause vals repeat (won't help w/ floats), (no print first X elements, as proper values could be later).
  # approx on diagram, the "long" period is about a ms; in the max ts distance printout, we see:
  # ...5.38000000e-04   4.25000000e-04  3.30000000e-04   1.00000000e-05 1.00000000e-05   9.00000000e-06 ..
  # so 0.33ms, 0.01ms, 9 us (!) .
  # at around 1ms, isn't drastic: 1.00100000e-03   1.00000000e-03 ... 9.99000000e-04... 9.98000000e-04
  # it also goes: 9.56000e-04   9.55000e-04, 8.39000e-04   7.24000e-04   6.77000e-04, 6.72000e-04 5.81000e-04
  # .. so going with 5.38000000e-04:
  ats2csrl = getNPsaPieceCumSum(ats2, 'ts2', 'rlen2', threshold=5.3e-4)
  ats2dl = np.ediff1d( np.concatenate(([0.], ats2csrl['ts2'] )) ) # timestamp 2 delta/diff
  ats2csrl = nprf.append_fields(ats2csrl, names='ts2dl', data=ats2dl, dtypes=ats2csrl.dtype['ts2'], usemask=False)
  ats2rcs = np.cumsum(ats2csrl['rlen2']) # recv. bytes cumulative sum (hopefully spikes are "filtered", but is still correct)
  ats2csrl = nprf.append_fields(ats2csrl, names='rcs', data=ats2rcs, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  # note: this ats2csrl now starts with 0.0!
  ats2rbcs = np.concatenate(([0.], ats2rcs[1:]/ats2csrl['ts2'][1:] )) # rbps via cumulative sum
  ats2csrl = nprf.append_fields(ats2csrl, names='rbcs', data=ats2rbcs, dtypes=ats2csrl.dtype['rlen2'], usemask=False)


  # {if($4==1){wrtot=$9;tsd=$1-tsp;tsdb=(tsd/ftpd)*bpw; ftqh=ftq-tsdb; ftqhb=bpw-tsdb; ftqhh= (ftqh<0)?0+bpw:( (ftqhb<0)?ftqh+bpw:ftq+ftqhb); ftq=ftqhh; tsp=$1;} if($4==2){rdtot=$9;} if(($4>0) && ($4<3)) {ts=$1;ots=$2; printf("%s %d %d %d %d\n",$0,int(wrtot)-int(rdtot), wrtot/$1, rdtot/$1, ftq); }}
  global bpw, fbps, ftpd, abps, apd, rbps_mean, rbps_med, rbps_rms, wbps_mean, wbps_med, wbps_rms
  bpw = ats1[0]['wtot1'] # bytes per write is also the first value in wtot1! (if we do it from start)
  fbps=200000; ftpd=float(bpw)/fbps;
  abps=44100*4; apd=float(bpw)/abps;
  #print( " ".join( get_namestr_vars('bpw', 'fbps', 'ftpd', 'abps', 'apd') ) ) # due to this "main" stuff, these cannot be seen as globals or locals...
  print( "wtfq " + ", ".join( [ix + ": " + str(globals()[ix]) for ix in ["bpw", "ftpd", "apd"]] ) ) # works with locals()[ix] when the vars aren't declared global
  ats2dlre = 176400*ats2dl # read_cs expected
  ats2csrl = nprf.append_fields(ats2csrl, names='ts2dlre', data=ats2dlre, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  # find where abs(ts2dlre - rlen2cs=ats2csrl.index('rlen2')) > 128?
  # happens before overrun, but not a predictor - happens many otherr times, too
  r2exdlt = np.subtract(ats2csrl['ts2dlre'], ats2csrl['rlen2']) # dtype/name is here lost
  ats2csrl = nprf.append_fields(ats2csrl, names='r2exdlt', data=r2exdlt, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  _ats2csrl = ats2csrl[ ats2csrl['r2exdlt']>128 ]
  print("_ats2csrl") ; print(_ats2csrl) ;

  # NOTE: rms is very sensitive to outliers - mean not as much:
  # m=np.array([20,40,20,40,20,40,20,40]) ; print np.mean(m), np.median(m), np.sqrt(np.mean(m**2))
  # 30.0 30.0 31.6227766017
  # m=np.array([20,40,20,40,200,40,20,40]) ; print np.mean(m), np.median(m), np.sqrt(np.mean(m**2))
  # 52.5 40.0 77.1362431027
  rbps_mean = np.mean(ats2['rbps2']) ; rbps_med = np.median(ats2['rbps2']); rbps_rms = np.sqrt(np.mean(ats2['rbps2']**2))
  wbps_mean = np.mean(ats1['wbps1']) ; wbps_med = np.median(ats1['wbps1']) ; wbps_rms = np.sqrt(np.mean(ats1['wbps1']**2))
  print( "     " + ", ".join( [ix + ": " + str(globals()[ix]) for ix in ["rbps_mean", "rbps_med", "rbps_rms", "wbps_mean", "wbps_med", "wbps_rms"]] ) ) # works with locals()[ix] when the vars aren't declared global
  # directly - without function here:
  print "wftq"
  tsd = np.ediff1d( np.concatenate(([0.], ats1['ts1'] )) )
  tsdb=(tsd/ftpd)*bpw
  ftqhh=np.empty(len(tsdb), dtype=tsdb.dtype); ftqhh.fill(bpw)
  for ix in xrange(0, len(ftqhh[:-1])):
    ftqhh[ix+1] = ( 0 if ftqhh[ix]-tsdb[ix+1]<0 else ftqhh[ix]-tsdb[ix+1] ) + bpw
  ats1 = nprf.append_fields(ats1, names='wftq1', data=ftqhh.astype(ats1.dtype['wtot1']), dtypes=ats1.dtype['wtot1'], usemask=False)

  # bpw:  [g] 64 fbps:  [g] 200000 ftpd:  [g] 0.00032 abps:  [g] 176400 apd:  [g] 0.000362811791383
  # (0.000413, 64)
  # (0.000759, 128)
  # 0.000413+0.000362811791383 = 0.000775812
  # (0.000413, 64)
  # (0.000776, 128)
  # y=ax+b; 64 = a*0.000413+b; 128 = a*0.000776+b;
  # 128-64 = a*(0.000776-0.000413) = a*0.000362811791383 => a=64/0.000362811791383 = 176400
  # b = 64-a*0.000413 = 64-176400*0.000413 = 64-72.8532 = -8.8532
  # 176400*0.000413 -8.8532 = 64
  # 176400*0.000776 -8.8532 = 128.033
  # 176400*0.000759 -8.8532 = 125.034
  # wrtot error in respect to ideal from first sample
  print "wtoe1"
  ka = abps; kb = bpw-ka*ats1[0]['ts1']
  wtoe1 = ats1['wtot1'] - (ka*ats1['ts1']+kb)
  ats1 = nprf.append_fields(ats1, names='wtoe1', data=wtoe1.astype(ats1.dtype['wtot1']), dtypes=ats1.dtype['wtot1'], usemask=False)
  print "rtoe2"
  ka = abps; kb = bpw-ka*ats2[0]['ts2']
  rtoe2 = ats2['rtot2'] - (ka*ats2['ts2']+kb)
  ats2 = nprf.append_fields(ats2, names='rtoe2', data=rtoe2.astype(ats2.dtype['rtot2']), dtypes=ats2.dtype['rtot2'], usemask=False)
  #~ ka = abps; kb = bpw-ka*ats2csrl[0]['ts2']
  #~ rtoe2 = ats2['rtot2'] - (ka*ats2['ts2']+kb)
  #~ ats2csrl = nprf.append_fields(ats2csrl, names='rtoe2', data=rtoe2.astype(ats2csrl.dtype['rlen2']), dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  print "interp to atsz"
  wtoez, rtoez = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wtoe1', ats2, 'ts2', 'rtoe2', atsz, 'tsz')
  print "subtract"
  wrtoez = np.subtract(wtoez['wtoe1'], rtoez['rtoe2']) # dtype/name is here lost
  print "atsz append_fields"
  atsz = nprf.append_fields(atsz, names='wrtoez', data=wrtoez, dtypes=wtoez.dtype['wtoe1'], usemask=False)

  print "wtoe1m"
  # median seems to give more "straight" output than mean here
  # (each respective - tm again makes it saw-ish)
  #t_m = np.mean(np.array([wbps_med, rbps_med]))
  # actually wr seems straightest for wbps_med vs. rbps_med-13 (-13 to -18) ?!
  # see extrafunc below - using it, can see straightest with (-13 to -14)!?
  # but zoomed at end, it looks like -16 is straightest?!
  ka = wbps_med; kb = bpw-ka*ats1[0]['ts1'] # wbps_mean wbps_med
  wtoe1m = ats1['wtot1'] - (ka*ats1['ts1']+kb)
  ats1 = nprf.append_fields(ats1, names='wtoe1m', data=wtoe1m.astype(ats1.dtype['wtot1']), dtypes=ats1.dtype['wtot1'], usemask=False)
  print "rtoe2m"
  ka = rbps_med; kb = bpw-ka*ats2[0]['ts2'] # rbps_mean rbps_med
  rtoe2m = ats2['rtot2'] - (ka*ats2['ts2']+kb)
  ats2 = nprf.append_fields(ats2, names='rtoe2m', data=rtoe2m.astype(ats2.dtype['rtot2']), dtypes=ats2.dtype['rtot2'], usemask=False)
  print "interp to atsz"
  wtoemz, rtoemz = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wtoe1m', ats2, 'ts2', 'rtoe2m', atsz, 'tsz')
  print "subtract"
  wrtoemz = np.subtract(wtoemz['wtoe1m'], rtoemz['rtoe2m']) # dtype/name is here lost
  print "atsz append_fields"
  atsz = nprf.append_fields(atsz, names='wrtoemz', data=wrtoemz, dtypes=wtoemz.dtype['wtoe1m'], usemask=False)
  print "rtoe2mm"
  ka = rbps_med-16; kb = bpw-ka*ats2[0]['ts2'] # rbps_mean rbps_med
  rtoe2mm = ats2['rtot2'] - (ka*ats2['ts2']+kb)
  ats2 = nprf.append_fields(ats2, names='rtoe2mm', data=rtoe2mm.astype(ats2.dtype['rtot2']), dtypes=ats2.dtype['rtot2'], usemask=False)
  print "interp to atsz"
  wtoemz, rtoemmz = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wtoe1m', ats2, 'ts2', 'rtoe2mm', atsz, 'tsz')
  print "subtract"
  wrtoemmz = np.subtract(wtoemz['wtoe1m'], rtoemmz['rtoe2mm']) # dtype/name is here lost
  print "atsz append_fields"
  atsz = nprf.append_fields(atsz, names='wrtoemmz', data=wrtoemmz, dtypes=wtoemz.dtype['wtoe1m'], usemask=False)
  print "resample wrdltz to wrdlt2cs"
  # use in1d to search (for timestamps in tz that match t2) => so to resample accordingly
  #print pformat(np.in1d(atsz['tsz'],ats2csrl['ts2'])[:25])
  # note: here [['wrdltz']] causes "ValueError: setting an array element with a sequence." and it keeps the column info; use ['wrdltz'] - then column info is lost, and we have 1d array
  #~ wrdlt2cs = atsz[np.nonzero(np.in1d(atsz['tsz'],ats2csrl['ts2']))[0]]['wrdltz']
  # must concatenate inital zero too for correct, ats2csrl has it, but atsz doesn't
  wrdlt2cs = np.concatenate(([0], atsz[np.in1d(atsz['tsz'],ats2csrl['ts2'])]['wrdltz'] ))
  ats2csrl = nprf.append_fields(ats2csrl, names='wrdlt2cs', data=wrdlt2cs, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  # just one np.concatenate here:
  wrdlt2csd = np.ediff1d(np.concatenate(([0], wrdlt2cs)))
  ats2csrl = nprf.append_fields(ats2csrl, names='wrdlt2csd', data=wrdlt2csd, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  # note, for the print below, must use view [[]], cannot index two+ record columns with just a single-bracket index
  #print pformat(atsz[['tsz','wrdltz']][:25]), "\n", pformat(ats2csrl[['ts2','wrdlt2cs']][:25]) #pformat(wrdlt2cs[:25])
  #~ tcheck = ats2csrl[np.nonzero(ats2csrl['wrdlt2cs'] > 288)][['ts2','wrdlt2cs']]
  #~ print len(tcheck), pformat(tcheck)
  #~ tcheck = ats2csrl[np.nonzero(ats2csrl['wrdlt2cs'] > 352)][['ts2','wrdlt2cs']]
  #~ print len(tcheck), pformat(tcheck)
  #~ tcheck = ats2csrl[np.nonzero(ats2csrl['wrdlt2cs'] > 416)][['ts2','wrdlt2cs']]
  #~ print len(tcheck), pformat(tcheck)
  # threshold via atso2
  #atso2thr = 256+bpw/2+bpw*np.arange(0, len(atso2), 1)
  #atso2 = nprf.append_fields(atso2, names='atso2thr', data=atso2thr, dtypes=ats2csrl.dtype['rlen2'], usemask=False)
  #print len(atso2), pformat(atso2)
  # we must have the zero and the last element for proper rendering;
  # add directly to a new "plain" array here, use it for direct assign to xnuplot
  # NOTE: here the last element ats2['ts2'][-1] is a scalar, and it MUST be wrapped in [], else the np.concatenate failes!
  atso2thr = np.ndarray((len(atso2)+2,2), dtype = object)
  #print pformat(atso2['ts2']), pformat(ats2['ts2'][-1])
  atso2thr[:,0] = np.array( np.concatenate( ( [0.], atso2['ts2'], [ats2['ts2'][-1]] ) ) )
  atso2thr[:,1] = 256+bpw/2+bpw*np.concatenate(( np.arange(0, len(atso2)+1, 1), [len(atso2)] ))
  #~ print pformat(atso2thr)


  data.structured = [ ats1, ats2, atsz, ats2csrl, atso2 ]  # mere reference
  # have to do this because "array for Gnuplot array/record must have ndim >= 2",
  # this seems to be the only way to reshape and preserve datatype:
  print "aats 1,2,z"
  aats1 = np.ndarray((ats1.shape[0],len(ats1.dtype)), dtype = object) #aa[:,0] = a['x']
  for ix, ins in enumerate(ats1.dtype.names): # also get a count iterator
    aats1[:,ix] = ats1[ins]
  aats2 = np.ndarray((ats2.shape[0],len(ats2.dtype)), dtype = object)
  for ix, ins in enumerate(ats2.dtype.names):
    aats2[:,ix] = ats2[ins]
  aatsz = np.ndarray((atsz.shape[0],len(atsz.dtype)), dtype = object)
  for ix, ins in enumerate(atsz.dtype.names):
    aatsz[:,ix] = atsz[ins]
  aats2csrl = np.ndarray((ats2csrl.shape[0],len(ats2csrl.dtype)), dtype = object)
  for ix, ins in enumerate(ats2csrl.dtype.names):
    aats2csrl[:,ix] = ats2csrl[ins]
  #~ aatso2 = np.ndarray((atso2.shape[0],len(atso2.dtype)), dtype = object)
  #~ for ix, ins in enumerate(atso2.dtype.names):
    #~ aatso2[:,ix] = atso2[ins]
  data.plotformat = [ aats1, aats2, aatsz, aats2csrl ]#, aatso2 ]  # mere reference

  # ---
  print "prep xgplot1"
  xgplot1=getPrepXgplot()
  xgplot1.myxrange = data.orig_data_xrange # add as new attribute
  xgplot1.origyrange = "set yrange [176400:176700]" # use [*:*] for auto
  xgplot1.myyrange = xgplot1.origyrange
  xgplot1(xgplot1.myyrange)
  xgplot1("set xrange [{0}:{1}]".format(xgplot1.myxrange[0], xgplot1.myxrange[1]))
  xgplot1.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
    options="t'wbps1 (mn %.1f|%d, md %.1f|%d, rm %.1f)' with steps lc rgb 'red'" % (wbps_mean, wbps_mean-abps, wbps_med, wbps_med-abps, wbps_rms)
  ))
  #~ xgplot1.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
    #~ options="t'' with points lc rgb 'red' pt 7"
  #~ ))
  xgplot1.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
    options="t'rbps2 (mn %.1f|%d, md %.1f|%d, rm %.1f)' with steps lc rgb 'blue'" % (rbps_mean, rbps_mean-abps, rbps_med, rbps_med-abps, rbps_rms)
  ))
  #~ xgplot1.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
    #~ options="t'' with points lc rgb 'blue' pt 7"
  #~ ))
  xgplots.append(xgplot1) ###

  print "prep xgplot1a"
  xgplot1a=getPrepXgplot()
  xgplot1a.myxrange = data.orig_data_xrange # add as new attribute
  xgplot1a.origyrange = "set yrange [165000:178000]" # use [*:*] for auto; [171500:174500]
  xgplot1a.myyrange = xgplot1a.origyrange
  xgplot1a(xgplot1a.myyrange)
  xgplot1a("set xrange [{0}:{1}]".format(xgplot1a.myxrange[0], xgplot1a.myxrange[1]))
  xgplot1a.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('rbcs')), # ts2(cs)/rbps2(cs)
    options="t'rbps2cs' with steps lc rgb 'dark-blue'"
  ))
  xgplot1a.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('rbcs')), # ts2(cs)/rbps2(cs)
    options="t'' with points lc rgb 'dark-blue' pt 1"
  ))
  xgplots.append(xgplot1a) ###

  print "prep xgplot2"
  xgplot2=getPrepXgplot()
  xgplot2.myxrange = data.orig_data_xrange # add as new attribute
  xgplot2.origyrange = "set yrange [0:150]"
  xgplot2.myyrange = xgplot2.origyrange
  xgplot2(xgplot2.myyrange)
  xgplot2("set xrange [{0}:{1}]".format(xgplot2.myxrange[0], xgplot2.myxrange[1]))
  xgplot2.append(xnuplot.record( aatsz, using=(0, 2), # tsz/wrbpsz
    options="t'wrbpsz' with steps lc rgb 'purple'"
  ))
  #~ xgplot2.append(xnuplot.record( aatsz, using=(0, 2), # tsz/wrbpsz
    #~ options="t'' with points lc rgb 'purple' pt 7"
  #~ )) # wrtoez
  xgplots.append(xgplot2) ###

  print "prep xgplot3"
  xgplot3=getPrepXgplot()
  xgplot3.myxrange = data.orig_data_xrange # add as new attribute
  xgplot3.origyrange = "set yrange [0:1200]"
  xgplot3.myyrange = xgplot3.origyrange
  xgplot3(xgplot3.myyrange)
  xgplot3("set xrange [{0}:{1}]".format(xgplot3.myxrange[0], xgplot3.myxrange[1]))
  xgplot3.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrdltz')), # tsz/wrdltz
    options="t'wrdltz' with steps lc rgb 'violet'"
  ))
  #~ xgplot3.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrdltz')), # tsz/wrdltz
    #~ options="t'' with points lc rgb 'violet' pt 1"
  #~ ))
  xgplot3.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('wrdlt2cs')), # tsz/wrdltz
    options="t'wrdlt2cs' with steps lc rgb 'purple'"
  ))
  xgplot3.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('wrdlt2csd')), # ts2sc/wrdlt2csd
    options="t'wrdlt2csd' with steps lc rgb 'dark-violet'"
  )) #
  # instead of adding zero point, use fsteps here instead? doesn't look good.. add zero point anyway
  xgplot3.append(xnuplot.record( atso2thr, using=(0, 1), # ts2o/thresh
    options="t'atso2thr' with steps lc rgb 'green'"
  )) #
  xgplots.append(xgplot3) ###

  print "prep xgplot4"
  xgplot4=getPrepXgplot()
  xgplot4.myxrange = data.orig_data_xrange # add as new attribute
  xgplot4.origyrange = "set yrange [0:2000]"
  xgplot4.myyrange = xgplot4.origyrange
  xgplot4(xgplot4.myyrange)
  xgplot4("set xrange [{0}:{1}]".format(xgplot4.myxrange[0], xgplot4.myxrange[1]))
  xgplot4.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wdlt1')), # ts1/wdlt1
    options="t'wdlt1' with steps lc rgb 'red'"
  ))
  xgplot4.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wdlt1')), # ts1/wdlt1
    options="t'' with points lc rgb 'red' pt 1"
  ))
  xgplots.append(xgplot4) ###

  print "prep xgplot5"
  xgplot5=getPrepXgplot()
  xgplot5.myxrange = data.orig_data_xrange # add as new attribute
  xgplot5.origyrange = "set yrange [0:80]"
  xgplot5.myyrange = xgplot5.origyrange
  xgplot5(xgplot5.myyrange)
  xgplot5("set xrange [{0}:{1}]".format(xgplot5.myxrange[0], xgplot5.myxrange[1]))
  xgplot5.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rlen2')), # ts2/rlen2
    options="t'rlen2' with steps lc rgb 'blue'"
  ))
  xgplot5.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rlen2')), # ts2/rlen2
    options="t'' with points lc rgb 'blue' pt 1"
  ))
  xgplots.append(xgplot5) ###

  print "prep xgplot6" # ats2csrl
  xgplot6=getPrepXgplot()
  xgplot6.myxrange = data.orig_data_xrange # add as new attribute
  xgplot6.origyrange = "set yrange [0:550]"
  xgplot6.myyrange = xgplot6.origyrange
  xgplot6(xgplot6.myyrange)
  xgplot6("set xrange [{0}:{1}]".format(xgplot6.myxrange[0], xgplot6.myxrange[1]))
  xgplot6.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('rlen2')), # ts2/rlen2 (cs)
    options="t'rlen2cs' with steps lc rgb 'blue'"
  ))
  xgplot6.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('rlen2')), # ts2/rlen2 (cs)
    options="t'' with points lc rgb 'blue' pt 1"
  ))
  xgplot6.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wftq1')), # ts1/wftq1
    options="t'wftq1' with steps lc rgb 'red'"
  ))
  xgplot6.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wftq1')), # ts1/wftq1
    options="t'' with points lc rgb 'red' pt 1"
  ))
  xgplot6.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('ts2dlre')), # ts2cs/read_expected
    options="t'ts2dlre' with points lc rgb 'dark-blue' pt 1"
  ))
  xgplots.append(xgplot6) ###

  print "prep xgplot7" # ats2csrl
  xgplot7=getPrepXgplot()
  xgplot7.myxrange = data.orig_data_xrange # add as new attribute
  xgplot7.origyrange = "set yrange [0:0.0045]"
  xgplot7.myyrange = xgplot7.origyrange
  xgplot7(xgplot7.myyrange)
  xgplot7("set xrange [{0}:{1}]".format(xgplot7.myxrange[0], xgplot7.myxrange[1]))
  xgplot7.append(xnuplot.record( aats2csrl, using=(0, ats2csrl.dtype.names.index('ts2dl')), # ts2/ts2dl (cs)
    options="t'ts2csdl' with impulses lc rgb 'blue'"
  ))
  xgplot7.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('ts1dl')), # ts1/ts1dl
    options="t'ts1dl' with impulses lc rgb 'red'"
  ))
  xgplots.append(xgplot7) ###

  print "prep xgplot8"
  xgplot8=getPrepXgplot()
  xgplot8.myxrange = data.orig_data_xrange # add as new attribute
  xgplot8.origyrange = "set yrange [0:*]"
  xgplot8.myyrange = xgplot8.origyrange
  xgplot8(xgplot8.myyrange)
  xgplot8("set xrange [{0}:{1}]".format(xgplot8.myxrange[0], xgplot8.myxrange[1]))
  xgplot8.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1')), # ts1/wtoe1
    options="t'wtoe1 (wtot-abps*t1)' with steps lc rgb 'red'"
  ))
  xgplot8.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1')), # ts1/wtoe1
    options="t'' with points lc rgb 'red' pt 1"
  ))
  xgplot8.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2')), # ts2/rtoe2
    options="t'rtoe2 (rtot-abps*t2)' with steps lc rgb 'blue'"
  ))
  xgplot8.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2')), # ts2/rtoe2
    options="t'' with points lc rgb 'blue' pt 1"
  ))
  xgplots.append(xgplot8) ###

#~ >   print "prep xgplot9"
#~ >   xgplot9=getPrepXgplot()
#~ >   xgplot9.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot9.origyrange = "set yrange [-300:600]"
#~ >   xgplot9.myyrange = xgplot9.origyrange
#~ >   xgplot9(xgplot9.myyrange)
#~ >   xgplot9("set xrange [{0}:{1}]".format(xgplot9.myxrange[0], xgplot9.myxrange[1]))
#~ >   xgplot9.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrtoez')), # tsz/wrtoez
#~ >     options="t'wrtoez' with steps lc rgb 'violet'"
#~ >   ))
#~ >   xgplots.append(xgplot9) ###
#~ >
#~ >   print "prep xgplot10"
#~ >   xgplot10=getPrepXgplot()
#~ >   xgplot10.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot10.origyrange = "set yrange [-300:1000]"
#~ >   xgplot10.myyrange = xgplot10.origyrange
#~ >   xgplot10(xgplot10.myyrange)
#~ >   xgplot10("set xrange [{0}:{1}]".format(xgplot10.myxrange[0], xgplot10.myxrange[1]))
#~ >   xgplot10.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1m')), # ts1/wtoe1m
#~ >     options="t'wtoe1m (wtot-mw*t1)' with steps lc rgb 'red'"
#~ >   ))
#~ >   #~ xgplot10.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1m')), # ts1/wtoe1m
#~ >     #~ options="t'' with points lc rgb 'red' pt 1"
#~ >   #~ ))
#~ >   xgplot10.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2m')), # ts2/rtoe2m
#~ >     options="t'rtoe2m (rtot-mr*t2)' with steps lc rgb 'blue'"
#~ >   ))
#~ >   #~ xgplot10.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2m')), # ts2/rtoe2m
#~ >     #~ options="t'' with points lc rgb 'blue' pt 1"
#~ >   #~ ))
#~ >   xgplots.append(xgplot10) ###
#~ >
#~ >   print "prep xgplot11"
#~ >   xgplot11=getPrepXgplot()
#~ >   xgplot11.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot11.origyrange = "set yrange [-1100:600]" # [-800:400]
#~ >   xgplot11.myyrange = xgplot11.origyrange
#~ >   xgplot11(xgplot11.myyrange)
#~ >   xgplot11("set xrange [{0}:{1}]".format(xgplot11.myxrange[0], xgplot11.myxrange[1]))
#~ >   xgplot11.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrtoemz')), # tsz/wrtoemz
#~ >     options="t'wrtoemz' with steps lc rgb 'violet'"
#~ >   ))
#~ >   xgplots.append(xgplot11) ###
#~ >
#~ >   print "prep xgplot12"
#~ >   xgplot12=getPrepXgplot()
#~ >   xgplot12.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot12.origyrange = "set yrange [-300:1200]"
#~ >   xgplot12.myyrange = xgplot12.origyrange
#~ >   xgplot12(xgplot12.myyrange)
#~ >   xgplot12("set xrange [{0}:{1}]".format(xgplot12.myxrange[0], xgplot12.myxrange[1]))
#~ >   xgplot12.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1m')), # ts1/wtoe1m
#~ >     options="t'wtoe1m (wtot-mw*t1)' with steps lc rgb 'red'"
#~ >   ))
#~ >   #~ xgplot12.append(xnuplot.record( aats1, using=(0, ats1.dtype.names.index('wtoe1m')), # ts1/wtoe1m
#~ >     #~ options="t'' with points lc rgb 'red' pt 1"
#~ >   #~ ))
#~ >   xgplot12.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2mm')), # ts2/rtoe2mm
#~ >     options="t'rtoe2m (rtot-mrm*t2)' with steps lc rgb 'blue'"
#~ >   ))
#~ >   #~ xgplot12.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2mm')), # ts2/rtoe2mm
#~ >     #~ options="t'' with points lc rgb 'blue' pt 1"
#~ >   #~ ))
#~ >   xgplots.append(xgplot12) ###
#~ >
#~ >   print "prep xgplot13"
#~ >   xgplot13=getPrepXgplot()
#~ >   xgplot13.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot13.origyrange = "set yrange [-1300:600]" # [-800:400]
#~ >   xgplot13.myyrange = xgplot13.origyrange
#~ >   xgplot13(xgplot13.myyrange)
#~ >   xgplot13("set xrange [{0}:{1}]".format(xgplot13.myxrange[0], xgplot13.myxrange[1]))
#~ >   xgplot13.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrtoemmz')), # tsz/wrtoemmz
#~ >     options="t'wrtoemmz' with steps lc rgb 'violet'"
#~ >   ))
#~ >   xgplots.append(xgplot13) ###
#~ >

  # for the xmarker, we only need x (ts) data; but may need other, for, say, color
  print "xmarkers"
  xmarkers = dObject()
  xmarkers.data = atso2[['ts2','st12']]
  # given we assume data_xrange starts from zero,
  # the data xrange length is the max in [1];
  # use it to get relative x positions (in range 0.0:1.0) :
  xmarkers.dataxrel = atso2['ts2']/data.orig_data_xrange[1]
  # application specific
  xmarkers.appd = np.array([]) # in data domain (will be np.array later; overwrites)
  xmarkers.appdxrel = [0.0] # in 0.0:1.0 domain
  #
  # a printout
  #~ print "ats2    ", pformat(ats2[:20])
  #~ print "ats2csrl", pformat(ats2csrl[:20])
  #  (0.138380, 0.139097) -> 4.22, 4.24 (approx)
  #~ pa2 = ats2[np.logical_and(ats2['ts2']>=4.22,ats2['ts2']<=4.24)]
  #~ pa2cs = ats2csrl[np.logical_and(ats2csrl['ts2']>=4.22,ats2csrl['ts2']<=4.24)]
  #~ for ipa in pa2:
    #~ print " ", ipa
    #~ if ipa['ts2'] in pa2cs['ts2']:
      #~ print " "*50, pa2cs[pa2cs['ts2'] == ipa['ts2']]
  #~ zmxrange_history[zmxrange_current] = (0.138380, 0.139097)
  # printout - check if there are cumulative sums that don't match
  #~ for ipacs in ats2csrl:
    #~ ipa = ats2[ats2['ts2'] == ipacs['ts2']]
    #~ if ipa['rtot2'] != ipacs['rcs']:
      #~ print "ipa  ", ipa
      #~ print "ipacs", ipacs
      #~ break
  #ipa   [(0.047101, 8084, 53, 171631, 0, 92, 84, 85)]
  #ipacs (0.047101, 177, 0.0019969999999999988, 7902, 167767)
  # this sort of messes up with a gnuplot Warning: empty y range [167767:167767], adjusting to [166089:169445]
  # (which then messes with the PNG - Xnuplot hack should be fixed to differentiate betw. stdout and stderr)
  #~ ttt = ipacs['ts2']/data.orig_data_xrange[1]
  #~ tttr = 0.0005/data.orig_data_xrange[1]
  #~ zmxrange_history.append( (ttt-tttr, ttt+tttr) )
  #~ zmxrange_current = len(zmxrange_history)-1
  #~ # just a comparison printout, to check if individual rlen and their cumulative sums match
  #~ pa2 = ats2[np.logical_and(ats2['ts2']>=0.044,ats2['ts2']<=0.048)]
  #~ pa2cs = ats2csrl[np.logical_and(ats2csrl['ts2']>=0.044,ats2csrl['ts2']<=0.048)]
  #~ for ipa in pa2:
    #~ print " ", ipa
    #~ if ipa['ts2'] in pa2cs['ts2']:
      #~ print " "*50, pa2cs[pa2cs['ts2'] == ipa['ts2']]
  #
  # if running extraFunc - use timer to schedule it later
  # (extraFunc_export_modified_rtoe2m is will show screen with just 2000ms after delay)
  ## gtk.timeout_add(3000, extraFunc_export_modified_rtoe2m)
  # (if needed, as in extraFunc_exportmarkers - but not extraFunc_export_modified_rtoe2m -
  # use global eF_em_started, to prevent additional recursion as setup is called by it;
  # note that even 3000ms after delay will not show first screen here, but export seems to work):
  ## if 'eF_em_started' not in globals():
  ##  gtk.timeout_add(2000, extraFunc_exportmarkers)

def extraFunc_export_modified_rtoe2m():
  global bpw, fbps, ftpd, abps, apd, rbps_mean, rbps_med, rbps_rms, wbps_mean, wbps_med, wbps_rms
  #print (bpw, fbps, ftpd, abps, apd, rbps_mean, rbps_med, rbps_rms, wbps_mean, wbps_med, wbps_rms)
  global data, xgplots, zmxrange_history, zmxrange_current
  #data.structured = [  ats1,  ats2,  atsz,  ats2csrl, atso2 ]
  #data.plotformat = [ aats1, aats2, aatsz, aats2csrl ]
  ats1 = data.structured[0]
  ats2 = data.structured[1]
  atsz = data.structured[2]
  aats2 = data.plotformat[1]
  aatsz = data.plotformat[2]
  zmxrange_history[zmxrange_current] = (0.9, 1)
  xgplot10 = xgplots[0] ; xgplot11 = xgplots[1] ;
  xgplot11.myyrange = "set yrange [-1400:-600]"
  for itn in range(10,21):
    print itn, "ex rtoe2m"
    ka = rbps_med-itn; kb = bpw-ka*ats2[0]['ts2'] # rbps_mean rbps_med
    rtoe2m = ats2['rtot2'] - (ka*ats2['ts2']+kb)
    #ats2 = nprf.append_fields(ats2, names='rtoe2m', data=rtoe2m.astype(ats2.dtype['rtot2']), dtypes=ats2.dtype['rtot2'], usemask=False)
    ats2['rtoe2m'] = rtoe2m.astype(ats2.dtype['rtot2'])
    print itn, "interp to atsz"
    wtoemz, rtoemz = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wtoe1m', ats2, 'ts2', 'rtoe2m', atsz, 'tsz')
    print itn, "subtract"
    wrtoemz = np.subtract(wtoemz['wtoe1m'], rtoemz['rtoe2m']) # dtype/name is here lost
    print itn, "atsz append_fields"
    #atsz = nprf.append_fields(atsz, names='wrtoemz', data=wrtoemz, dtypes=wtoemz.dtype['wtoe1m'], usemask=False)
    atsz['wrtoemz'] = wrtoemz
    for ix, ins in enumerate(ats2.dtype.names):
      aats2[:,ix] = ats2[ins]
    for ix, ins in enumerate(atsz.dtype.names):
      aatsz[:,ix] = atsz[ins]
    #xgplot10.append(xnuplot.record( aats2, using=(0, ats2.dtype.names.index('rtoe2m')), # ts2/rtoe2m
    #  options="t'rtoe2m (rtot-mr*t2)' with steps lc rgb 'blue'"
    #)) # for x10, this is the second append!
    #xgplot11.append(xnuplot.record( aatsz, using=(0, atsz.dtype.names.index('wrtoemz')), # tsz/wrtoemz
    #  options="t'wrtoemz' with steps lc rgb 'violet'"
    #))
    #pprint(inspect.getmembers(xgplot10[1])) # xgplot10[1] == xnuplot.record
    xgplot10[1].data = aats2.astype('float32')
    xgplot11[0].data = aatsz.astype('float32')
    #pprint(inspect.getmembers(xgplot10[1])) # xgplot10[1] == xnuplot.record
    # cannot just put generateEntireImage here:
    # (warning: Too many axis ticks requested -> glib.GError: Fatal error reading PNG image file: Not a PNG file)
    #generateEntireImage(fnsuffix="rm-%d"%(ix), prompt=False, blocking=True)
    # needed for "live" view also:
    rerenderXnuplotTracks(blocking=True)
    while gtk.events_pending():
      gtk.main_iteration(block=True) # is good here
    # after that, now can generateEntireImage:
    generateEntireImage(fnsuffix="rm-{0}".format(itn), prompt=False, blocking=True)
  gtk.timeout_add(500, sys.exit, 0)


# these files have ftdi overruns:
# $ for DIRNAME in `ls -d ftdi*/` ; do DIRNAME=${DIRNAME%%/}; echo -e $DIRNAME "\n$(awk '{if($6!="0" && $6!="60"){print;}}' $DIRNAME/repz.txt)" ; done
# ftdiprof-2013-12-03-07-07-02_256
# 24.670420 24464.334967 0 2 1 2 62 74119 4357303 0 585 176644 176620 256
# ftdiprof-2013-12-03-07-17-29_256
# 25.674498 25091.446265 0 2 1 2 62 77132 4534528 0 768 176645 176616 256
# ftdiprof-2013-12-03-07-22-05_128
#
# ftdiprof-2013-12-03-07-24-24_128
#
# ftdiprof-2013-12-03-07-26-30_128
#
# ftdiprof-2013-12-03-07-38-31_64
# 5.971406 26331.685702 0 2 1 62 62 17931 1054066 0 590 176617 176518 64 ********
# 5.971427 26331.685723 0 2 1 2 62 17932 1054128 0 592 176627 176528 64
# 9.966742 26335.681038 0 2 1 2 62 29935 1759785 0 663 176632 176565 64
# ftdiprof-2013-12-03-08-25-59_64
#
# ftdiprof_first_256
# 16.925497 7292.701039 0 2 1 2 62 50841 2989001 0 823 176646 176597 256
# 26.912340 7302.687882 0 2 1 2 62 80843 4753083 0 837 176644 176613 256
#
# (0.569052, 0.572684) 0.572684-0.569052 = 0.003632 (0.3% of 30s)
def extraFunc_exportmarkers():
  global indatfile, window
  global eF_em_started
  eF_em_started = True
  window.set_size_request(1000, 400)
  basedir = "/media/disk/tmp/ftdi_prof"
  dirs_with_overruns = [ "oldcapt01/ftdiprof-2013-12-03-07-07-02_256",
  "oldcapt01/ftdiprof-2013-12-03-07-17-29_256",
  "oldcapt01/ftdiprof-2013-12-03-07-38-31_64",
  "oldcapt01/ftdiprof_first_256",
  "ftdiprof-2013-12-06-05-03-49_64" ]
  for idir in dirs_with_overruns:
    indatfile = basedir + "/" + idir + "/" + "repz.txt"
    setupPlotData()
    exportAllXmarkersAtRange(inrange=[0, 0.003632])
  print("ls /media/disk/tmp/ftdi_prof/{,oldcapt01}/{ftdiprof-2013-12-03-07-07-02_256,ftdiprof-2013-12-03-07-17-29_256,ftdiprof-2013-12-03-07-38-31_64,ftdiprof_first_256,ftdiprof-2013-12-06-05-03-49_64}/mtp*_m*.png 2>/dev/null")
  gtk.timeout_add(500, sys.exit, 0)



# actually set the new setup
import inspect
setupsrc = inspect.getsource(setupPlotData)
setGlobalFunc(setupsrc) #set_setupPlotData(setupsrc)
# if running extraFunc:
#extrasrc = inspect.getsource(extraFunc_export_modified_rtoe2m)
#setGlobalFunc(extrasrc)
#extrasrc = inspect.getsource(extraFunc_exportmarkers)
#setGlobalFunc(extrasrc)

if __name__ == "__main__":
  main()

