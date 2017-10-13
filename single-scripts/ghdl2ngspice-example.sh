#!/usr/bin/env bash

SIGN="sdaau, 2011"
# call with: ./ghdl2ngspice-example.sh (no arguments)
# demonstration of:
## GHDL to simulate a VHDL model (PWM generator) and output vcd data;
## gtkwave with tcl script to extract the PWM vcd channel into new vcd file;
## vcd2ngspice-d_source.py to convert the extracted vcd data file into ngspice's d_source (digital source) data format
## gschem to generate appropriate circuit schematic and netlist for ngspice
## ngspice to simulate the circuit with the converted PWM data as a voltage source
# to clean, with: ./ghdl2ngspice-example.sh -clean

BASENM="ghdl2ngspice"
VHDBASE="${BASENM}_pwmgensim_twb"
VHDFILE="${VHDBASE}.vhd"
VCDFILEA="${BASENM}_dumpall_ghdl.vcd"
VCDFILEB="${BASENM}_extrpwm_ghdl.vcd"
TCLFILE="${BASENM}_gtkwave_extract_vcd.tcl"
VCD2NGSCRIPT="vcd2ngspice-d_source.py"
VCD2NGURL="http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/single-scripts/vcd2ngspice-d_source.py?content-type=text%2Fplain"
NGDSRCFILE="${BASENM}_extrpwm_ngspice_d_source.text"
SCHFILE="${BASENM}_d_source_RC.sch"
IVBASE="input_vector"
MODFILEIV="${IVBASE}.mod"
DACBASE="dac1"
MODFILEDAC="${DACBASE}.mod"
SIMCMDS="${BASENM}_ngspice-sim.cmds"
NETFILE="${BASENM}_d_source_RC.net"

# note: `hardcopy ${NGSIMPSFILE}` enforces lowercase anyways!
# ( ${BASENM}_pwm_d_source_RC.ps -> 'ghdl2ngspice_pwm_d_source_rc.ps')
OUTIMGBASE="${BASENM}_pwm_d_source_rc"
NGSIMPSFILE="${OUTIMGBASE}.ps"
NGSIMPNGFILE="${OUTIMGBASE}.png"

# list of all files to clean:
ALLFCLEAN="${VCDFILEA} ${VCDFILEB} ${TCLFILE} ${NGDSRCFILE} ${SCHFILE} ${MODFILEIV} ${MODFILEDAC} ${SIMCMDS} ${NETFILE} ${NGSIMPSFILE} *${VHDBASE}* work-obj93.cf" # minus ${VCD2NGSCRIPT}; minus ${VHDBASE} ${VHDFILE} (because of *${VHDBASE}*) ; minus ${NGSIMPNGFILE} so eog can reload modifies images properly

SIMTIME="100us"

# succeeds if there is something in $1
#~ echo "1: $1"
if [ -n "${1:+x}" ] ; then
if [ "${1}" == "-clean" ] ; then
echo "DOCLEAN"
DOCLEAN="1"
fi
fi

testfiles() {
  cleanup
  create_vhdfile
  create_tclfile
  create_schfile
}

main() {

  #~ testfiles ; exit               # test/debug
  #~ dumpversions ; set -x; set +x  # ; exit # test/debug

  if [ "${DOCLEAN}" == "1" ] ; then
    # just cleanup and exit
    cleanup
    exit
  fi

  # start with cleanup
  # (ignore complaints when it fails on not-yet-created files)
  cleanup
  #~ exit                           # test/debug

  # get .vhd file, if needed
  create_vhdfile

  set -x
  # simulate using ghdl:
  # "import units" - analyze pwmgensim_twb.vhd
  ghdl -i "${VHDFILE}" # creates work-obj93.cf

  # "Make UNIT": elaborate pwmgensim_twb
  ghdl -m ${VHDBASE} # generates ./pwmgensim_twb executable

  # note [1]: "run UNIT" - simulates (generates VCD data)
  ghdl -r ${VHDBASE} --stop-time=${SIMTIME} --vcd=${VCDFILEA}
  set +x

  # get ghdl tcl file, if needed
  create_tclfile

  set -x
  # vcd file all of the signals inside;
  # extract only `pwmoc_out` using gtkwave tcl script
  # (this command exports as file ${VCDFILEB} (vcd))
  gtkwave ${VCDFILEA} --tcl_init=${TCLFILE}

  # now here we need a script, to generate ngspice compatible digital data from the .vcd ... python2.7 / 3.2 is OK
  # get vcd2ngspice script, if needed
  if [ ! -f "${VCD2NGSCRIPT}" ]; then
    wget "${VCD2NGURL}" -O "${VCD2NGSCRIPT}"
  fi

  # convert the extracted PWM in ${VCDFILEB} (vcd) to "${NGDSRCFILE}" (ngspice d_source)
  python vcd2ngspice-d_source.py -i "${VCDFILEB}" > "${NGDSRCFILE}"
  set +x

  # now the PWM ngspice d_source data is ready;
  # proceed with ngspice netlist generation

  # get gschem .sch file (and supporting), if needed
  create_schfile


  set -x
  # create ngspice netlist from .sch using gnetlist
  # note: must be sorted (old: -s/new: -O sort_mode)
  #  so sim commands are appended at end of netlist file!
  gnetlist -v -O sort_mode -g spice-sdb -o "${NETFILE}" "${SCHFILE}"

  # the netlist file should have all the right references;
  # call ngspice (batch) to simulate it:
  ngspice -b "${NETFILE}"

  # the batch simulation should generate a PostScript diagram/hardcopy
  # use ImageMagick's convert to obtain png from it
  convert "${NGSIMPSFILE}" "${NGSIMPNGFILE}"
  set +x

  echo "----- ${0} FINISHED ----  "
  echo "----- (you can view the ${OUTIMGBASE}.{png,ps} images now) ----  "

  # if you want to start viewer:
  #~ eog ${NGSIMPNGFILE}
} # end main()


cleanup() {
  echo "  RM ${ALLFCLEAN}"
  for ix in "${ALLFCLEAN}" ; do
    #~ echo rm ${ix}
    rm ${ix}
  done
} # end cleanup()


dumpversions() {
  cat /etc/issue
  uname -a
  ghdl --version | grep '[[:digit:]]'
  gtkwave --version | grep '[[:digit:]]'
  python --version
  gschem --version | grep '[[:digit:]]'
  gnetlist --version | grep '[[:digit:]]'
  ngspice --version | grep '[[:digit:]]'
  convert --version | grep '[[:digit:]]'

  # dev output:
  #~ Ubuntu 11.04 \n \l
  #~ Linux ljutntcol 2.6.38-12-generic #51-Ubuntu SMP Wed Sep 28 14:25:20 UTC 2011 i686 i686 i386 GNU/Linux
  #~ GHDL 0.29 (20100109) [Sokcho edition]
  #~  Compiled with GNAT Version: 4.4.5 20100909 (prerelease)
  #~ Copyright (C) 2003 - 2010 Tristan Gingold.
  #~ GTKWave Analyzer v3.3.19 (w)1999-2011 BSI
  #~ Python 2.7.1+
  #~ gEDA 1.7.0 (gdc5914e)
  #~ Copyright (C) 1998-2011 gEDA developers
  #~ gEDA 1.7.0 (gdc5914e)
  #~ Copyright (C) 1998-2011 gEDA developers
  #~ ngspice compiled from ngspice revision 22
  #~ Copyright (C) 1985-1996,  The Regents of the University of California
  #~ Copyright (C) 1999-2008,  The NGSpice Project
  #~ Version: ImageMagick 6.6.2-6 2011-03-16 Q16 http://www.imagemagick.org
  #~ Copyright: Copyright (C) 1999-2010 ImageMagick Studio LLC

} # end cleanup()



create_vhdfile() {
echo "create_ ${VHDFILE}"
cat > "${VHDFILE}" <<EOF
-- file: ${VHDFILE}
-- ${SIGN}
-- "pure" testbench (no components)
---------------

-- library IEEE;
  -- use IEEE.STD_LOGIC_1164.ALL;
  -- use IEEE.NUMERIC_STD.ALL;


-- #########################

library IEEE;
  use IEEE.STD_LOGIC_1164.ALL;
  use IEEE.NUMERIC_STD.ALL;

ENTITY ${VHDBASE} IS
END ${VHDBASE};

ARCHITECTURE testbench_arch OF ${VHDBASE} IS

  -- 'wires'
  SIGNAL wCLK : std_logic := '0';

  -- divisor 2 info signal
  SIGNAL cdiv2 : std_logic := '0';
  -- clock freq divided 2
  SIGNAL wclk2 : std_logic := '0';

  -- 8-bit count - 0 to 255: specifies PWM period & resolution
  -- SIGNAL pwmCount : NATURAL range 0 to 2**8-1 := 2**8-1; -- does not wrap
  SIGNAL pwmCount : UNSIGNED(7 downto 0) := "11111111"; -- this wraps; but even if "+" defined: 2**8-1; -- cannot determine exact overloaded matching definition for "-"
  SIGNAL pwmTick : std_logic := '0';

  -- 8-bit PWM value (to be reproduced)
  SIGNAL pwmVAL : UNSIGNED(7 downto 0) := "11111111";

  -- pwm out (output compare)
  SIGNAL pwmOC_out : std_logic := '1';

  SIGNAL wIN  : std_logic := 'Z';

  -- clock parameters
  constant PERIODN : natural := 20; -- can be real := 20.0;
  constant PERIOD : time := PERIODN * 1 ns;
  constant DUTY_CYCLE : real := 0.5;
  constant OFFSET : time := 100 ns;

-- implementation of workbench
BEGIN

  -- PROCESSES (STATE MACHINES) CODE =========

  -- clock process for generating CLK
  clocker: PROCESS
  BEGIN

    WAIT for OFFSET;

    CLOCK_LOOP : LOOP
      wCLK <= '0';
      WAIT FOR (PERIOD - (PERIOD * DUTY_CYCLE));
      wCLK <= '1';
      WAIT FOR (PERIOD * DUTY_CYCLE);
    END LOOP CLOCK_LOOP;
  END PROCESS clocker;

  -- perma-assign:
  -- pwmOC_out <= '1'  WHEN pwmVAL > pwmCount ELSE '0'; -- no pulse on 0 ; 255 don't hit
  pwmOC_out <= '1'  WHEN pwmVAL >= pwmCount ELSE '0'; -- 0 gives pulse; 255 hits (fills period with 1)


  clockdiv2: PROCESS(wCLK)
  BEGIN

    -- like this, wclk2 is synchronous to wclk in beh sim (somehow; even if all should start next clock cycle?!):
    if rising_edge(wCLK) then
      if cdiv2 = '1' then
        wclk2 <= '0';
        cdiv2 <= '0';
      else
        wclk2 <= '1';
        cdiv2 <= '1';
        pwmCount <= pwmCount + 1;

        if pwmCount = "11111111" then -- next will be 0, indicate pwm period
          pwmTick <= '1';
          pwmVAL <= pwmVAL + 16;
        else
          pwmTick <= '0';
        end if;
      end if;

      -- strangely; this never fires ?!:
      -- if wclk2 = '1' then
        -- pwmCount <= pwmCount + 1;
      -- end if;
    else -- negedge
      wclk2 <= '0';
      pwmTick <= '0';
    end if;
  END PROCESS clockdiv2;

  simulator: PROCESS
  BEGIN

    WAIT for OFFSET;

    WAIT for 10 ns;

    -- take 'in' low - out should detect it with a pulse
    wIN <= '0';
    WAIT for 50 ns;

    -- take 'in' high - no out
    wIN <= '1';
    WAIT for 50 ns;

    -- repeat
    wIN <= '0';
    WAIT for 50 ns;

    wIN <= '1';
    WAIT for 50 ns;

    -- hold
    WAIT;

  END PROCESS simulator;

  -- END PROCESSES (STATE MACHINES) CODE =====
END testbench_arch; -- ARCHITECTURE

EOF
} # end create_vhdfile()

create_tclfile() {
echo "create_ ${TCLFILE}"
cat > "${TCLFILE}" <<EOF
# file: ${TCLFILE}
# ${SIGN}

# call with:
# (this opens gtkwave, and has interpreter started in cmdline):
# gtkwave ${VCDFILEA} --tcl_init=${TCLFILE}
# (--script seems to behave the same as --tcl_init,
#  ... except there is no tcl interpreter with --script)
# (in any case, must specify 'exit' manually in tcl)

# to list every command (there are no procs) inside gtkwave:
# % info commands gtkwave::*
# also, this works too:
# % ::gtkwave::/File/Export/Write_VCD_File_As "test.vcd"
# it will save directly - without the argument, it will raise window

puts "${TCLFILE}: input dump file name: [ ::gtkwave::getDumpFileName ]"
set outfname "${VCDFILEB}"

# (doesn't really work! not even with arguments ..)
# (and even if changing from GUI, it is not preserved in .vcd export)
::gtkwave::/View/Scale_To_Time_Dimension/ns

# select the signals to "filter"
# add the pwmoc_out signal from the mydump_pwmocout_isim_gtkwave_sed.vcd
# (specified on command line; adding to gtkwave's window)
# (the returned value of addSignals is stored in var num_added - not used atm)
set num_added [ gtkwave::addSignalsFromList "pwmoc_out" ]

# (nope, doesn't do anything really)
::gtkwave::/View/Scale_To_Time_Dimension/ns

# now export the current window as new .vcd file
::gtkwave::/File/Export/Write_VCD_File_As "\$outfname"


# change the "$timescale"
# since we want the output file in ns (as it is created with 10 ns resolution)
# we may as well run the sed commands here;
## Do not quote the exec arguments!
## furthermore; don't even singlequote the set 's///' statement!
## exec -ignorestderr completely gulps stderr - even from strace;
## cannot do stuff like 's//{...; w /dev/stdout}' from tcl either..
## just `exec $tcom` fails; but `eval exec $tcom` passes!

# now, the fs from GHDL propagate trhough the gtkwave export
# so instead of ps, replace fs (with "ns")
set tcom "sed -i s/1fs/1ns/ \$outfname"
puts \$tcom
catch {eval exec \$tcom} result
puts \$result

# remove six zeroes each from timesteps (fs to ns):
# inside sed statements, usual shell escape \1 needs to
#  be repeated four times: \\\\\\\\1 !!
set tcom "sed -i s/^#\\\\\\\\(.*\\\\\\\\)000000/#\\\\\\\\1/ \$outfname"
puts \$tcom
catch {eval exec \$tcom} result
puts \$result

# finally, exit
# (it will raise window anyway, but will exit - --nowm doesn't help)
exit

EOF
} # end create_tclfile()


create_schfile() {
echo "create_ ${SCHFILE}"
cat > "${SCHFILE}" <<EOF
# file: ${SCHFILE}
# ${SIGN}
v 20110116 2
C 40000 40000 0 0 0 title-B.sym
C 47100 48500 1 90 0 capacitor-1.sym
{
T 46400 48700 5 10 0 0 90 0 1
device=CAPACITOR
T 46600 48800 5 10 1 1 90 0 1
refdes=C1
T 46200 48700 5 10 0 0 90 0 1
symversion=0.1
T 47100 48800 5 10 1 1 0 0 1
value=10n
}
C 45500 49800 1 0 0 resistor-1.sym
{
T 45800 50200 5 10 0 0 0 0 1
device=RESISTOR
T 45900 50100 5 10 1 1 0 0 1
refdes=R1
T 45800 49600 5 10 1 1 0 0 1
value=1K
}
C 46800 47900 1 0 0 gnd-1.sym
N 46400 49900 46900 49900 4
{
T 46900 49900 5 10 1 1 0 0 1
netname=1
}
N 46900 49900 46900 49400 4
N 46900 48500 46900 48200 4
{
T 46900 48300 5 10 1 1 0 0 1
netname=0
}
C 40900 47800 1 0 0 spice-model-1.sym
{
T 41000 48500 5 10 0 1 0 0 1
device=model
T 41000 48400 5 10 1 1 0 0 1
refdes=M1
T 42200 48100 5 10 1 1 0 0 1
model-name=${IVBASE}
T 41400 47900 5 10 1 1 0 0 1
file=${MODFILEIV}
}
C 43500 47800 1 0 0 spice-model-1.sym
{
T 43600 48500 5 10 0 1 0 0 1
device=model
T 43600 48400 5 10 1 1 0 0 1
refdes=M2
T 44800 48100 5 10 1 1 0 0 1
model-name=${DACBASE}
T 44000 47900 5 10 1 1 0 0 1
file=${MODFILEDAC}
}
C 43800 49500 1 0 0 dac.sym
{
T 44100 50400 5 10 1 1 0 0 1
refdes=abridge1
T 43400 49300 5 10 1 0 0 0 1
value=[3] [2] ${DACBASE}
}
N 42500 49900 43800 49900 4
{
T 43100 49900 5 10 1 1 0 0 1
netname=3
}
N 45000 49900 45500 49900 4
{
T 45200 49900 5 10 1 1 0 0 1
netname=2
}
C 42500 49500 1 0 1 logic.sym
{
T 42100 50400 5 10 1 1 0 0 1
refdes=A1
T 40500 49300 5 10 1 0 0 0 1
value=[3] ${IVBASE}
T 41200 49100 5 10 1 0 0 0 1
pinnumber=1
}
C 47300 49200 1 0 0 spice-directive-1.sym
{
T 47400 49500 5 10 0 1 0 0 1
device=directive
T 47400 49600 5 10 1 1 0 0 1
refdes=AF1
T 47500 49300 5 10 1 0 0 0 1
file=${SIMCMDS}
T 47300 49900 5 10 1 0 0 0 1
value=unknown
}
EOF
# end ${SCHFILE}

echo "create_ ${MODFILEIV}"
cat > "${MODFILEIV}" <<EOF
.model ${IVBASE} d_source(input_file="${NGDSRCFILE}")
EOF
# end ${MODFILEIV}

echo "create_ ${MODFILEDAC}"
cat > "${MODFILEDAC}" <<EOF
.model ${DACBASE} dac_bridge(out_low = 0.7 out_high = 3.5 out_undef = 2.2
+ input_load = 5.0e-12 t_rise = 50e-9 t_fall = 20e-9)
EOF
# end ${MODFILEDAC}

echo "create_ ${SIMCMDS}"
cat > "${SIMCMDS}" <<EOF
.control
echo ...........

* set color for postscript output
set hcopypscolor=1

* perform transient sim
tran 1us ${SIMTIME}

* show all accessible vectors
display

* save the plot of node voltage V(1)
* in a ${NGSIMPSFILE} file
set hcopywidth=1000
set hcopyheight=500
hardcopy ${NGSIMPSFILE} V(2) V(1)

.endc

EOF
# end ${SIMCMDS}

} # end create_schfile()


## ----------- file creation code END

## ----------- call main
main

## ----------- SCRIPT END







# notes:
#~ $ sudo apt-get install ghdl
#~ The following NEW packages will be installed:
  #~ cpp-4.4 gcc-4.4 gcc-4.4-base ghdl gnat-4.4 gnat-4.4-base libgnat-4.4
  #~ libgnatprj4.4 libgnatvsn4.4
#~ Need to get 33,6 MB of archives.
#~ After this operation, 112 MB of additional disk space will be used.

# see also:
# https://wiki.ubuntu.com/From_PSpice_to_ngspice-gEDA
# [https://sourceforge.net/projects/ngspice/forums/forum/133842/topic/4835459 MWE: load text file data for digital source]
# [https://sourceforge.net/projects/ngspice/forums/forum/133842/topic/3833858?message=8611592 Command log: basic use: variables and vectors]

# note [1]
# ghdl -r supports the same output switches like the executable; --vcd=FILENAME etc...
# "Currently, there is no way to select signals to be dumped: all signals are dumped" http://ghdl.free.fr/ghdl/Simulation-options.html
#~ ghdl -r pwmgensim_twb --stop-time=50ns # no new files if no dump output
#~ ./pwmgensim_twb:info: simulation stopped by --stop-time
#~ http://svn.gna.org/svn/ghdl/trunk/translate/grt/grt-vcd.adb shows that timescale is always 1 fs as output from ghdl!
