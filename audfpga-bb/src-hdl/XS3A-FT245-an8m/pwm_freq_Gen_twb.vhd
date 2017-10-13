-------------------------------------------------------------------------------
-- pwm_freq_Gen_twb.vhd
-- This file is a testbench engine - that represents (and
--   tries to simulate) the behaviour of FTDI FT245 chip.
-- The behaviour of the *FPGA interface* (toward the
--   FT245 chip) is in pwm_freq_Gen.vhd
-- Here we try to test only the _read_ part of process
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
ENTITY pwm_freq_Gen_twb IS
  -- some parameters, maybe?
  GENERIC(
    clkfreq   : natural := 50000000;  -- Hz
    cd_rate   : natural := 44100;     -- Hz
    pwm_bits  : natural := 8          -- bits of resulution
  );
END pwm_freq_Gen_twb;

ARCHITECTURE testbench_arch OF pwm_freq_Gen_twb IS
  FILE RESULTS: TEXT OPEN WRITE_MODE IS "pwm_freq_Gen_twb-results.txt";

  -- the COMPONENT defined below, is the component
  --   that this testbench will apply to (interface with)
  --   a.k.a the UUT/DUT (unit/device under test)
  --   (UUT also needs to be specified after BEGIN)
  COMPONENT pwm_freq_Gen
    PORT(
    CLK : IN STD_LOGIC;         -- external 50 MHz oscillator

    pData_In_PWM  : IN STD_LOGIC_VECTOR(pwm_bits-1 downto 0);
    pRead_Data_In : IN STD_LOGIC;

    pCD_Rate_Tick  : OUT STD_LOGIC;
    pPWM_Rate_Tick  : OUT STD_LOGIC;

    pPWM_Out   : OUT STD_LOGIC
    );
  END COMPONENT;


   -- DECLARE REGISTERS ==========================

  constant pwmrate_maxcount : integer := 2**pwm_bits-1;

  -- 'wires'
  -- we need to handle both inputs and outputs of UUT here
  SIGNAL wtCLK : std_logic := '0';

  SIGNAL wCD_Rate_Tick : std_logic := 'Z';
  SIGNAL wPWM_Rate_Tick : std_logic := 'Z';
  SIGNAL wRead_Data_In : std_logic := 'Z';

  -- SIGNAL Data_Sim: NATURAL range 0 to pwmrate_maxcount:= pwmrate_maxcount;
  SIGNAL Data_Sim: STD_LOGIC_VECTOR(pwm_bits-1 downto 0) := (others => '1');
  -- others bits MUST be inited for STD_LOGIC_VECTOR;
  -- else: "WARNING:Simulator:29 - at 22.675 us: Warning: There is an 'U'|'X'|'W'|'Z'|'-' in an arithmetic operand, the result will be 'X'(es)."


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
  UUT : pwm_freq_Gen
  PORT MAP (
    CLK   => wtCLK,
    pRead_Data_In => wRead_Data_In,
    pData_In_PWM => Data_Sim,
    pCD_Rate_Tick => wCD_Rate_Tick, -- OPEN,
    pPWM_Rate_Tick  => wPWM_Rate_Tick,
    pPWM_Out => OPEN
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


  -- simulate process:
  test_sim: PROCESS
  BEGIN

    WAIT; -- wait forever

  END PROCESS test_sim;

  -- simulate data:
  test_data: PROCESS
  BEGIN

    wRead_Data_In <= '0' ;

    WAIT FOR 22675 ns; -- 1/44100

    wRead_Data_In <= '1' ;
    Data_Sim <= Data_Sim + 10 ;

    WAIT FOR PERIOD ;
    -- will loop here

  END PROCESS test_data;


  -- END PROCESSES (STATE MACHINES) CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END testbench_arch;
-- END ARCHITECTURE -----------------------------
