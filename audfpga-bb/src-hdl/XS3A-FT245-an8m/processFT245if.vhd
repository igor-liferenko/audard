-------------------------------------------------------------------------------
-- processFT245if.vhd
-- Digial Duplex Loopback example for Xilinx S3A with FT245;
--    attempt for interleaved read/write...
--
-- FTDI read and write process as state machines..
----------------------------------------------------------------------------------
-- based on usb_jtag/device/cpld/jtag_logic.vhd by Kolja Waschk, ixo.de
-- Serial/Parallel converter, interfacing JTAG chain with FTDI FT245BM
-- -- (from http://www.ixo.de/info/usb_jtag/usb_jtag-20080705-1200.zip)
-- -- (jtag_logic.vhd can be seen on http://tigerwang202.blogbus.com/files/12360479200.vhd)
-------------------------------------------------------------------------------
-- Create Date:    18:59:28 10/17/2009
-- This file represents an interface engine - how the FPGA should behave in order to work with FT245
-- The behaviour of the FT245 chip is in testbench engine - (..._tbw.vhd)
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

-- textio cannot be used in synthesis, skip
-- synthesis translate_off
  use IEEE.Std_Logic_TextIO.all;
library Std;
  use STD.TextIO.all;
-- synthesis translate_on


-- ENTITY ---------------------------------------
-- declaration of actual 'electric ports' of this
--   FPGA 'core' (FT245 process interface)...

ENTITY processFT245if IS
  -- some parameters
  GENERIC(
    T7 : real := 50.0E-09; -- : time := 50 ns ;
    T8 : real := 50.0E-09; -- : time := 50 ns ;
    -- note, ISE reports cannot show small E-09 numbers;
    --   (shown as zeroes)
    -- for debug, best to define them 'in nanoseconds'
    -- T12 : real := 80.0E-09; -- : time := 80 ns ;
    T12 : real := 80.0;

    T1 : real := 50.0;
    T6 : real := 80.0; -- under control of FT245, anyway
    T2p : real := 50.0;

    clkfreq : natural := 50000000
  );
  PORT(
    CLK : IN STD_LOGIC;         -- external 50 MHz oscillator
    -- OKtoREAD : IN STD_LOGIC = '0';  -- whether to execute next read - to allow
                                --   time for a consecutive write;
                                -- based on fifo's aempty
                                -- = 'Z'; default value; but "parse error, unexpected EQ, expecting SEMICOLON or CLOSEPAR", also for 0
                                -- screw it, as its unused, remove

    nRXF  : IN STD_LOGIC;                       -- FT245's nRXF
    nTXE  : IN STD_LOGIC;                       -- FT245's nTXE
    nRD   : OUT STD_LOGIC;                      -- FT245's nRD
    WR    : OUT STD_LOGIC;                      -- FT245's WR
    -- D     : INOUT STD_LOGIC_VECTOR(7 downto 0); -- FT245's D[7..0]

    DoutR : OUT STD_LOGIC;	    -- Data Out Ready
    DinR  : OUT STD_LOGIC;	    -- Data In Ready (now it's output, as control signal - read enable)
    -- Din   : IN STD_LOGIC_VECTOR(7 downto 0);  -- port where data to FT245 is piped
    -- Dout  : OUT STD_LOGIC_VECTOR(7 downto 0)  -- port where data from FT245 is read

    InCdTck : IN STD_LOGIC;	    -- Input CD tick (from PWM gen)
    mF : IN STD_LOGIC   -- memory full - from fifo buffer
    ; -- pre-last semicolon
    mE : IN STD_LOGIC   -- memory empty - from fifo buffer

    -- debug
    -- DBG_state       : OUT STD_LOGIC_VECTOR(1 downto 0)
    -- DBG_stcnt       : OUT STD_LOGIC_VECTOR(1 downto 0)
  );
END processFT245if;


-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE spec OF processFT245if IS

ATTRIBUTE keep_hierarchy : STRING;
ATTRIBUTE keep_hierarchy of spec: ARCHITECTURE IS "yes";

  -- DECLARE COMPONENTS =========================
  -- not using any here

  -- DECLARE STATES for STATE MACHINES ==========

  TYPE states_rd IS
  (
    wait_for_nRXF_low,
    read_data_from_ft,
    wait_nRD_expire,  -- wait out T1
    wait_nRXF_expire  -- both wait for RXF# to go down (T6),
                      -- and wait out the 50 ns (rest of T2 after T6)
  );

  TYPE states_wr IS
  (
    wait_for_CD_tick,
    wait_for_nTXE_low,
    fetch_wrdata_from_fifo,
    alert_write_data_to_ft,
    wait_WR_expire
  );

  ATTRIBUTE ENUM_ENCODING: STRING;    -- still reoptimization
  ATTRIBUTE SIGNAL_ENCODING: STRING;  -- still reoptimization
  ATTRIBUTE fsm_encoding : STRING;
  ATTRIBUTE fsm_extract : STRING;
  ATTRIBUTE keep : STRING;
  ATTRIBUTE s: STRING; -- "SAVE NET FLAG"

  ATTRIBUTE SIGNAL_ENCODING OF states_rd: TYPE IS "user";
  ATTRIBUTE ENUM_ENCODING OF states_rd: TYPE IS
    -- "000 001 010 011 100 101";
    "00 01 10 11";

  ATTRIBUTE SIGNAL_ENCODING OF states_wr: TYPE IS "user";
  ATTRIBUTE ENUM_ENCODING OF states_wr: TYPE IS
    -- "0000 0001 0010 0011 0100 0101 0110 0111 1000";
    -- "00 01 10 11";
    "000 001 010 011 100";

  -- init state vars
  SIGNAL state_rd, next_state_rd: states_rd := wait_for_nRXF_low;
  SIGNAL state_wr, next_state_wr: states_wr := wait_for_nTXE_low;

  -- "signalize" state_wr (as std_logic wire) - so to use it in fsm for read
  -- we already know 4 states - so 2 bits
  -- SIGNAL state_wr_SIG: STD_LOGIC_VECTOR(1 downto 0) := "ZZ";

  ATTRIBUTE fsm_extract OF state_rd: SIGNAL IS "yes";       -- no dice
  ATTRIBUTE fsm_extract OF next_state_rd: SIGNAL IS "yes";
  ATTRIBUTE keep of state_rd : SIGNAL IS "true" ;

  -- END DECLARE STATES for STATE MACHINES ======


  -- DECLARE REGISTERS ==========================

  constant T7steps : integer := integer(ieee.math_real.floor( real(T7) / real(1.0/real(clkfreq)) ) ) ;
  constant T8steps : integer := integer(ieee.math_real.floor( real(T8) / real(1.0/real(clkfreq)) ) ) ;
  constant T12steps : integer := integer(ieee.math_real.floor( real(T12)*1.0E-09 / real(1.0/real(clkfreq))) ) ;
  constant T1steps : integer := integer(ieee.math_real.floor( real(T1)*1.0E-09 / real(1.0/real(clkfreq))) ) ;
  constant T2psteps : integer := integer(ieee.math_real.floor( real(T2p)*1.0E-09 / real(1.0/real(clkfreq))) ) ;

  -- synthesis translate_off
  -- at this point, "parse error, unexpected REPORT" for both synth and sim!
  -- report("integer is "& integer'image(T12steps)); --report "T12steps " & T12steps;
  -- synthesis translate_on

  -- conversion ?!
  -- [http://www.edaboard.com/thread185565.html VHDL: Predicting how many bits an expression is made of]
  -- cannot find bit width of the T12steps value at this point;
  -- below generates: 'parse error, unexpected IDENTIFIER'
  -- SIGNAL cnt_WR : std_logic_vector(2 downto 0);
  -- cnt_WR := std_logic_vector(to_unsigned(T12steps, cnt_WR'length)) ; -- , integer(T12steps)'length
  -- try simply define cnt_WR as integer instead? and hope length will be automatically allocated?
  -- .. if just 'integer', can end up to -1... try define it as range;
  -- -- SIGNAL cnt_WR : integer range 0 to T12steps := T12steps;
  -- yet integer doesn't have 'length, so reuse def of std_logic_vector?:
  -- -- SIGNAL cnt_WR : array ( NATURAL range 0 to T12steps ) of STD_LOGIC := T12steps;
  -- nope; 'array' seemingly can only be used with 'type' (parse error, unexpected ARRAY)
  -- so as conversion to std_logic_vector with auto inference of bit width is problematic,
  --   go back to just ranged integer for now (bitwidth is log2 anyways) - shouldn't be a problem w synth?!
  -- well, even ranging like this, causes the counter to eventually go to -1,
  --   so must limit it manually (below)
  SIGNAL cnt_WR : NATURAL range 0 to T12steps := T12steps;
  ATTRIBUTE keep of cnt_WR : SIGNAL IS "true" ; -- also this?

  -- T1steps should be = T2psteps, can reuse this counter:
  SIGNAL cnt_RD : NATURAL range 0 to T1steps := T1steps;
  -- even with a proper read fsm, cnt_RD *MUST* be given 'keep';
  -- else it (apparently) gets 'optimized away'; and duplex streaming results with corrupt data!
  -- with it kept, all may look good (but also corrupt)
  ATTRIBUTE keep of cnt_RD : SIGNAL IS "true" ;

  -- null count (not really needed for number integer types)
  -- constant cnt_NULL : std_logic_vector := std_logic_vector(to_unsigned(0, T12steps'length)) ;
  constant cnt_NULL : integer := 0 ;

  -- initialize the signals - else the synthesizer optimizes them away!

  SIGNAL wDoutR : STD_LOGIC := '0'; -- 'data out ready wire'
  SIGNAL wDinR  : STD_LOGIC := '0'; -- 'data in ready wire'
  SIGNAL fFULL  : STD_LOGIC := '0'; -- 'fifo full wire'
  SIGNAL fEMPTY : STD_LOGIC := '0'; -- 'fifo empty wire'

  SIGNAL wInCdTck : STD_LOGIC := '0'; -- 'in CD tick wire'

  -- assign to this register: 'memory' rather than 'wire'
  --  (else we cannot set init value)
  SIGNAL nRD_mem: STD_LOGIC := '1';
  SIGNAL WR_mem: STD_LOGIC := '0';

  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map - none here)
-- -- and write all applicable state machines on this level
BEGIN

  -- initializations:

  -- synthesis translate_off
  -- at this point, "parse error, unexpected REPORT" for both synth and sim!
  -- report("integer is "& integer'image(T12steps)); --report "T12steps " & T12steps;
  -- synthesis translate_on

  -- signals to membuf (same sigs to FT245 for now)
  DoutR <= wDoutR;  -- map pin to signal
                    -- (will multi-source, if
                    -- DoutR is assigned to elsewhere);
  DinR <= wDinR;

  -- signals to FT245 that FPGA controls
  nRD <= nRD_mem;
  WR <=  WR_mem; -- not(WR_mem);

  -- in CD tick
  wInCdTck <= InCdTck ;

  -- state_wr_SIG <= std_logic_vector(to_unsigned(states_wr'pos(state_wr), state_wr_SIG'length));

  -- DBG_state <= std_logic_vector(to_unsigned(states_rd'pos(state_rd), DBG_state'length)); -- <= state_rd; "Type of DBG_state is incompatible with type of state_rd."; to_unsigned(state_rd): to_unsigned can not have such operands in this context.
  -- DBG_stcnt <= std_logic_vector(to_unsigned(cnt_RD, DBG_state'length));


  -- assign pin directly to hiZ, as we're not using it here
  -- OKtoREAD <= 'Z'; -- input pin, cannot


  -- instances of components, and their wiring (port maps)...
  -- ... none here


  -- STATE MACHINES CODE =========

  -- attempt to debug
  -- hopefully, this will not run repeatedly in a sim,
  -- as it is not clocked - but it generates, during synth:
  -- WARNING:HDLParsers:1406 - No sensitivity list and no wait in the process
  -- (but otherwise, show INFO in Console report during synthesis)
  -- (and even if synthesizer complains, allowing it to see the WAIT will cause Xst:841!)
  -- * Just a plain definition (without wait) will make it loop and hog simulation
  -- * defining a wait time causes the statement to loop with that wait time
  -- so for once only, wait forever
  myinitdebug: PROCESS
  BEGIN
    report("T12steps is "& integer'image(T12steps)); --report "T12steps " & T12steps;
    report("T7steps is "& integer'image(T7steps));
    report("T8steps is "& integer'image(T8steps));
    report("T1steps is "& integer'image(T1steps));
    report("T2psteps is "& integer'image(T2psteps));
    -- integers may have 'range instead of 'length? NO
    -- " Prefix of attribute 'range must be an array object."
    -- so ignore this printout, and hope compiler truncates bit width
    --report("cnt_WR'length is "& integer'image(cnt_WR'range));

    -- synthesis translate_off
    -- put a wait statement here for simulator:
    WAIT; -- without argument, should wait forever
    -- synthesis translate_on

  END PROCESS myinitdebug;


  -- write process state machine: from membuf to ft245
  -- remember incdtck in sensitivity list!
  sm_wr: PROCESS(state_wr, nTXE, mE, mF, cnt_WR, wInCdTck) -- combinatorial process part
  BEGIN
    -- at this point, report passes even for synth!!
    -- report("integer is "& integer'image(T12steps)); --report "T12steps " & T12steps;

    CASE state_wr IS

      WHEN wait_for_CD_tick =>
        IF wInCdTck = '1' THEN          -- we are triggered by CD rate tick
          next_state_wr <= wait_for_nTXE_low;
        ELSE
          next_state_wr <= wait_for_CD_tick;
        END IF;

      WHEN wait_for_nTXE_low =>
        IF mF = '0' AND mE = '0' THEN   -- membuf is not full, nor empty
          IF cnt_WR = T7steps THEN      -- in this case, we've just exited a write - wait (delay)
            -- cnt_WR <= 0;        -- must reset counter from here, but cannot - multisource (below)
            next_state_wr <= wait_for_nTXE_low;
          ELSE                          -- we are not immediately after a write,
                                        -- so react appropriately here
            IF nTXE = '0' THEN          -- TXE# is gone active low
              next_state_wr <= fetch_wrdata_from_fifo;
            ELSE
              next_state_wr <= wait_for_nTXE_low;
            END IF;
          END IF;
        ELSE                            -- membuf either full, or empty
          IF mE = '1' THEN              -- if membuf empty
            next_state_wr <= wait_for_nTXE_low; -- loop in nTXE, waiting for transmittion
          ELSE
            next_state_wr <= wait_for_CD_tick; -- maybe best to exit state here
          END IF;
        END IF;

      WHEN fetch_wrdata_from_fifo =>
        next_state_wr <= alert_write_data_to_ft;

      WHEN alert_write_data_to_ft =>
        next_state_wr <= wait_WR_expire;

      WHEN wait_WR_expire =>
        IF cnt_WR = cnt_NULL THEN
          next_state_wr <= wait_for_CD_tick;
        ELSE
          next_state_wr <= wait_WR_expire;
        END IF;

    END CASE;
  END PROCESS sm_wr;

  -- write process state machine: from membuf to ft245
  out_sm_wr: PROCESS(CLK) -- synchronous process part -- , state_wr
  BEGIN
    IF CLK = '1' AND CLK'event THEN -- posedge??

      IF state_wr = wait_for_CD_tick THEN
        WR_mem <= '0';
        wDoutR <= '0';
      END IF;

      IF state_wr = wait_for_nTXE_low THEN
        WR_mem <= '0';
        wDoutR <= '0';
        -- this signalling - so we delay a clock cycle:
        IF cnt_WR = T7steps THEN -- if signalled, reset
          cnt_WR <= 0; -- must reset counter from here,
        END IF;
      END IF;

      IF state_wr = fetch_wrdata_from_fifo THEN
        -- do NOT switch the bidir bus yet! ;
        -- fetching data from RAM will take a clock cycle;
        -- so if we write to bidir bus already here;
        -- we will allow the transition to be seen on the bus!
        -- WR_mem <= '1';        -- WR high should switch the
                              -- bidirectional bus; and have data from fifo
        wDoutR <= '1';        -- DoutR changes the same as WR;
                              -- gives signal to fifo
        -- cnt_WR <= T7steps-1;  -- init write timeout counter -- not here
      END IF;

      IF state_wr = alert_write_data_to_ft THEN
        -- at this point, we expect data to be fetched
        -- from RAM (membuf fifo) to the write register,
        -- so alert FT and switch the bus
        WR_mem <= '1';        -- WR high should switch the
                              -- bidirectional bus; and have data from fifo
        cnt_WR <= T7steps-1;  -- init write timeout counter
        wDoutR <= '0';        -- also cancel DoutR - to prevent multiclocking of RAM
                              -- (and unnecesarry spill of bytes) - it's anyways WR that should hold
      END IF;

      IF state_wr = wait_WR_expire THEN
        IF cnt_WR < T7steps THEN  -- is set in previous state
          IF cnt_WR > 0 THEN
            cnt_WR <= cnt_WR-1;
          ELSE  -- counter down to 0, raise it to T7steps as a signal
            cnt_WR <= T7steps;
          END IF;
        END IF;
      END IF;

      state_wr <= next_state_wr;
    END IF;
  END PROCESS out_sm_wr;


  -- read process state machine: from ft245 to membuf
  sm_rd: PROCESS(state_rd, nRXF, mE, mF, cnt_RD, state_wr, nTXE) -- combinatorial process part --
  BEGIN
    CASE state_rd IS

      WHEN wait_for_nRXF_low =>
        IF mF = '0' THEN        -- membuf is not full
          IF nRXF = '0' THEN    -- FT245 signals there is something to be read
            next_state_rd <= read_data_from_ft;
          ELSE
            next_state_rd <= wait_for_nRXF_low;
          END IF;
        ELSE -- don't forget, else we'll infer latch instead of fsm!
          next_state_rd <= wait_for_nRXF_low;
        END IF;

      WHEN read_data_from_ft =>
        next_state_rd <= wait_nRD_expire;

      WHEN wait_nRD_expire =>
        IF cnt_RD = cnt_NULL THEN
          next_state_rd <= wait_nRXF_expire;
        ELSE
          next_state_rd <= wait_nRD_expire;
        END IF;

      WHEN wait_nRXF_expire =>
        IF nRXF = '1' THEN
          next_state_rd <= wait_nRXF_expire;
        ELSE
          IF cnt_RD = T2psteps THEN -- delay signal, go back in this state
            next_state_rd <= wait_nRXF_expire;
          ELSE
            IF cnt_RD = cnt_NULL THEN
              -- only go to read data if a write is not currently active (delay); NOT (state_wr = wait_wr_expire)
              -- IF ( (NOT (state_wr_SIG = std_logic_vector(to_unsigned(states_wr'pos(wait_wr_expire), state_wr_SIG'length)) )) AND (NOT (nTXE = '1')) ) THEN
              IF ( (NOT (state_wr = wait_wr_expire)) AND (NOT (nTXE = '1')) ) THEN
                -- here nRXF = '0', so more data ready for read
                -- if we go next to wait_for_nRXF_low, we'll have 20 extra ns
                -- but, as nRXF = '0', may as well go direct to read_data_from_ft
                -- along with counter expire, we should have some
                -- 3 clock cycles @ 20 ns = 60 ns (T2p) over T6 (which = T2) ..
                next_state_rd <= read_data_from_ft;
              ELSE
                next_state_rd <= wait_nRXF_expire; -- must specify this - else latch instead of fsm!
              END IF;
            ELSE
              next_state_rd <= wait_nRXF_expire;
            END IF;
          END IF;
        END IF;

    END CASE;
  END PROCESS sm_rd;

  -- read process state machine: from ft245 to membuf
  out_sm_rd: PROCESS(CLK) -- synchronous process part -- , state_rd, nRXF
  BEGIN
    IF CLK = '1' AND CLK'event THEN -- posedge??

      IF state_rd = wait_for_nRXF_low THEN
        nRD_mem <= '1';   -- inactive high
        wDinR <= '0';
        -- this signalling - so we delay a clock cycle:
        IF cnt_RD = T1steps THEN -- if signalled, reset
          cnt_RD <= 0; -- must reset counter from here,
        END IF;
      END IF;

      IF state_rd = read_data_from_ft THEN
        nRD_mem <= '0';       -- RD# low should switch the
                              -- bidirectional bus; and have data from FT245
        -- again, do not give signal to FIFO now;
        -- at this time, the bidir bus may still be switching;
        -- and we may record bad values?!
        -- wDinR <= '1';         -- DinR changes the same as nRD_mem; (not anymore)
                              -- gives signal to fifo
        cnt_RD <= T1steps;    -- init read timeout counter
                              -- 2x20 < 50 ns; so don't use T1steps-1,
                              -- use full T1steps
      END IF;

      IF state_rd = wait_nRD_expire THEN
        -- IF cnt_RD < T1steps THEN -- is set in previous state
                                    -- no need if using full T1steps
          IF cnt_RD > 0 THEN
            cnt_RD <= cnt_RD-1;
            wDinR <= '1';   -- give signal to fifo to record here;
                            -- hopefully, at this point the bidir bus
                            -- has switched, and we have valid data
          ELSE  -- counter down to 0, raise it to T2psteps-1 as init for next
            cnt_RD <= T2psteps;     -- actually, to T2psteps as delay signal
            -- and, reset signals here
            nRD_mem <= '1';   -- inactive high
            wDinR <= '0';
          END IF;
        -- END IF;
      END IF;

      IF state_rd = wait_nRXF_expire THEN
        IF cnt_RD < T2psteps THEN   -- is set in previous (now this) state
          IF nRXF = '0' THEN        -- only when RXF had gone down (which
                                    -- should be tested first after delay)
            IF cnt_RD > 0 THEN
              cnt_RD <= cnt_RD-1;
            ELSE  -- counter down to 0, raise it to T1steps as a signal
              -- hold the cnt on 0 if still writing (only signal after nTXE goes down)
              IF ( (NOT (nTXE = '1')) ) THEN
                cnt_RD <= T1steps;
              END IF;
            END IF;
          END IF;
        ELSE    -- we expect cnt_RD = T2psteps here (as delay signal)
          cnt_RD <= T2psteps - 1;
        END IF;
      END IF;

      state_rd <= next_state_rd;
    END IF;
  END PROCESS out_sm_rd;

  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END spec;
-- END ARCHITECTURE -----------------------------
