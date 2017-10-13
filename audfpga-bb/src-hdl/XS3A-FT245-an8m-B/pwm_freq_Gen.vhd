-------------------------------------------------------------------------------
-- pwm_freq_Gen.vhd
-- frequency generator for XS3A_FT245_an8m;
-- generates 'audio interrupt' at CD Rate (44130.6 Hz) and PWM rate (97656.2 Hz)
-- since the counters are here, may as well generate PWM..
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
  -- use IEEE.STD_LOGIC_ARITH.ALL;    -- DO NOT USE!
  -- use IEEE.STD_LOGIC_UNSIGNED.ALL; -- DO NOT USE!
  use IEEE.NUMERIC_STD.ALL;
  use IEEE.MATH_REAL.ALL;

-- textio cannot be used in synthesis, skip using attribute translate_off:
-- synthesis translate_off
  use IEEE.Std_Logic_TextIO.all;
library Std;
  use STD.TextIO.all;
-- synthesis translate_on


-- ENTITY ---------------------------------------
-- declaration of actual 'electric ports' of this
--   FPGA 'core' (frequency 'interrupt' generator)...

ENTITY pwm_freq_Gen IS
  -- some parameters
  GENERIC(
    clkfreq   : natural := 50000000;  -- Hz
    cd_rate   : natural := 44100;     -- Hz
    pwm_bits  : natural := 8          -- bits of resulution
  );
  PORT(
    CLK : IN STD_LOGIC;         -- external 50 MHz oscillator
    rst : IN STD_LOGIC;         -- added reset

    pData_In_PWM  : IN STD_LOGIC_VECTOR(pwm_bits-1 downto 0);
    pRead_Data_In : IN STD_LOGIC;

    pCD_Rate_Tick  : OUT STD_LOGIC;
    pPWM_Rate_Tick  : OUT STD_LOGIC;

    pPWM_Out   : OUT STD_LOGIC

  );
END pwm_freq_Gen;


-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE spec OF pwm_freq_Gen IS

ATTRIBUTE keep_hierarchy : STRING;
ATTRIBUTE keep_hierarchy of spec: ARCHITECTURE IS "yes";

  -- DECLARE COMPONENTS =========================
  -- not using any here

  -- DECLARE STATES for STATE MACHINES ==========

  TYPE states_cntr IS
  (
    reset_cntr,
    count_cntr
  );

  ATTRIBUTE ENUM_ENCODING: STRING;    -- still reoptimization
  ATTRIBUTE SIGNAL_ENCODING: STRING;  -- still reoptimization
  ATTRIBUTE keep : STRING;
  ATTRIBUTE s: STRING; -- "SAVE NET FLAG"

  ATTRIBUTE SIGNAL_ENCODING OF states_cntr: TYPE IS "user";
  ATTRIBUTE ENUM_ENCODING OF states_cntr: TYPE IS
    -- "000 001 010 011 100 101";
    "0 1";

  -- init state vars
  SIGNAL state_cnt_cd, next_state_cnt_cd: states_cntr := reset_cntr;
  SIGNAL state_cnt_pwm, next_state_cnt_pwm: states_cntr := reset_cntr;

  -- END DECLARE STATES for STATE MACHINES ======


  -- DECLARE REGISTERS ==========================

  constant cdrate_maxcount : integer := integer(ieee.math_real.floor( real(clkfreq) / real(cd_rate) ) ) - 1; -- should be 1133-1 = 1132
  -- http://www.edaboard.com/thread186363.html
  constant cdrate_maxcount_bits : integer := integer(ieee.math_real.ceil( ieee.math_real.log2( real(cdrate_maxcount) ) ) ) ; -- should be 11; 2^10 = 1024 < 1133
  constant pwm_levels : integer := 2**pwm_bits;
  constant pwmrate_maxcount : integer := 2**pwm_bits-1;


  SIGNAL cnt_CD : NATURAL range 0 to cdrate_maxcount:= cdrate_maxcount;
  ATTRIBUTE keep of cnt_CD : SIGNAL IS "true" ;

  SIGNAL cnt_PWM : NATURAL range 0 to pwmrate_maxcount:= pwmrate_maxcount;
  ATTRIBUTE keep of cnt_PWM : SIGNAL IS "true" ;


  -- initialize the signals - else the synthesizer optimizes them away!

  SIGNAL wCD_Rate_Tick  : STD_LOGIC := '0'; --
  SIGNAL wPWM_Rate_Tick : STD_LOGIC := '0'; --
  SIGNAL PWM_SlowToggle : STD_LOGIC := '0'; -- toggle to slow down PWM, so it uses 512 clock cycles, yet still counts up to 256..
  SIGNAL wPWM_Out  : STD_LOGIC := '0'; --


  -- SIGNAL PWM_OC_Reg: STD_LOGIC_VECTOR(pwm_bits-1 downto 0) := (others => '0');
  SIGNAL PWM_OC_Reg: NATURAL range 0 to pwmrate_maxcount:= pwmrate_maxcount;

  SIGNAL wRead_Data_In  : STD_LOGIC := '0'; --
  SIGNAL In_Data_Reg: NATURAL range 0 to pwmrate_maxcount:= pwmrate_maxcount;

  SIGNAL am_not_inited  : STD_LOGIC := '1'; -- to delay operation until very first reset
  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map - none here)
-- -- and write all applicable state machines on this level
BEGIN

  -- initializations:

  -- map signal to pin
  pCD_Rate_Tick <= wCD_Rate_Tick;
  pPWM_Rate_Tick <= wPWM_Rate_Tick;
  pPWM_Out <= wPWM_Out;

  -- map pin to signal
  wRead_Data_In <= pRead_Data_In;


  -- instances of components, and their wiring (port maps)...
  -- ... none here


  -- STATE MACHINES CODE =========

  -- attempt to debug
  myinitdebug: PROCESS
  BEGIN
    report("cdrate_maxcount is "& integer'image(cdrate_maxcount)); --report "T12steps " & T12steps;
    report("cdrate_maxcount_bits is "& integer'image(cdrate_maxcount_bits));
    report("pwm_levels is "& integer'image(pwm_levels));
    report("pwmrate_maxcount is "& integer'image(pwmrate_maxcount));

    -- synthesis translate_off
    -- put a wait statement here for simulator:
    WAIT; -- without argument, should wait forever
    -- synthesis translate_on

  END PROCESS myinitdebug;


  -- cd rate counter state machine
  -- must have the cnt_ in sensitivity list!
  sm_cnt_cd: PROCESS(state_cnt_cd, cnt_CD) -- combinatorial process part
  BEGIN
    -- at this point, report passes even for synth!!
    -- report("integer is "& integer'image(T12steps)); --report "T12steps " & T12steps;

    CASE state_cnt_cd IS

      WHEN reset_cntr =>
        next_state_cnt_cd <= count_cntr;

      WHEN count_cntr =>
        IF cnt_CD >= natural(cdrate_maxcount) THEN
          next_state_cnt_cd <= reset_cntr;
        ELSE
          next_state_cnt_cd <= count_cntr;
        END IF;

    END CASE;
  END PROCESS sm_cnt_cd;

  -- cd rate counter state machine
  out_sm_cnt_cd: PROCESS(CLK,rst,am_not_inited) -- synchronous process part -- , state_cnt_cd
  BEGIN
    IF rst = '1' THEN
      state_cnt_cd <= reset_cntr;
      -- only here set - but setting it here infers a latch (doesn't depend on clock then!
      IF rising_edge(CLK) THEN
        IF am_not_inited = '1' THEN
          am_not_inited <= '0';
        END IF;
      END IF;
    ELSIF am_not_inited = '1' THEN
      state_cnt_cd <= reset_cntr;
    ELSIF CLK = '1' AND CLK'event THEN -- posedge??

      IF state_cnt_cd = reset_cntr THEN
        cnt_CD <= 0;
        wCD_Rate_Tick <= '1';
      END IF;

      IF state_cnt_cd = count_cntr THEN
        cnt_CD <= cnt_CD+1;
        wCD_Rate_Tick <= '0';
      END IF;

      state_cnt_cd <= next_state_cnt_cd;
    END IF;
  END PROCESS out_sm_cnt_cd;


  -- pwm rate counter state machine
  -- must have the cnt_ in sensitivity list!
  sm_cnt_pwm: PROCESS(state_cnt_pwm, cnt_PWM) -- combinatorial process part
  BEGIN
    -- at this point, report passes even for synth!!
    -- report("integer is "& integer'image(T12steps)); --report "T12steps " & T12steps;

    CASE state_cnt_pwm IS

      WHEN reset_cntr =>
        next_state_cnt_pwm <= count_cntr;

      WHEN count_cntr =>
        IF cnt_PWM >= natural(pwmrate_maxcount) THEN
          next_state_cnt_pwm <= reset_cntr;
        ELSE
          next_state_cnt_pwm <= count_cntr;
        END IF;

    END CASE;
  END PROCESS sm_cnt_pwm;

  -- pwm rate counter state machine
  out_sm_cnt_pwm: PROCESS(CLK,rst,am_not_inited) -- synchronous process part -- , state_cnt_pwm
  BEGIN
    IF rst = '1' THEN
      state_cnt_pwm <= reset_cntr;
    ELSIF am_not_inited = '1' THEN
      state_cnt_pwm <= reset_cntr;
    ELSIF CLK = '1' AND CLK'event THEN -- posedge??

      IF state_cnt_pwm = reset_cntr THEN
        cnt_PWM <= 0;
        wPWM_Rate_Tick <= '1';
        -- sample into OC register here (temp for now)
        -- PWM_OC_Reg <= cnt_CD(pwm_bits-1 downto 0); -- Wrong slice type for cnt_CD.
        -- PWM_OC_Reg <= std_logic_vector(to_unsigned(cnt_CD, cdrate_maxcount_bits)): type conversion std_logic_vector is not allowed as a prefix for an slice name.
        -- PWM_OC_Reg <= cnt_CD MOD pwm_levels; -- just for test
        -- at each PWM tick, re-sample the In_Data_Reg
        PWM_OC_Reg <= In_Data_Reg;
        wPWM_Out <= '1';
      END IF;

      IF state_cnt_pwm = count_cntr THEN
        -- slow down using the toggle
        PWM_SlowToggle <= NOT (PWM_SlowToggle);
        IF PWM_SlowToggle = '1' THEN
          cnt_PWM <= cnt_PWM+1;
        END IF;
        IF cnt_PWM < PWM_OC_Reg THEN
          wPWM_Out <= '1';
        ELSE
          wPWM_Out <= '0';
        END IF;
        wPWM_Rate_Tick <= '0';
      END IF;

      state_cnt_pwm <= next_state_cnt_pwm;
    END IF;
  END PROCESS out_sm_cnt_pwm;


  -- input data handler (clocked) flip flop/latch
  idh_in: PROCESS(CLK) -- synchronous process part --
  BEGIN
    IF CLK = '1' AND CLK'event THEN -- posedge??

      IF wRead_Data_In = '1' THEN
        In_Data_Reg <= to_integer(unsigned(pData_In_PWM));
      END IF;

    END IF;
  END PROCESS idh_in;

  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END spec;
-- END ARCHITECTURE -----------------------------
