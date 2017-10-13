-------------------------------------------------------------------------------
-- XS3A-FT245-duplex.vhd
-- Digial Duplex Loopback example for Xilinx S3A with FT245;
--    attempt for interleaved read/write...
--
-- main file (top level design/container)
----------------------------------------------------------------------------------
-- based on http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/audfpga-bb/src-hdl/XS3A-FT245-duplex-B/XS3A-FT245-duplex.vhd
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
ENTITY XS3A_FT245_duplex IS
  PORT
  (
    pgCLK : IN STD_LOGIC;						-- external 50 MHz oscillator, "global" clock
                                    -- (possibly 100 MHz with Xilinx DCM)

    -- interface pins to FT245
    pD_ft245     : INOUT STD_LOGIC_VECTOR(7 downto 0);  -- FT245's D[7..0]
    pRDn_ft245   : OUT STD_LOGIC := '1';                       -- FT245's nRD
    pWR_ft245    : OUT STD_LOGIC := '0';											  -- FT245's WR
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

    pDBG       : OUT STD_LOGIC_VECTOR(3 downto 0);

    -- LED pins (indication)
    pLED_R     : OUT STD_LOGIC;   -- LED active on Read - simply buffered (via FF) RD or RXF, must be out too
    pLED_nTXE  : OUT STD_LOGIC   -- LED active on nTXE
    ; -- pre-last semicolon
    pLED_W     : OUT STD_LOGIC    -- LED active on Write - simply buffered (via FF) TXE or RXF

  );
END XS3A_FT245_duplex;



-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE structure OF XS3A_FT245_duplex IS


  ATTRIBUTE keep_hierarchy : STRING;
  ATTRIBUTE keep_hierarchy of structure: ARCHITECTURE IS "yes";

  ATTRIBUTE clock_signal : STRING;
  ATTRIBUTE clock_signal of pgCLK : SIGNAL IS "yes";

  -- DECLARE REGISTERS: initialize the signals

  -- if I use single StateType for both state machines: ERROR:HDLCompiler:299 case statement does not cover all choices. 'others' clause is needed
  -- therefore, split them
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
-- >     wf_WR2_expire,  -- wait for write 2 to expire
-- >     finish,         -- final (lock)
    hold_WR_data,   -- hold WR data on bus, after WR deasserted
    wf_wr_idle      -- wait for after write idle
  );

  -- debug -- gets trimmed/optimized away if not used
  -- http://www.velocityreviews.com/forums/t615140-convert-enumeration-to-std_logic_vector.html
  -- type encoding_array_RD is array(StateTypeRD) of std_logic_vector(2 downto 0);
  -- constant encodeRD : encoding_array_RD :=
  -- ( wf_nRXF_L     => "001",
    -- nRD_L_start   => "010",
    -- RD_sample     => "011",
    -- wf_nRD_expire => "100",
    -- wf_rd_idle    => "101");

  -- type encoding_array_WR is array(StateTypeWR) of std_logic_vector(2 downto 0);
  -- constant encodeWR : encoding_array_WR :=
  -- ( wf_WR_start   => "001",
    -- WR_H_start    => "010",
    -- wf_WR_expire  => "011",
    -- hold_WR_data  => "100",
    -- wf_wr_idle    => "101");
  -- or:

  constant encSize : integer := 3 ;
  signal dstate_rd, dstate_wr: STD_LOGIC_VECTOR(encSize-1 DOWNTO 0) := "000";

  -- using dstate_rd/wr'length in functions causes 'impure' function warnings
  -- (using constant encSize instead is fine)
  function encodeRD ( invar : StateTypeRD) -- inputs
  return std_logic_vector is
  begin  -- function max
    return std_logic_vector(to_unsigned(StateTypeRD'pos(invar), encSize));
  end function encodeRD;
  function encodeWR ( invar : StateTypeWR) -- inputs
  return std_logic_vector is
  begin  -- function max
    return std_logic_vector(to_unsigned(StateTypeWR'pos(invar), encSize));
  end function encodeWR;


  -- http://www.vhdl.org/vhdlsynth/vhdl/minmax.vhd
  function maximum ( left, right : integer) -- inputs
  return integer is
  begin  -- function max
    if LEFT > RIGHT then return LEFT;
    else return RIGHT;
    end if;
  end function maximum;


  constant numRDsteps : integer := 20 ; -- number of wait for Read steps; in clock periods
  constant numWRsteps : integer := 20 ; -- number of wait for Write steps; in clock periods

  constant numIdleStepsR : integer := 20 ; -- idle state wait; clock periods
  constant numIdleStepsW : integer := 100 ; -- idle state wait; clock periods

  constant dlyRDsteps : integer := 2 ; -- delay steps for RD; was 2, but it locks? ok w/ 1?
  constant dlyWRsteps : integer := 3 ; -- delay steps for WR

  -- must have these as signals, local variables cannot be simmed yet
  signal sstate_rd, snext_state_rd : StateTypeRD := wf_nRXF_L;
  signal sstate_wr, snext_state_wr : StateTypeWR := wf_WR_start; -- WR_H_start;
  signal scnt_RD : NATURAL range 0 to maximum(numRDsteps,numIdleStepsR) := maximum(numIdleStepsR,numRDsteps); -- numRDsteps;
  signal scnt_WR : NATURAL range 0 to maximum(numWRsteps,numIdleStepsW) := maximum(numIdleStepsW,numWRsteps); -- numWRsteps;


  SIGNAL dMEM : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001111"; --
  SIGNAL rdSAMPLE : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001111"; --
  SIGNAL is_d_io_tristate : STD_LOGIC := '1'; -- was: is_d_io_active
  SIGNAL rd_has_byte_sync : STD_LOGIC := '0'; -- whether it's time to perform a write
  SIGNAL wr_sent_byte_sync : STD_LOGIC := '0'; -- whether it's time to perform a write

  -- now global, to allow reference between processes
  -- "ERROR:HDLCompiler:885 Variable outside of subprogram or process must be 'shared'"
  shared variable state_wr, next_state_wr : StateTypeWR := wf_WR_start;
  shared variable state_rd, next_state_rd : StateTypeRD := wf_nRXF_L;

  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map)
-- -- and write all applicable state machines on this level
BEGIN


  -- async tristate
  pD_ft245      <= dMEM     when is_d_io_tristate = '0' else "ZZZZZZZZ";


  -- STATE MACHINES CODE =========

  -- single process (one process) FSM
  FSM_rd: process(pgCLK)
    -- type StateType is ( -- moved up
    -- "ISim does not yet support tracing of VHDL variables."
    --variable state_rd, next_state_rd : StateTypeRD := wf_nRXF_L; -- now global (though not really needed)
    -- however, cannot declare signal as local
    -- signal state_rd, next_state_rd : StateTypeRD := wf_nRXF_L; -- syntax error

  begin
    if rising_edge(pgCLK) then
      case state_rd is

        when wf_nRXF_L =>
          if rd_has_byte_sync='1' then
            -- byte has been handled, reset yourself; and wait state
            if wr_sent_byte_sync='1' then
              rd_has_byte_sync <= '0'; -- effective in next state
            end if;
            next_state_rd := wf_nRXF_L;
          else --rd_has_byte_sync=0
            if wr_sent_byte_sync='1' then -- wait for wr_sent_byte_sync
              -- note: a most peculiar situation can occur here - a lockdown
              -- while wf_nRXF_L and wf_WR_start should overlap briefly,
              -- they may end up locked! Hence try see if next_state_wr is
              --  wf_WR_start, then force-initiate a read if the conditions are there
              -- else loop back to this state
              if next_state_wr = wf_WR_start then
                if pRXFn_ft245='0' then
                  pRDn_ft245 <= '0'; -- effective in next state
                  next_state_rd := nRD_L_start;
                  scnt_RD <= numRDsteps-dlyRDsteps; -- available next state
                  -- is_d_io_tristate <= '1'; -- available next state - should be 1 already; avoid multi-source; handle from WR only..
                else
                  next_state_rd := wf_nRXF_L;
                end if; -- pRXFn_ft245
              else -- wf_WR_start
                next_state_rd := wf_nRXF_L;
              end if;
            else
              -- rd/wr sync gone, proceed w. handling next byte rd
              if pRXFn_ft245='0' then
                pRDn_ft245 <= '0'; -- effective in next state
                next_state_rd := nRD_L_start;
                scnt_RD <= numRDsteps-dlyRDsteps; -- available next state
                -- is_d_io_tristate <= '1'; -- available next state - should be 1 already; avoid multi-source; handle from WR only..
              else
                next_state_rd := wf_nRXF_L;
              end if; -- pRXFn_ft245
            end if; -- wr_sent_byte_sync
          end if; -- rd_has_byte_sync

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
          rdSAMPLE <= pD_ft245; -- sample to memory - available next state
          next_state_rd := wf_nRD_expire;
          scnt_RD <= 1;

        -- just wait for expiration here
        when wf_nRD_expire =>
          scnt_RD <= scnt_RD + 1;
          if scnt_RD = numRDsteps then
            pRDn_ft245 <= '1'; -- release; effective in next state
            scnt_RD <= 1;
            next_state_rd := wf_rd_idle;
          else
            next_state_rd := wf_nRD_expire;
          end if;

        when wf_rd_idle =>
          if scnt_RD = numIdleStepsR then
            rd_has_byte_sync <= '1'; -- signal other thread
            next_state_rd := wf_nRXF_L;
          else
            scnt_RD <= scnt_RD + 1; -- only update if not reached limit yet; available in next state
            next_state_rd := wf_rd_idle;
          end if;

      end case;

      -- finally update state for next time
      state_rd := next_state_rd;
      sstate_rd <= state_rd; -- can do, for tracing in isim
      dstate_rd <= encodeRD(state_rd); -- for debug output pins
      -- pDBG(3) <= rd_has_byte_sync;
      -- pDBG(2 downto 0) <= encodeRD(state_rd);
    end if;

  end process FSM_rd;


  FSM_wr: process(pgCLK)
    -- type StateType is ( -- moved up
    -- "ISim does not yet support tracing of VHDL variables."
    --variable state_wr, next_state_wr : StateTypeWR := wf_WR_start; -- wf_nRXF_L; -- need to make it global for reference in other thread
    -- however, cannot declare signal as local
    -- signal state_wr, next_state_wr : StateTypeWR := wf_WR_start; -- syntax error

  begin
    if rising_edge(pgCLK) then
      case state_wr is

        when wf_WR_start =>
          if rd_has_byte_sync = '1' then
            wr_sent_byte_sync <= '1'; -- signal to other thread
            next_state_wr := WR_H_start;
          else
            next_state_wr := wf_WR_start;
          end if;

        when WR_H_start =>
          is_d_io_tristate <= '0'; -- available next state
          -- pD_ft245 <= dMEM ; -- assign from memory - available next state !!!NO need, this happens auto, due to tristate!
-- >             -- dMEM <= "11110000"; -- ok to start with WR, gets sampled at WR negedge
          dMEM <= rdSAMPLE;
          pWR_ft245 <= '1'; -- available next state
          scnt_WR <= 1;
          next_state_wr := wf_WR_expire;

        when wf_WR_expire =>
          -- is_d_io_tristate <= '0'; -- available next state; was before too
          scnt_WR <= scnt_WR + 1;
          if scnt_WR = numWRsteps then
            -- pD_ft245 <= "11110000"; -- available next state -- don't assign to pD anymore, messes the tristate...
            pWR_ft245 <= '0'; -- available next state
            scnt_WR <= numWRsteps-dlyWRsteps;
            next_state_wr := hold_WR_data;
          else
            next_state_wr := wf_WR_expire;
          end if;

        when hold_WR_data =>
          scnt_WR <= scnt_WR + 1;
          if scnt_WR = numWRsteps then -- if need for delay;
            --wr_sent_byte_sync <= '0'; -- reset this too - a bit later
            is_d_io_tristate <= '1'; -- available next state
            scnt_WR <= 1;
            next_state_wr := wf_wr_idle;
          else
            next_state_wr := hold_WR_data;
          end if;

        when wf_wr_idle =>
          if scnt_WR = numIdleStepsW then
            if pTXEn_ft245 = '0' then -- wait for nTXE (sometimes FT can make it long!)
              wr_sent_byte_sync <= '0'; -- available next state
              next_state_wr := wf_WR_start;
            else
              next_state_wr := wf_wr_idle;
            end if;
          else
            scnt_WR <= scnt_WR + 1; -- update only if not reached
            next_state_wr := wf_wr_idle;
          end if;

      end case;

      -- finally update state for next time
      state_wr := next_state_wr;
      sstate_wr <= state_wr; -- can do, for tracing in isim
      dstate_wr <= encodeWR(state_wr); -- for debug output pins
      pDBG(3) <= wr_sent_byte_sync;
      -- pDBG(2 downto 0) <= encodeWR(state_wr);
      pDBG(2 downto 0) <= encodeWR(next_state_wr);
    end if;

  end process FSM_wr;


  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END structure;
-- END ARCHITECTURE -----------------------------
