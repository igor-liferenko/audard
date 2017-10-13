-------------------------------------------------------------------------------
-- XS3A_FT245_an8m.vhd (B)
-- PWM (analog) reproduction & Digital Duplex Loopback example for Xilinx S3A with FT245;
--    attempt for interleaved read/write...
--
-- main file (top level design/container)
----------------------------------------------------------------------------------
-- based on http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/audfpga-bb/src-hdl/XS3A-FT245-an8m/XS3A_FT245_an8m.vhd
-- also using portions from:
-- -- http://opencores.org/project,versatile_fifo
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
-- Constraint Entry Table - http://www.xilinx.com/itp/xilinx4/data/docs/cgd/entry17.html#1027089

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.STD_LOGIC_ARITH.ALL;    -- DO NOT USE!
-- use IEEE.STD_LOGIC_UNSIGNED.ALL; -- DO NOT USE!
  use IEEE.NUMERIC_STD.ALL;


-- ENTITY ---------------------------------------
-- declaration of actual electric ports of this
--   FPGA 'core' (top level design/container)...
-- --
-- This top level container will contain inside:
-- -- the FT245 interface with duplex engine; a FIFO buffer;
-- -- startup engine; and LED drivers
--
ENTITY XS3A_FT245_an8m IS
  -- some parameters
  GENERIC(
    clkfreq   : natural := 50000000;  -- Hz
    cd_rate   : natural := 44100;     -- Hz
    pwm_bits  : natural := 8          -- bits of resulution
  );
  PORT
  (
    pgCLK : IN STD_LOGIC;						-- external 50 MHz oscillator, "global" clock
                                    -- (possibly 100 MHz with Xilinx DCM)

    -- interface pins to FT245
    pD_ft245     : INOUT STD_LOGIC_VECTOR(7 downto 0);  -- FT245's D[7..0]
    pRDn_ft245   : OUT STD_LOGIC := '0';                -- FT245's nRD (remember initval)
    pWR_ft245    : OUT STD_LOGIC := '0';								-- FT245's WR  (remember initval)
    pRXFn_ft245  : IN STD_LOGIC;                        -- FT245's nRXF
    pTXEn_ft245  : IN STD_LOGIC;                        -- FT245's nTXE
    pPWREN_ft245 : IN STD_LOGIC := 'Z';   -- FT245's PWREN
                                          -- (make it INOUT, so we put it in hi Z,
                                          -- so it don't interfere)
                                          -- (was INOUT - now IN w/ pullup) (no pullup)
                                          -- will generate a warning with Xilinx tools anyway
                                          --  if unconnected.. (Xst:647)
                                          -- just leave it and use
                                          --  message filtering in gui
                                          -- adding ":= 'Z'" prevents ERROR:HDLCompiler:432 Formal <ppwren_ft245> has no actual or default value.

    pAPWM_Out    : OUT STD_LOGIC;   -- PWM (analog) output

    -- pDBG       : OUT STD_LOGIC_VECTOR(3 downto 0); -- debug

    -- LED pins (indication)
    pLED_R     : OUT STD_LOGIC;   -- LED active on Read - simply buffered (via FF) RD or RXF, must be out too
    pLED_nTXE  : OUT STD_LOGIC   -- LED active on nTXE
    ; -- pre-last semicolon
    pLED_W     : OUT STD_LOGIC    -- LED active on Write - simply buffered (via FF) TXE or RXF

  );
END XS3A_FT245_an8m;



-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE structure OF XS3A_FT245_an8m IS

  ATTRIBUTE keep_hierarchy : STRING;
  -- ATTRIBUTE keep_hierarchy of XS3A_FT245_an8m: ENTITY IS "yes"; -- Attribute on units are only allowed on current unit.
  ATTRIBUTE keep_hierarchy of structure: ARCHITECTURE IS "yes";

  -- http://www.vhdl.org/vhdlsynth/vhdl/minmax.vhd
  function maximum ( left, right : integer) -- inputs
  return integer is
  begin  -- function max
    if LEFT > RIGHT then return LEFT;
    else return RIGHT;
    end if;
  end function maximum;

  -- DECLARE COMPONENTS =========================

  -- First, declaration of other HDL components used in-
  --   side the top-level 'XS3A_FT245_an8m' FPGA 'core':


  -- declarin' a Verilog FIFO here
  COMPONENT versatile_sd_fifo_1buf
    PORT(
      dat_i         : IN std_logic_vector(7 downto 0);
      we_i          : IN std_logic;
      re_i          : IN std_logic;
      wr_clk        : IN std_logic;
      rd_clk        : IN std_logic;
      dat_o         : OUT std_logic_vector(7 downto 0);
      fifo_full     : OUT std_logic; -- only one buffer now
      fifo_rd_lags  : OUT std_logic; --
      fifo_empty    : OUT std_logic; -- only one buffer now
      fifo_aempty   : OUT std_logic; -- async empty - should be set also whenever buffer is not empty
      rst           : IN std_logic
    );
  END COMPONENT;

  -- LED drivers - to extend the timing to be longer?
  --  else, can be modified to just act as buffers..
  COMPONENT led_drv_gate
  PORT(
      clk     : IN STD_LOGIC;  -- clock
      reset   : IN STD_LOGIC;  -- Active high, syn reset
      insig   : IN STD_LOGIC;  -- input signal to be replicated
      outled  : OUT STD_LOGIC  -- output gated signal to drive a led
  );
  END COMPONENT;

  -- PWM output, and CD/PWM rate generator
  COMPONENT pwm_freq_Gen
    PORT(
      CLK : IN STD_LOGIC;         -- external 50 MHz oscillator
      rst : IN STD_LOGIC;

      pData_In_PWM  : IN STD_LOGIC_VECTOR(pwm_bits-1 downto 0);
      pRead_Data_In : IN STD_LOGIC;

      pCD_Rate_Tick  : OUT STD_LOGIC;
      pPWM_Rate_Tick  : OUT STD_LOGIC;

      pPWM_Out   : OUT STD_LOGIC

    );
  END COMPONENT;

  -- END DECLARE COMPONENTS =====================


  -- DECLARE STATES for STATE MACHINES ==========

  TYPE init_states IS
  (
    start_init,     -- here set rst 1
    init_rst_down,  -- here set rst down
    run_main
  );
  ATTRIBUTE ENUM_ENCODING: STRING;
  ATTRIBUTE ENUM_ENCODING OF init_states: TYPE IS
    "00 01 11"; -- as in auto gray encoding
  SIGNAL istate: init_states := start_init;
  SIGNAL next_istate: init_states := start_init;

  ATTRIBUTE keep : STRING;
  ATTRIBUTE s: STRING; -- "SAVE NET FLAG"
  ATTRIBUTE clock_signal : STRING;
  ATTRIBUTE fsm_encoding: STRING;
  ATTRIBUTE fsm_extract: STRING;

  -- ##########
  -- for main FT245 interface state machine:
  type StateTypeRD is (
    wf_nRXF_L,      -- wait for nRXF low
    nRD_L_start,    -- start of nRD low
    RD_sample,      -- read - sample from FT245
    wf_nRD_expire,  -- wait for read to expire
    wf_rd_idle      -- wait for after read idle
  );
  type StateTypeWR is (
    wf_WR_start,    -- wait for write process start
    WR_H_start,     -- start write process
    wf_WR_expire,   -- wait for write to expire
    hold_WR_data,   -- hold WR data on bus, after WR deasserted
    wf_wr_idle      -- wait for after write idle
  );
  -- ? "-- enum_encoding attribute is not supported for symbolic encoding"
  -- was: shared variable - then signal; but signal will introduce double the delay, and mess up the state transitions!
  -- so back to (shared) variables - and then have them copied to signals with KEEP/S
  shared VARIABLE state_rd, next_state_rd : StateTypeRD := wf_nRXF_L;
  shared VARIABLE state_wr, next_state_wr : StateTypeWR := wf_WR_start;


  -- signal dstate_rd, dstate_wr: STD_LOGIC_VECTOR(encSize-1 DOWNTO 0) := "000";
  -- using dstate_rd/wr'length in functions causes 'impure' function warnings
  -- (using constant encSize instead is fine)
  constant encSize : integer := 3 ;

  function encodeRD ( invar : StateTypeRD) -- inputs
  return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(StateTypeRD'pos(invar), encSize));
  end function encodeRD;

  function encodeWR ( invar : StateTypeWR) -- inputs
  return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(StateTypeWR'pos(invar), encSize));
  end function encodeWR;

  -- END DECLARE STATES for STATE MACHINES ======


  -- DECLARE REGISTERS ==========================

  -- bus interface 'wires'
  --  (from out of bus interface to other components)
  SIGNAL bRXFn: STD_LOGIC :='1';
  SIGNAL bRDn : STD_LOGIC :='1';
  SIGNAL bTXEn: STD_LOGIC :='0';
  SIGNAL bWR  : STD_LOGIC :='0';
  SIGNAL bDri : STD_LOGIC_VECTOR(7 DOWNTO 0) := "ZZZZZZZZ"; -- bus data read in (in for FPGA)
  SIGNAL bDwo : STD_LOGIC_VECTOR(7 DOWNTO 0) := "ZZZZZZZZ"; -- bus data write out (out for FPGA)

  SIGNAL wDoutR : STD_LOGIC :='0'; -- 'data out ready wire'
  SIGNAL wDinR  : STD_LOGIC :='0'; -- 'data in ready wire'
  SIGNAL fFULL  : STD_LOGIC :='0'; -- 'fifo full wire' // actually, this means 'fifo exhaust': radr=wadr
  -- note: in this case, USB connection runs at 2Mbps; audio over that @ 44.1 kHz
  -- thus, rptr is always in a position to run faster than wptr - rptr always reaches the end of buffer first
  -- to avoid buffer wrap problem, added 'fifo rd full' - when rd reached end of buffer, do not ack FT's rd requests, until wptr manages to catch up (which will then reset both rptr and wptr).
  -- blocking read at fifo_rd_lags = (direction_set || direction_clr); will effectively cap usage of RAM at quarter its size
  SIGNAL fRD_LAGS  : STD_LOGIC :='0'; -- was fifo_full
  SIGNAL fEMPTY : STD_LOGIC :='1'; -- 'fifo empty wire'

  SIGNAL wCD_Rate_Tick : STD_LOGIC :='0'; -- 'CD_Rate_Tick wire'

  SIGNAL wRst : STD_LOGIC := '0'; -- 'Z'; -- startup reset 'wire' (power-on reset)
                                  -- used also for versatile fifo..
                                  -- .. which is why it SHOULDn't be inited as 0;
                                  --    otherwise it messes the first ffull (fifo_full) value to X!

  ATTRIBUTE keep of bRXFn, bRDn, bTXEn, bWR, bDri, bDwo, wDoutR, wDinR, fFULL, fRD_LAGS, fEMPTY, wRst : SIGNAL IS "true" ;
  ATTRIBUTE s of bRXFn, bRDn, bTXEn, bWR, bDri, bDwo, wDoutR, wDinR, fFULL, fRD_LAGS, fEMPTY, wRst : SIGNAL IS "true" ;
  ATTRIBUTE clock_signal of pgCLK : SIGNAL IS "yes";



  -- main FT245 process state machine
  constant numRDsteps : integer := 20 ; -- number of wait for Read steps; in clock periods
  constant numWRsteps : integer := 20 ; -- number of wait for Write steps; in clock periods

  -- numIdleStepsR/W = 20/100 is OK for raw duplex (miniFT_par) because there read/write is interleaved
  -- however, here in audio we'd get a (fast) burst of read data @200kHz, and then wr CD ticks in between @44.1kHz - so the RD delay needs to be a bit more!
  constant numIdleStepsR : integer := 200 ; -- idle state wait; clock periods
  constant numIdleStepsW : integer := 20; -- idle state wait; clock periods

  constant dlyRDsteps : integer := 2 ; -- delay steps for RD; was 2, but it locks? ok w/ 1?
  constant dlyWRsteps : integer := 3 ; -- delay steps for WR



  -- must have these as signals, local variables cannot be simmed yet
  signal sstate_rd, snext_state_rd : StateTypeRD := wf_nRXF_L;
  signal sstate_wr, snext_state_wr : StateTypeWR := wf_WR_start;
  signal scnt_RD : NATURAL range 0 to maximum(numRDsteps,numIdleStepsR) := maximum(numIdleStepsR,numRDsteps);
  signal scnt_WR : NATURAL range 0 to maximum(numWRsteps,numIdleStepsW) := maximum(numIdleStepsW,numWRsteps);

  SIGNAL dMEM : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001111"; --
  SIGNAL rdSAMPLE : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001111"; --
  SIGNAL is_d_io_tristate : STD_LOGIC := '1'; -- was: is_d_io_active
  SIGNAL rd_has_byte_sync : STD_LOGIC := '0'; -- whether it's time to perform a write
  SIGNAL wr_sent_byte_sync : STD_LOGIC := '0'; -- whether it's time to perform a write


  -- "Entity class of state_wr is not compatible with the attribute specification"
  ATTRIBUTE keep of sstate_rd, sstate_wr, snext_state_rd, snext_state_wr, scnt_RD, scnt_WR : SIGNAL IS "true" ;
  ATTRIBUTE s of sstate_rd, sstate_wr, snext_state_rd, snext_state_wr, scnt_RD, scnt_WR : SIGNAL IS "true" ;

  constant dlyWDoutRsteps : integer := 4 ; -- how long (in clock periods) should wDoutR be kept high, so read from fifo/RAM is safe (fetch data from RAM)

  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map)
-- -- and write all applicable state machines on this level
BEGIN

  -- initializations:

  -- async tristate
  pD_ft245      <= dMEM     when is_d_io_tristate = '0' else "ZZZZZZZZ";

  -- pin outputs cannot be read - must use intermediate wire/buffer
  pWR_ft245 <= bWR;
  pRDn_ft245 <= bRDn;

  -- instance of the fifo component
  membuf: versatile_sd_fifo_1buf
  PORT MAP(
    dat_i         => bDri,
    dat_o         => bDwo,
    we_i          => wDoutR,
    re_i          => wDinR,
    wr_clk        => pgCLK,
    rd_clk        => pgCLK, -- rd_clk => pass_PinR_E,
    fifo_full     => fFULL,
    fifo_rd_lags  => fRD_LAGS,
    fifo_aempty   => OPEN,  -- here OPEN is OK, no 'HDLParsers:856' ?! However, yes Xst:753, so filter message
    fifo_empty    => fEMPTY,
    rst           => wRst
  );

  pwmfGen: pwm_freq_Gen
  PORT MAP(
    CLK   => pgCLK,
    rst   => wRst,

    pData_In_PWM  => bDwo,
    pRead_Data_In => bWR,

    pCD_Rate_Tick  => wCD_Rate_Tick,
    pPWM_Rate_Tick => OPEN,

    pPWM_Out => pAPWM_Out

  );

  -- instances of LED drivers
  led_drv_wr: led_drv_gate
  PORT MAP (
    clk     => pgCLK,
    reset   => wRst,
    insig   => bWR,
    outled  => pLED_W
  );
  led_drv_ntxe: led_drv_gate
  PORT MAP (
    clk     => pgCLK,
    reset   => wRst,
    insig   => pTXEn_ft245, -- bTXEn,
    outled  => pLED_nTXE
  );
  led_drv_rd: led_drv_gate
  PORT MAP (
    clk     => pgCLK,
    reset   => wRst,
    insig   => NOT bRDn,
    outled  => pLED_R
  );

  -- END instances of components, and their wiring (port maps)...


  -- STATE MACHINES CODE =========

  -- NOTE: should eventually be changed to a single-process state machine!
  -- istate machine(s) - for initial reset pulse (delayed)
  -- (power-on reset)
  sm_i: PROCESS(istate)           -- combinatorial process part
  BEGIN
    CASE istate IS
      WHEN start_init =>
        next_istate <= init_rst_down;

      WHEN init_rst_down =>
        next_istate <= run_main;

      WHEN run_main =>
        next_istate <= run_main;

      WHEN OTHERS =>
        next_istate <= start_init;
    END CASE;
  END PROCESS sm_i;

  out_sm_i: PROCESS(pgCLK, istate) -- synchronous process part
  BEGIN
    -- if(rising_edge(clk)) -- returns only valid transitions;
    -- the oldschool below will react at X transitions too
    IF pgCLK = '1' AND pgCLK'event THEN

      IF istate = start_init THEN
        wRst <= '0';
      END IF;

      IF istate = init_rst_down THEN
        wRst <= '1';
      END IF;

      IF istate = run_main THEN
        wRst <= '0';
      END IF;

      istate <= next_istate;

    END IF;
  END PROCESS out_sm_i;



  -- ########################
  -- Main FT245 process rd & wr state machines
  -- ########################

  -- single process (one process) FSM
  FSM_FT245_rd: process(pgCLK)
    -- type StateType is ( -- moved up
    -- "ISim does not yet support tracing of VHDL variables."
    --variable state_rd, next_state_rd : StateTypeRD := wf_nRXF_L; -- now global (though not really needed)
    -- however, cannot declare signal as local
    -- signal state_rd, next_state_rd : StateTypeRD := wf_nRXF_L; -- syntax error

    -- note: we don;t need to trigger write with rd_has_byte_sync anymore;
    --   since now it is controlled by wCD_Rate_Tick...
    -- actually, we DO need rd_has_byte_sync:
    -- else write (WR=1) may end up on the bus at the same time when read (nRD=0) (multisource X)!!
    -- but here it's enough to use nRD = 0, or next_state_rd = wf_nRXF_L

  begin
    if rising_edge(pgCLK) then
      case state_rd is

        when wf_nRXF_L =>
            if wr_sent_byte_sync='1' then -- wait for wr_sent_byte_sync
              -- note: a most peculiar situation can occur here - a lockdown
              -- while wf_nRXF_L and wf_WR_start should overlap briefly,
              -- they may end up locked! Hence try see if next_state_wr is
              --  wf_WR_start, then force-initiate a read if the conditions are there
              -- else loop back to this state
              if next_state_wr = wf_WR_start then
                if pRXFn_ft245='0' and not(fFULL = '1') then
                  bRDn <= '0'; -- pRDn_ft245 <= '0'; -- effective in next state
                  next_state_rd := nRD_L_start;
                  scnt_RD <= numRDsteps-dlyRDsteps; -- available next state
                  -- is_d_io_tristate <= '1'; -- available next state - avoid multi-source; handle from WR only..
                else
                  next_state_rd := wf_nRXF_L;
                end if; -- pRXFn_ft245
              else -- wf_WR_start
                next_state_rd := wf_nRXF_L;
              end if;
            else -- wr_sent_byte_sync='0'
              -- rd/wr sync gone, proceed w. handling next byte rd
              if pRXFn_ft245='0' and not(fFULL = '1') then
                bRDn <= '0'; -- pRDn_ft245 <= '0'; -- effective in next state
                next_state_rd := nRD_L_start;
                scnt_RD <= numRDsteps-dlyRDsteps; -- available next state
                -- is_d_io_tristate <= '1'; -- available next state - avoid multi-source; handle from WR only..
              else
                next_state_rd := wf_nRXF_L;
              end if; -- pRXFn_ft245
            end if; -- wr_sent_byte_sync

        when nRD_L_start =>
          -- prolong this too - have the hi-Z longer before RDsample
          scnt_RD <= scnt_RD + 1; -- effective in next state
          if scnt_RD = numRDsteps then
            next_state_rd := RD_sample; -- just wait clock period(s) (20 ns); then sample
          else
            next_state_rd := nRD_L_start;
          end if;

        -- no need for begin/end multiple statements
        when RD_sample =>
          -- rdSAMPLE <= pD_ft245; -- sample to memory - available next state
          -- sample to RAM
          bDri <= pD_ft245; -- available next state
          wDinR <= '1';     -- available next ...
          next_state_rd := wf_nRD_expire;
          scnt_RD <= 1;

        -- just wait for expiration here
        when wf_nRD_expire =>
          scnt_RD <= scnt_RD + 1;
          if wDinR = '1' then
            wDinR <= '0'; -- leave wDinR up only one clock cycle
          end if;
          if scnt_RD = numRDsteps then
            bRDn <= '1'; -- pRDn_ft245 <= '1'; -- release; effective in next state
            scnt_RD <= 1;
            next_state_rd := wf_rd_idle;
          else
            next_state_rd := wf_nRD_expire;
          end if;

        when wf_rd_idle =>
          if scnt_RD = numIdleStepsR then
            -- rd_has_byte_sync <= '1'; -- signal other thread
            next_state_rd := wf_nRXF_L;
          else
            scnt_RD <= scnt_RD + 1; -- only update if not reached limit yet; available in next state
            next_state_rd := wf_rd_idle;
          end if;

        when OTHERS =>
          next_state_rd := wf_nRXF_L;

      end case;

      -- finally update state for next time
      state_rd := next_state_rd;
      sstate_rd <= state_rd; -- can do, for tracing in isim
      snext_state_rd <= next_state_rd; -- can do, for tracing in isim
      -- pDBG(3) <= rd_has_byte_sync;
      -- -- pDBG(2 downto 0) <= encodeRD(state_rd);
      -- pDBG(2 downto 0) <= encodeRD(next_state_rd);
    end if;

  end process FSM_FT245_rd;


  -- the write process here should react only on CD tick!

  FSM_FT245_wr: process(pgCLK)
    -- type StateType is ( -- moved up
    -- "ISim does not yet support tracing of VHDL variables."
    --variable state_wr, next_state_wr : StateTypeWR := wf_WR_start; -- wf_nRXF_L; -- need to make it global for reference in other thread
    -- however, cannot declare signal as local
    -- signal state_wr, next_state_wr : StateTypeWR := wf_WR_start; -- syntax error

    -- note: should execute a write on cd tick *always*; (FT should discard incoming data if there's no user on PC side);
    -- note: for recording, make sure Audacity is 44.1kHz / 16 bit in prefs (32 bit will fail)
    -- "and not(fEMPTY = '1')" here in wf_WR_start causes blanks to appear in audacity.. which are not easily seen without that - as then last byte is repeated for those portions..
  begin
    if rising_edge(pgCLK) then
      case state_wr is

        when wf_WR_start =>
          if wCD_Rate_Tick = '1' and not(fEMPTY = '1') then  --rd_has_byte_sync = '1' then
            wr_sent_byte_sync <= '1'; -- signal to other thread
            wDoutR <= '1'; -- available next state; data should be too? (should go auto to PWM) NO - takes four clock periods!
            -- wCD_Rate_Tick could hit at exactly last clockper of wf_rd_idle; then wdoutr is truncated
            -- protect - allow transition to WR_H_start only if next_state_rd is wf_rd_idle?
            -- no; here we are synchronous to CD tick, to fetch from RAM first (and apply to PWM)
            -- then we decide when to write on bidir FTDI bus.
            -- reset counter - will wait for safe RAM fetch
            scnt_WR <= 1;
            next_state_wr := WR_H_start;
          else
            next_state_wr := wf_WR_start;
          end if;

        when WR_H_start => -- equivalent to fetch_data_from_ram
          if (scnt_WR = dlyWDoutRsteps) then
            wDoutR <= '0'; -- cut this signal *here* (regardless if we transit state or not) - wait is finished!
            if state_rd = wf_nRXF_L and next_state_rd = wf_nRXF_L then -- data to bidir bus
              is_d_io_tristate <= '0'; -- available next state
              -- pD_ft245 <= dMEM ; -- assign from memory - available next state !!!NO need, this happens auto, due to tristate!
              dMEM <= bDwo; -- rdSAMPLE; -- goes to PWM directly
              bWR <= '1'; -- pWR_ft245 <= '1'; -- available next state
              scnt_WR <= 1;
              next_state_wr := wf_WR_expire;
            else    -- state_rd
              next_state_wr := WR_H_start;
            end if; -- state_rd
          else    -- scnt_WR
            -- update counter only here:
            scnt_WR <= scnt_WR + 1;
            next_state_wr := WR_H_start;
          end if; -- scnt_WR

        when wf_WR_expire =>
          -- is_d_io_tristate <= '0'; -- available next state; was before too
          scnt_WR <= scnt_WR + 1;
          if scnt_WR = numWRsteps then
            bWR <= '0'; -- pWR_ft245 <= '0'; -- available next state
            scnt_WR <= numWRsteps-dlyWRsteps;
            next_state_wr := hold_WR_data;
          else
            next_state_wr := wf_WR_expire;
          end if;

        when hold_WR_data =>
          scnt_WR <= scnt_WR + 1;
          if scnt_WR = numWRsteps then -- if need for delay;
            -- wr_sent_byte_sync <= '0'; -- reset this too - a bit later, way too early here
            is_d_io_tristate <= '1'; -- available next state
            scnt_WR <= 1;
            next_state_wr := wf_wr_idle;
          else
            next_state_wr := hold_WR_data;
          end if;

        when wf_wr_idle =>
          if scnt_WR = numIdleStepsW then
            if pTXEn_ft245 = '0' then -- wait for nTXE (sometimes FT can make it long!)
              wr_sent_byte_sync <= '0'; -- available next state; seems too late here; but nvm leave it
              next_state_wr := wf_WR_start;
            else
              next_state_wr := wf_wr_idle;
            end if;
          else
            scnt_WR <= scnt_WR + 1; -- update only if not reached
            next_state_wr := wf_wr_idle;
          end if;

        when OTHERS =>
          next_state_wr :=  wf_WR_start;

      end case;

      -- finally update state for next time
      state_wr := next_state_wr;
      sstate_wr <= state_wr; -- can do, for tracing in isim
      snext_state_wr <= next_state_wr; -- can do, for tracing in isim
      -- debug
      -- pDBG(3) <= wr_sent_byte_sync;
      -- -- pDBG(2 downto 0) <= encodeWR(state_wr);
      -- pDBG(2 downto 0) <= encodeWR(next_state_wr);
    end if;

  end process FSM_FT245_wr;


  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END structure;
-- END ARCHITECTURE -----------------------------
