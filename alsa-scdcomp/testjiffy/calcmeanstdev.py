#!/usr/bin/env python2.7
################################################################################
# calcmeanstdev.py                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

import numpy as np


def processFile(inpath):
  txtdata = np.loadtxt(inpath,
    #delimiter=chr(164),
    #comments="#",
    dtype=np.float64, # more accurate mean
  )
  #~ print txtdata

  # axis=0 goes per columns

  colmeans = np.mean(txtdata, axis=0, dtype=np.float64)
  #~ print colmeans

  colstds = np.std(txtdata, axis=0, dtype=np.float64)
  #~ print colstds

  colvars = np.var(txtdata, axis=0, dtype=np.float64)
  #~ print colvars, colstds**2 # are equal

  rep="""{0} has
  N={1} items of delta t (col 1), with:
  mean: {2} stddev: {3} (variance: {4})

""".format(inpath,
  txtdata.shape[0], #len(txtdata[1]),
  colmeans[1], colstds[1], colvars[1]
)
  print(rep)

for ifile in ('captures/_testjiffy_00001.dat',
    'captures/_testjiffy_00002.dat',
    'captures/_testjiffy_hr_00001.dat'):
  processFile(ifile)


"""
# prints:

captures/_testjiffy_00001.dat has
  N=9 items of delta t (col 1), with:
  mean: 0.00400422222123 stddev: 1.84075890004e-05 (variance: 3.38839332809e-10)
  -E 0.0040042 = 4004.200e-6 = 4.004200e-03 ; 18.407e-6 = 1.8407e-05

captures/_testjiffy_00002.dat has
  N=9 items of delta t (col 1), with:
  mean: 0.00400166666562 stddev: 0.00187989869374 (variance: 3.53401909873e-06)


captures/_testjiffy_hr_00001.dat has
  N=199 items of delta t (col 1), with:
  mean: 0.00400011055274 stddev: 5.33826408929e-05 (variance: 2.8497063487e-09)
"""

