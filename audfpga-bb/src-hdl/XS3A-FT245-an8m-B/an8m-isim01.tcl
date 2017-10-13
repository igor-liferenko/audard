
# isim tcl script file
# place this file in directory of ISE project;
# and when running ISIM, execute
# (at the command line/terminal/shell prompt):
# source an8m-isim01.tcl

# [http://www2.tcl.tk/1302 vwait]
# [http://www.groupsrv.com/computers/about300535.html is there a way to pause Tcl?]
# synhronization variable
# (to allow sleep/wait/pause via vwait)
set syncvar 1
# sleeptime in milliseconds
set sleeptime 2000


# current single nRD cycle duration
# (negedge to negedge) - in ns
set rdtime 900
# cd tick period: 1/44100 = 22.6757e-6 = 22675 ns
set cdprd 22675

# note:
# run (6-1)*$rdtime ns  ;# "Incorrect usage of command 'run'"
# eval "run 10 ns"      ;# is OK!
# arithmetic operations - expr:
#   http://en.wikibooks.org/wiki/Tcl_Programming/expr#Arithmetic_operators
# to set variable to value of expr - "command substitution":
#   http://www.tcl.tk/about/language.html
# note: cannot write proc procName{x} (without space);
#  else: wrong # args: should be "proc name args body"
#  also: cannot call without space: procName{var}:
#  will get: invalid command name "procName{1000}"
# note:
#  #~ runSinglePass {$dly} ;# NaN: `Incorrect usage of command 'run'`
#  runSinglePass $dly      ;# works ok


# for with breakpoints: run ; show01
proc show01 {} {
  set a [show value {/xs3a_ft245_an8m_rdwr_tbw/UUT/state_rd}]
  set b [show value {/xs3a_ft245_an8m_rdwr_tbw/UUT/next_state_rd}]
  set c [show value {/xs3a_ft245_an8m_rdwr_tbw/UUT/state_wr}]
  set d [show value {/xs3a_ft245_an8m_rdwr_tbw/UUT/next_state_wr}]
  puts "_rd: $a ($b) ; _wr: $c ($d)"
}

# use `bp list` if setting manually
# wr state machine breakpoints
# to restart: bp clear; restart ; run 22875 ns ; show01 ; addbp01 ...  then `run; show01` or `step; show01`
proc addbp01 {} {
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 545
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 560
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 580
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 590
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 601
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 614
  bp add "/path/to/XS3A-FT245-an8m-B/XS3A_FT245_an8m.vhd" 619
}

# if singleRun takes too long,
# can always use Simulation/Break in isim
proc singleRun {} {
  global rdtime; # must declare global variable
  puts "singleRun here"
  restart
  isim force add do_rd_sim 0        ;# disable rd sim engine
  run 200 ns                        ;# go past the reset
  isim force add do_rd_sim 1        ;#  enable rd sim engine
  set simtime [expr (6-1)*$rdtime]  ;# calculate sim time for 6 bytes
  run $simtime ns                   ;# sim for 6 bytes
  isim force add do_rd_sim 0        ;#  disable rd sim engine
  run 8 ms                          ;# wait 8 ms before second run
  isim force add do_rd_sim 1        ;#  enable rd sim engine
  set simtime [expr $simtime+2500]  ;# take into account appearance of WR delay
  run $simtime ns                   ;# sim for 6 bytes
  isim force add do_rd_sim 0        ;#  disable rd sim engine
  run 8 ms                          ;#
}

# from ISIM terminal, call w:
# ISim>  runSinglePass 1000
proc runSinglePass {inDelay} {
  global rdtime; # must declare global variable
  puts "runSinglePass here"
  restart
  isim force add do_rd_sim 0        ;# disable rd sim engine
  run 200 ns                        ;# go past the reset
  isim force add do_rd_sim 1        ;#  enable rd sim engine
  set simtime [expr (6-1)*$rdtime]  ;# calculate sim time for 6 bytes
  run $simtime ns                   ;# sim for 6 bytes
  isim force add do_rd_sim 0        ;#  disable rd sim engine
  run $inDelay ns                   ;# wait for requested time in this state
  isim force add do_rd_sim 1        ;#  enable rd sim engine
  set simtime [expr $simtime+2500]  ;# take into account appearance of WR delay
  run $simtime ns                   ;# sim for 6 bytes
  isim force add do_rd_sim 0        ;#  disable rd sim engine
  run 140 us                        ;# exhaust CD ticks - at least 6*22 us!
}

# note: cannot really stop the stress test for loop in isim!
# (although can interrupt "run" by Simulation/Break in gui)
# to stop it, have to exit isim!
# (not really - can use Break is available at times,
#  open that menu at wait for it, and then can break even the for!
#  not always though - sometimes it continues after a break)
proc stressTest {} {
  global sleeptime; # must declare global variable
  global syncvar;   # going with the global here..
  puts "stressTest here"
  ;# dly 1000:2000/20 - seems OK
  ;# 22935 - first CD tick; go back some
  ;# dly 18205 - doesn't collide any more; 10905 doesn't reach, 11005 starts coliding
  for {set dly 10905} {$dly<=18205} {set dly [expr {$dly + 20}]} {
    puts "dly is $dly"
    runSinglePass $dly
    # wait for X seconds (allow GUI to update, and time to see it)
    after $sleeptime {set syncvar $syncvar}
    vwait syncvar
  }
}

#~ # select nets in module to trace (both -m and -n a must)
#~ # could use select -o off to "unselect"
#~ # "When a simulation is run from the ISE® software, ntrace is run automatically in order to draw out the waveforms" - it does not trace to stdout..
#~ # there is ltrace (line) and ptrace (process)
#~ ntrace select -m {UUT/membuf} -n wadr1
#~ ntrace select -m {UUT/membuf} -n radr1
#~ ntrace start
#~ ntrace stop

#~ "The isim condition command adds, removes or generates a list of conditional actions. A conditional action is equivalent to a VHDL process or a Verilog always process. "
#~ " To add a condition that states that for any change on signal asig, a stop occurs, and the condition is called label2:
#~ isim condition add /top/asig  {stop} -label label2 "
#~ "The expression may include vhdl/verilog signal or a verilog reg."
#~ however, must be on proper scope when setting condition - if it's not, may get messed up, and keep on spitting "Unable to find script corresponding to condition" regardless. (then isim must be shut down and restarted)
#~ must bring scope to actual container (so, membuf) (click on obj, then dump to see identifiers in scope!) only then can accept - even w/ full path! else "An identifier {/xs3a_ft245_an8m_rdwr_tbw/UUT/membuf/rptr_en} could not be found in the current scope."
#~ must not have braces in test (nor quotations!)
#~ { {UUT/membuf/rptr_en} == '1' }  # -- "An identifier {UUT/membuf/rptr_en} could not be found in the current scope."
#~ this works (when set on proper scope):
#~ isim condition add { /xs3a_ft245_an8m_rdwr_tbw/UUT/pgclk == 1 } {puts "Ehhe"} -label label0
#~ ctrl-c breaks too in isim??
#~ the label doesn't have much of a function - it shows neither in list, nor in stdout
#~ isim condition remove seems actually to leave something behind in memory, leading to possible breakage - restart isim instead in that case?
#~ condition add will always stop - even without a stop command! resume doesn't help; run continue just keeps on going and there's no printout
#~ "The command can include standard tcl commands and simulation tcl command, except run, restart, init, and step. Tcl variables used in the condition expression are surrounded by quotes "" instead of {}."


# doesn't really help with isim condition;
# it still breaks (and file isn't written until flush $fo; which is missing below)
set fo [open "tlogfile" w]
#~ eval "isim condition add { $trsig1 } { global \$fo; puts \$fo \"\[show time\]: radr1 \[show value $trsig1 -radix unsigned\]\" ; resume } -label radrChange"
# also - flush stdout - for immediate puts printout!

proc setIsimConditions {} {
  # trace any change on signal
  # must use eval if using variables; use quotes too - and escape quotes and []!

  set trsig1 /xs3a_ft245_an8m_rdwr_tbw/UUT/membuf/radr1
  set trsig2 /xs3a_ft245_an8m_rdwr_tbw/UUT/membuf/wadr1

  # set scope
  scope {/xs3a_ft245_an8m_rdwr_tbw/UUT/membuf}
  isim condition remove -all
  eval "isim condition add { $trsig1 } { puts \"\[show time\]: radr1 \[show value $trsig1 -radix unsigned\]\" ; flush stdout ; resume } -label radrChange"
  eval "isim condition add { $trsig2 } { puts \"\[show time\]: wadr1 \[show value $trsig2 -radix unsigned\]\" ; flush stdout ; resume } -label wadrChange"
  isim condition list

  # reset scope?
  scope {xs3a_ft245_an8m_rdwr_tbw}
}

# run with Conditions Until Duration - may kill isimgui!
# also, may have a "heavy" exit - with a delay, while breaking execution of rest of script.
proc runCUD { indur } {
  global syncvar
  # `show time` returns "x ns" - already a Tcl list with words (space separated)
  # can refer directly to list index via lindex
  # assume ns

  # add conditions - to trace in stdout
  setIsimConditions

  set tstart [lindex [show time] 0]
  set tend [expr $tstart + $indur]
  set ttmp $tstart
  puts "runCUD: tstart $tstart ; tend $tend "
  while { $ttmp < $tend } {
    #~ run 20 ns ;# will stop at break? yup.. much slower, but 'puts' from condition is more 'synchronized'
    run          ;# sim goes much faster than previous (but much much slower than normal sim), but puts printouts are flushed in bulks throughout!

    #~ # set ttmp [lindex [show time] 0]
    #~ # puts "ttmp1 $ttmp"
    #~ # flush stdout
    # MUST have this sync here!
    # AND at least 50 ms ! (slows everything down, but it works) - 10 ms nowork!
    after 50 {set syncvar $syncvar}
    vwait syncvar

    set ttmp [lindex [show time] 0]
    #~ puts "ttmp $ttmp"
    flush stdout ;# also this - to help the puts printouts?
  }
  # done - remove conditions
  isim condition remove -all

  puts "runCUD: out $ttmp "
}

# 512 (ram size)/ 176 (apparent in audacity) = 2.91; 3*176 = 528
proc runPointerTest {} {
  global rdtime; # must declare global variable
  global cdprd;  # must declare global variable
  puts "runPointerTest here"

  isim condition remove -all

  # go on...
  restart
  isim force add do_rd_sim 0          ;# disable rd sim engine
  run 200 ns                          ;# go past the reset

  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  #~ runCUD $simtime                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  #~ runCUD $simtime                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  #~ runCUD $simtime                     ;# sim for 176 bytes          # here should wrap
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks

  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  #~ runCUD $simtime                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  #~ run $simtime ns                     ;# sim for 176 bytes
  runCUD $simtime                     ;# sim for 176 bytes         # here should wrap
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (176-1)*$rdtime]  ;# calculate sim time for 176 bytes
  run $simtime ns                     ;# sim for 176 bytes
  #~ runCUD $simtime                     ;# sim for 176 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks

}

proc runPointerTest02 {} {
  global rdtime; # must declare global variable
  global cdprd;  # must declare global variable
  puts "runPointerTest here"

  isim condition remove -all

  # go on...
  restart
  isim force add do_rd_sim 0          ;# disable rd sim engine
  run 200 ns                          ;# go past the reset

  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (500-1)*$rdtime]  ;# calculate sim time for 500 bytes
  run $simtime ns                     ;# sim for 500 bytes
  #~ runCUD $simtime                     ;# sim for 500 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
  isim force add do_rd_sim 1          ;#  enable rd sim engine
  set simtime [expr (100-1)*$rdtime]  ;# calculate sim time for 100 bytes
  #~ run $simtime ns                     ;# sim for 100 bytes # should wrap here
  runCUD $simtime                     ;# sim for 500 bytes
  isim force add do_rd_sim 0          ;#  disable rd sim engine
  set simtime [expr 100*$cdprd]       ;# calculate sim time for 100 CD ticks
  run $simtime ns                     ;# sim for 100 cd ticks
}

proc runPrep01 {} {
  set cmdstr "scope {/xs3a_ft245_an8m_rdwr_tbw/}
  isim force remove do_rd_sim
  restart
  run 2 us
  isim force add do_rd_sim 1
  puts \"do_rd_sim will show \[show value do_rd_sim\], but it will be 1 \"
  "
  puts $cmdstr
  eval $cmdstr
}





