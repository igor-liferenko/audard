-------------------------------------------------------------------------------
-- busFT245ifVHD.vhd
-- (bidirectional port with hi-z)
-- conversion of MyHDL ft245if.v to VHDL
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


-- ENTITY ---------------------------------------
-- declaration of actual electric ports of this
--   FPGA 'core' (top level design/container)...
-- --
-- same pins as busFT245ifVHD
ENTITY busFT245ifVHD IS
  PORT
  (
    clk :       IN STD_LOGIC;
    ---interface to USB module
    rxf_n_i :   IN STD_LOGIC;
    txe_n_i :   IN STD_LOGIC;
    rd_n_o :    OUT STD_LOGIC;
    wr_o :      OUT STD_LOGIC;
    d_io :      INOUT STD_LOGIC_VECTOR(7 downto 0);
    ---interface to FPGA logic
    rxf_n_o :   OUT STD_LOGIC;
    txe_n_o :   OUT STD_LOGIC;
    rd_n_i :    IN STD_LOGIC;
    wr_i :      IN STD_LOGIC;
    d_read_o :  OUT STD_LOGIC_VECTOR(7 downto 0);
    d_write_i : IN STD_LOGIC_VECTOR(7 downto 0)
  );
END busFT245ifVHD;


-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE structure OF busFT245ifVHD IS

ATTRIBUTE keep_hierarchy : STRING;
ATTRIBUTE keep_hierarchy of structure: ARCHITECTURE IS "yes";
ATTRIBUTE keep : STRING;
ATTRIBUTE s: STRING; -- "SAVE NET FLAG"

  -- DECLARE COMPONENTS =========================

  -- First, declaration of other HDL components used in-
  --   side the top-level 'busFT245ifVHD' FPGA 'core':


  -- END DECLARE COMPONENTS =====================


  -- DECLARE STATES for STATE MACHINES ==========

  -- TYPE init_states IS
  -- (
    -- start_init,     -- here set rst 1
    -- init_rst_down,  -- here set rst down
    -- run_main
  -- );
  -- ATTRIBUTE ENUM_ENCODING: STRING;
  -- ATTRIBUTE ENUM_ENCODING OF init_states: TYPE IS
    -- "00 01 11"; -- as in auto gray encoding
  -- SIGNAL istate: init_states := start_init;
  -- SIGNAL next_istate: init_states := start_init;

  -- END DECLARE STATES for STATE MACHINES ======


  -- DECLARE REGISTERS ==========================

  -- "constants" to emulate low and high logic level,
  --   (if needed to "ground" something)
  SIGNAL LO: STD_LOGIC :='0';
  SIGNAL HI: STD_LOGIC :='1';
  SIGNAL FLOATZ: STD_LOGIC :='Z'; -- undriven net, instead of OPEN: AR #18415

  -- 'dummy signals' - registers
  SIGNAL wtCLK : std_logic := '0';

  SIGNAL wrxf_n_i : std_logic := 'Z';
  SIGNAL wtxe_n_i : std_logic := 'Z';
  SIGNAL wrd_n_o : std_logic := 'Z';
  SIGNAL wwr_o : std_logic := 'Z';
  -- SIGNAL wd_io : STD_LOGIC_VECTOR(7 DOWNTO 0) := "ZZZZZZZZ";
  -- SIGNAL wd_io : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');
  SIGNAL wd_io_mirror : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');

  SIGNAL wrxf_n_o : std_logic := 'Z';
  SIGNAL wtxe_n_o : std_logic := 'Z';
  SIGNAL wrd_n_i : std_logic := 'Z';
  SIGNAL wwr_i : std_logic := 'Z';
  SIGNAL wd_read_o : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');
  SIGNAL wd_write_i : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');

  SIGNAL d_write_reg : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');
  SIGNAL d_io_reg : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');

  SIGNAL DATABUS_ZERO: STD_LOGIC :='Z';
  SIGNAL is_d_io_tristate : std_logic := 'Z'; -- was: is_d_io_active

  ATTRIBUTE s of d_write_reg, d_io_reg, is_d_io_tristate : SIGNAL IS "yes";
  ATTRIBUTE keep of d_write_reg, d_io_reg, is_d_io_tristate : SIGNAL IS "yes";
  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map)
-- -- and write all applicable state machines on this level
BEGIN

  -- initializations:

  LO <= '0';
  HI <= '1';

  FLOATZ <= 'Z'; -- gets rid of 'used but never assigned'

  -- assign 'register' to port
  -- (hopefully, changes to regs will be preserved)
  rd_n_o <= wrd_n_o;
  wr_o <= wwr_o;
  rxf_n_o <= wrxf_n_o;
  txe_n_o <= wtxe_n_o;
  d_read_o <= wd_read_o;
  -- assign port to 'register'
  wrxf_n_i <= rxf_n_i;
  wtxe_n_i <= txe_n_i;
  wrd_n_i <= rd_n_i;
  wwr_i <= wr_i;
  wd_write_i <= d_write_i;
  -- READ_EN1 => REG1_READ_EN; -- parse error, unexpected ROW, expecting OPENPAR or TICK or LSQBRACK

  -- signals from USB module
  wrxf_n_o <= wrxf_n_i;
  wtxe_n_o <= wtxe_n_i;

  -- signals to USB module
  wwr_o   <= wwr_i;
  wrd_n_o <= wrd_n_i;


  -- is_d_io_active  <= (wwr_i AND wrd_n_i);
  -- d_io            <= d_write_reg  when is_d_io_active = '1' else "ZZZZZZZZ";
  -- wd_read_o       <= d_io_reg     when is_d_io_active = '0' else "ZZZZZZZZ";

  -- is d_io tristated by us, the FPGA
  -- see: http://forums.xilinx.com/t5/General-Technical-Discussion/Portmapping-bidirectional-ports/td-p/98930
  -- "the top level port, if bidirectional or "INOUT"  MUST be directly connected to the submodule port with no intervening signal  or assignment.
  -- There is no direct "assignment" operator  that works bidirectionally."
  -- but: d_read_o <= d_io: Multi-source in Unit <busFT245ifVHD> on signal <d_read_o<0>>
  is_d_io_tristate  <= NOT (wwr_i AND wrd_n_i);
  d_io       <= d_write_i     when is_d_io_tristate = '0' else "ZZZZZZZZ";
  wd_read_o <= d_io;

  DATABUS_ZERO <= '1' when d_io = X"00" else '0';

  -- instance of component (PORT MAP)

  -- END instances of components, and their wiring (port maps)...


  -- STATE MACHINES CODE =========


  -- You can use DATABUS directly as input.
  -- The following will set DATABUS_ZERO to "true" whenever DATABUS is 0,
  --   regardless of where the zero came from (e.g., it can come from REG1_OUT).


  -- Update registers using appropriate write-enable signal.
  -- Use registers to "capture" input data.

  -- U_REG1: process (clk)
  -- begin
     -- if rising_edge(clk) then
        -- if wwr_i = '1' then
        ---- if is_d_io_tristate = '0' then
          ---- d_io_reg <= d_io;
        ---- else      -- these assignments should be exclusive, so they keep values
          -- d_write_reg <= wd_write_i;
        -- end if;
     -- end if;
  -- end process;



  -- U_REG2: process (clk)
  -- begin
     -- if rising_edge(clk) then
        -- if REG2_WRITE_EN = '1' then
           -- REG2_OUT <= DATABUS;
        -- end if;
     -- end if;
  -- end process;


  -- istate machine(s) - for initial reset pulse (delayed)
  -- (power-on reset)
  -- sm_i: PROCESS(istate)           -- combinatorial process part
  -- BEGIN
    -- CASE istate IS
      -- WHEN start_init =>
        -- next_istate <= init_rst_down;

      -- WHEN init_rst_down =>
        -- next_istate <= run_main;

      -- WHEN run_main =>
        -- next_istate <= run_main;

      -- WHEN OTHERS =>
        -- next_istate <= start_init;
    -- END CASE;
  -- END PROCESS sm_i;

  -- out_sm_i: PROCESS(pgCLK, istate) -- synchronous process part
  -- BEGIN
    -- -- if(rising_edge(clk)) -- returns only valid transitions;
    -- -- the oldschool below will react at X transitions too
    -- IF pgCLK = '1' AND pgCLK'event THEN

      -- IF istate = start_init THEN
        -- wRst <= '0';
      -- END IF;

      -- IF istate = init_rst_down THEN
        -- wRst <= '1';
      -- END IF;

      -- IF istate = run_main THEN
        -- wRst <= '0';
      -- END IF;

      -- istate <= next_istate;

    -- END IF;
  -- END PROCESS out_sm_i;

  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END structure;
-- END ARCHITECTURE -----------------------------
