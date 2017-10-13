-------------------------------------------------------------------------------
-- processFT245if_wr_tbw.vhd
-- This file is a testbench engine - that represents (and
--   tries to simulate) the behaviour of FTDI FT245 chip.
-- The behaviour of the *FPGA interface* (toward the
--   FT245 chip) is in processFT245if.vhd
-- Here we try to test only the _write_ part of process
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
ENTITY processFT245if_wr_tbw IS
END processFT245if_wr_tbw;

ARCHITECTURE testbench_arch OF processFT245if_wr_tbw IS
  FILE RESULTS: TEXT OPEN WRITE_MODE IS "processFT245if_wr_tbw-results.txt";

  -- the COMPONENT defined below, is the component
  --   that this testbench will apply to (interface with)
  --   a.k.a the UUT/DUT (unit/device under test)
  --   (UUT also needs to be specified after BEGIN)
  COMPONENT processFT245if
    PORT(
      CLK : IN STD_LOGIC;         -- external 50 MHz oscillator
      OKtoREAD : IN STD_LOGIC;    -- whether to execute next read - to allow
                                  --   time for a consecutive write;
                                  -- based on fifo's aempty

      nRXF  : IN STD_LOGIC;                       -- FT245's nRXF
      nTXE  : IN STD_LOGIC;                       -- FT245's nTXE
      nRD   : OUT STD_LOGIC;                      -- FT245's nRD
      WR    : OUT STD_LOGIC;                      -- FT245's WR
      -- D     : INOUT STD_LOGIC_VECTOR(7 downto 0); -- FT245's D[7..0]

      DoutR : OUT STD_LOGIC;	    -- Data Out Ready
      DinR  : OUT STD_LOGIC;	    -- Data In Ready (now it's output, as control signal - read enable)
      -- Din   : IN STD_LOGIC_VECTOR(7 downto 0);  -- port where data to FT245 is piped
      -- Dout  : OUT STD_LOGIC_VECTOR(7 downto 0)  -- port where data from FT245 is read
      mF : IN STD_LOGIC;  -- memory full - from fifo buffer
      mE : IN STD_LOGIC   -- memory empty - from fifo buffer
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

  SIGNAL wtmF : std_logic := 'Z';
  SIGNAL wtmE : std_logic := 'Z';

  SIGNAL wtDoutR : STD_LOGIC :='0'; -- 'data out ready wire'
  SIGNAL wtDinR  : STD_LOGIC :='0'; -- 'data in ready wire'


  SIGNAL LO: STD_LOGIC :='0';

  -- clock parameters
  constant PERIODN : natural := 20; -- can be real := 20.0;
  constant PERIOD : time := PERIODN * 1 ns;
  constant DUTY_CYCLE : real := 0.5;
  constant OFFSET : time := 95 ns;

BEGIN

  -- initializations:
  LO <= '0';

  -- instances of components, and their wiring (port maps)...

  -- must define the device under test (UUT) after BEGIN, too
  UUT : processFT245if
  PORT MAP (
    CLK   => wtCLK,
    OKtoREAD => LO, -- OPEN,
    nRXF  => wtnRXF,
    nTXE  => wtnTXE,
    nRD   => wtnRD,
    WR    => wtWR,
    mF => wtmF,
    mE => wtmE,
    DoutR => wtDoutR,
    DinR  => wtDinR
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


  -- simulate write process:
  -- instead of writing a state machine,
  -- here we merely need to control mE to 'trigger' a write?!
  -- but also, need to control nTXE
  ft245_write_trigger_sim: PROCESS
  BEGIN
    -- startup values:
    wtnTXE <= '1';  -- prepare nTXE high (Transmit FIFO NOT ready to write data )
    wtmE <= '1';    -- buffer is empty
    wtmF <= '0';    -- buffer is not full
    -- processFT245if should have set WR to 0 as well..


    WAIT for OFFSET;  -- wait out the clock offset
    WAIT for 30 ns;   -- ... and 30 ns more

    wtmE <= '0';      -- now, buffer is not empty anymore

    WAIT for 10 ns;

    wtnTXE <= '0';    -- Transmit FIFO ready to write data

    -- sometime after this, processFT245if should raise WR, possibly present data
    -- we should wait for WR low..
    WAIT until falling_edge(wtWR);

    -- WR went low, now (FT245) can raise nTXE,
    --   and wait out T12=80 ns;
    wtnTXE <= '1';
    WAIT for 80 ns;

    -- now (FT245) can lower nTXE
    wtnTXE <= '0';

    -- let's see what happens in the next 100 ns:
    WAIT for 100 ns;


  END PROCESS ft245_write_trigger_sim;


  -- END PROCESSES (STATE MACHINES) CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END testbench_arch;
-- END ARCHITECTURE -----------------------------
