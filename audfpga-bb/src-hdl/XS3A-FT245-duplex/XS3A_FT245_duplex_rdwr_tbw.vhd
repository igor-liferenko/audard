-------------------------------------------------------------------------------
-- XS3A_FT245_duplex_rdwr_tbw.vhd
-- This file is a testbench engine - that represents (and
--   tries to simulate) the behaviour of FTDI FT245 chip.
-- The behaviour of the *FPGA interface* (toward the
--   FT245 chip) is in processFT245if.vhd, embedded in XS3A-FT245-duplex.vhd
-- Here we try to test read/write digital duplex loopback process
----------------------------------------------------------------------------------
-- sdaau <sd[at]imi.aau.dk>, 2011
-------------------------------------------------------------------------------
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
----------------------------------------------------------------------------------
-- quick sim:
-- xil_synt_test.sh XS3A_FT245_duplex_rdwr_tbw.vhd XS3A-FT245-duplex.vhd busFT245ifVHD.vhd processFT245if.vhd versatile_sd_fifo-1buf.v versatile_sd_counter.v versatile_fifo_dual_port_ram_dc_sw.v versatile_fifo_async_cmp.v led_drv_gate.v
--

library IEEE;
  use IEEE.STD_LOGIC_1164.ALL;
  -- use IEEE.STD_LOGIC_ARITH.ALL;
  use IEEE.STD_LOGIC_UNSIGNED.ALL;
  use IEEE.NUMERIC_STD.ALL;
  use IEEE.MATH_REAL.ALL;
  use IEEE.Std_Logic_TextIO.all;

library Std;
  use STD.TextIO.all;


-- ENTITY ---------------------------------------
-- declaration of actual 'electric ports' of this
--   FPGA 'core' (the testbench driver) ...
-- none here - it is a testbench
-- NOTE: never use '-' as entity name, only '_'!
ENTITY XS3A_FT245_duplex_rdwr_tbw IS
END XS3A_FT245_duplex_rdwr_tbw;

ARCHITECTURE testbench_arch OF XS3A_FT245_duplex_rdwr_tbw IS
  FILE RESULTS: TEXT OPEN WRITE_MODE IS "XS3A_FT245_duplex_rdwr_tbw-results.txt";

  -- the COMPONENT defined below, is the component
  --   that this testbench will apply to (interface with)
  --   a.k.a the UUT/DUT (unit/device under test)
  --   (UUT also needs to be specified after BEGIN)
  COMPONENT XS3A_FT245_duplex
  PORT
  (
    pgCLK : IN STD_LOGIC;						-- external 50 MHz oscillator, "global" clock
                                    -- (possibly 100 MHz with Xilinx DCM)

    -- interface pins to FT245
    pD_ft245     : INOUT STD_LOGIC_VECTOR(7 downto 0);  -- FT245's D[7..0]
    pRDn_ft245   : OUT STD_LOGIC;                       -- FT245's nRD
    pWR_ft245    : OUT STD_LOGIC;											  -- FT245's WR
    pRXFn_ft245  : IN STD_LOGIC;                        -- FT245's nRXF
    pTXEn_ft245  : IN STD_LOGIC;                        -- FT245's nTXE
    pPWREN_ft245 : INOUT STD_LOGIC;       -- FT245's PWREN
                                          -- make it INOUT, so we put it in hi Z,
                                          -- so it don't interfere

    -- LED pins (indication)
    pLED_R     : OUT STD_LOGIC;   -- LED active on Read - simply buffered (via FF) RD or RXF, must be out too
    pLED_nTXE  : OUT STD_LOGIC;   -- LED active on nTXE
    pLED_W     : OUT STD_LOGIC    -- LED active on Write - simply buffered (via FF) TXE or RXF
  );
  END COMPONENT;


   -- DECLARE REGISTERS ==========================

  -- 'wires'
  -- we need to handle both inputs and outputs of UUT here
  SIGNAL wtCLK : std_logic := '0';
  SIGNAL wtnRXF : std_logic := '1'; -- HERE init value, was 0
  SIGNAL wtnTXE : std_logic := '0';

  SIGNAL wtnRD : std_logic := 'Z'; -- was 0
  SIGNAL wtWR : std_logic := 'Z'; -- was 0

  SIGNAL wtD : STD_LOGIC_VECTOR(7 DOWNTO 0) := "ZZZZZZZZ";


  -- clock parameters
  constant PERIODN : natural := 20; -- can be real := 20.0;
  constant PERIOD : time := PERIODN * 1 ns;
  constant DUTY_CYCLE : real := 0.5;
  constant OFFSET : time := 95 ns;

BEGIN

  -- initializations:
  -- wtD <= "ZZZZZZZZ"; -- not this, seems to drive net??

  -- instances of components, and their wiring (port maps)...

  -- must define the device under test (UUT) after BEGIN, too
  UUT : XS3A_FT245_duplex
  PORT MAP (
    pgCLK       => wtCLK,
    pRXFn_ft245 => wtnRXF,
    pTXEn_ft245 => wtnTXE,
    pRDn_ft245  => wtnRD,
    pWR_ft245   => wtWR,
    pD_ft245    => wtD,
    pPWREN_ft245  => OPEN,
    pLED_R        => OPEN,
    pLED_W        => OPEN,
    pLED_nTXE     => OPEN
  );

  -- END instances of components, and their wiring (port maps)...


  -- PROCESSES (STATE MACHINES) CODE =========

  -- clock process for generating CLK
  -- (here, left as unnamed)
  PROCESS
  BEGIN

    WAIT for OFFSET;

    CLOCK_LOOP : LOOP
      wtCLK <= '0';
      WAIT FOR (PERIOD - (PERIOD * DUTY_CYCLE));
      wtCLK <= '1';
      WAIT FOR (PERIOD * DUTY_CYCLE);
    END LOOP CLOCK_LOOP;
  END PROCESS;


  -- simulate read process:
  -- need to control nRXF here
  ft245_read_trigger_sim: PROCESS
  BEGIN
    -- startup values:
    wtnRXF <= '1';  -- prepare nRXF high (Data (in receive FIFO) NOT ready for read  )
    -- no buffer signals here
    -- wtmE <= '1';    -- buffer is empty
    -- wtmF <= '0';    -- buffer is not full
    -- processFT245if should have set nRD to 1 as well..

    WAIT for OFFSET;  -- wait out the clock offset
    WAIT for 30 ns;   -- ... and 30 ns more

    FOR ipack IN 1 TO 130 LOOP

      wtnRXF <= '0';	-- trigger read; Data (in receive FIFO) ready for read

      -- WAIT until falling_edge(wtnRD);	--wrong syntax!
      WAIT until wtnRD = '0';
      WAIT for 20 ns; -- wait for FPGA to react with nRD active low
                      -- actually, wait T3 (20-50?) and then set data
      wtD <= std_logic_vector(to_unsigned(ipack, wtD'length)); -- "01010101"; ipack

      WAIT until wtnRD = '1';	-- wait for FPGA to end read (with nRD high)
      wtD <= "ZZZZZZZZ";  -- ... and we release the bidirectional bus (after T4=0ns)

      WAIT for 5 ns;	-- this would be wait T5 (0-25 ns) ; we take 5 ns here

      wtnRXF <= '1';	    -- read has finished, we (FT245) now raise RXF#

      WAIT for 80 ns; -- wait out T6 (RXF# Inactive after RD cycle)

    END LOOP;

    -- once more

-- >     wtnRXF <= '0';	-- trigger read; Data (in receive FIFO) ready for read
-- >
-- >     -- WAIT until falling_edge(wtnRD);	--wrong syntax!
-- >     WAIT until wtnRD = '0';
-- >     WAIT for 20 ns; -- wait for FPGA to react with nRD active low
-- >                     -- actually, wait T3 (20-50?) and then set data
-- >     wtD <= "11110000";
-- >
-- >     WAIT until wtnRD = '1';	-- wait for FPGA to end read (with nRD high)
-- >     wtD <= "ZZZZZZZZ";  -- ... and we release the bidirectional bus (after T4=0ns)
-- >
-- >     WAIT for 5 ns;	-- this would be wait T5 (0-25 ns) ; we take 5 ns here
-- >
-- >     wtnRXF <= '1';	    -- read has finished, we (FT245) now raise RXF#
-- >
-- >     WAIT for 80 ns; -- wait out T6 (RXF# Inactive after RD cycle)

    WAIT FOR 100 ns;

    wtnRXF <= '0';	-- for test of locking

    WAIT; -- wait forever

    -- don't do below - plenty of offset when the loop wraps ...
    -- let's see what happens in the next 100 ns:
    -- WAIT for 100 ns;


  END PROCESS ft245_read_trigger_sim;


  -- simulate write process:
  -- instead of writing a state machine,
  -- here we merely need to control mE to 'trigger' a write?!
  -- but also, need to control nTXE
  ft245_write_trigger_sim: PROCESS
  BEGIN
    -- startup values:
    wtnTXE <= '0';  -- prepare nTXE high (Transmit FIFO ready for write data )
    -- no buffer signals here
    -- wtmE <= '1';    -- buffer is empty
    -- wtmF <= '0';    -- buffer is not full
    -- processFT245if should have set WR to 0 as well..


    -- WAIT for OFFSET;  -- wait out the clock offset -- no need here

    FOR ix IN 1 TO 10 LOOP -- for test of locking

      -- sometime after this, processFT245if should raise WR, possibly present data
      -- we should wait for WR low..
      -- WAIT until falling_edge(wtWR);	--wrong syntax!
      WAIT until wtWR = '0';
      WAIT until wtWR = '1';	-- wait for FPGA to start write (with WR high)
      WAIT until wtWR = '0';	-- wait for FPGA to end write (with WR low)


      -- WR went low, now (FT245) can raise nTXE,
      --   and wait out T12=80 ns;
      wtnTXE <= '1';
      WAIT for 80 ns;

      -- now (FT245) can lower nTXE
      wtnTXE <= '0';

    END LOOP;

    WAIT FOR 200 ns;

    wtnTXE <= '0';

    WAIT; -- wait forever, for test of locking

    -- then we just loop
  END PROCESS ft245_write_trigger_sim;


  -- END PROCESSES (STATE MACHINES) CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END testbench_arch;
-- END ARCHITECTURE -----------------------------
