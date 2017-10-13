-------------------------------------------------------------------------------
-- XS3A-FT245-duplex.vhd
-- Digial Duplex Loopback example for Xilinx S3A with FT245;
--    attempt for interleaved read/write...
--
-- main file (top level design/container)
----------------------------------------------------------------------------------
-- based on usb_jtag/device/cpld/jtag_logic.vhd by Kolja Waschk, ixo.de
-- -- (from http://www.ixo.de/info/usb_jtag/usb_jtag-20080705-1200.zip)
-- -- (jtag_logic.vhd can be seen on http://tigerwang202.blogbus.com/files/12360479200.vhd)
-- also using portions from:
-- -- http://www.myhdl.org/doku.php/projects:ft245r
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
    pRDn_ft245   : OUT STD_LOGIC;                       -- FT245's nRD
    pWR_ft245    : OUT STD_LOGIC;											  -- FT245's WR
    pRXFn_ft245  : IN STD_LOGIC;                        -- FT245's nRXF
    pTXEn_ft245  : IN STD_LOGIC;                        -- FT245's nTXE
    pPWREN_ft245 : INOUT STD_LOGIC;       -- FT245's PWREN
                                          -- make it INOUT, so we put it in hi Z,
                                          -- so it don't interfere

    -- LED pins (indication)
    pLED_R     : OUT STD_LOGIC;   -- LED active on Read - simply buffered (via FF) RD or RXF, must be out too
    pLED_nTXE  : OUT STD_LOGIC   -- LED active on nTXE
    ; -- pre-last semicolon
    pLED_W     : OUT STD_LOGIC    -- LED active on Write - simply buffered (via FF) TXE or RXF

    -- debug
    -- pDBG       : OUT STD_LOGIC_VECTOR(3 downto 0)
  );
END XS3A_FT245_duplex;



-- ARCHITECTURE ---------------------------------
-- contents of this 'top-level' FPGA 'container':
--
ARCHITECTURE structure OF XS3A_FT245_duplex IS

ATTRIBUTE keep_hierarchy : STRING;
-- ATTRIBUTE keep_hierarchy of XS3A_FT245_duplex: ENTITY IS "yes"; -- Attribute on units are only allowed on current unit.
ATTRIBUTE keep_hierarchy of structure: ARCHITECTURE IS "yes";

  -- DECLARE COMPONENTS =========================

  -- First, declaration of other HDL components used in-
  --   side the top-level 'XS3A_FT245_duplex' FPGA 'core':

  -- bidirectional FT245 bus interface
  -- COMPONENT busFT245if --  (verilog, from myhdl)
  COMPONENT busFT245ifVHD
    PORT(
      clk :       IN STD_LOGIC;
      -- interface to USB module
      rxf_n_i :   IN STD_LOGIC;
      txe_n_i :   IN STD_LOGIC;
      rd_n_o :    OUT STD_LOGIC;
      wr_o :      OUT STD_LOGIC;
      d_io :      INOUT STD_LOGIC_VECTOR(7 downto 0);
      -- interface to FPGA logic
      rxf_n_o :   OUT STD_LOGIC;
      txe_n_o :   OUT STD_LOGIC;
      rd_n_i :    IN STD_LOGIC;
      wr_i :      IN STD_LOGIC;
      d_read_o :  OUT STD_LOGIC_VECTOR(7 downto 0);
      d_write_i : IN STD_LOGIC_VECTOR(7 downto 0)
    );
  END COMPONENT;

  -- read and write processes/state machines
  --   are defined in this component:
  COMPONENT processFT245if
    PORT(
      CLK : IN STD_LOGIC;         -- external 50 MHz oscillator
      -- OKtoREAD : IN STD_LOGIC;    -- whether to execute next read - to allow; default value = 'Z' but "parse error, unexpected EQ, expecting SEMICOLON or CLOSEPAR"
                                  --   time for a consecutive write;
                                  -- based on fifo's aempty
                                  -- removed

      nRXF  : IN STD_LOGIC;                       -- FT245's nRXF
      nTXE  : IN STD_LOGIC;                       -- FT245's nTXE
      nRD   : OUT STD_LOGIC;                      -- FT245's nRD
      WR    : OUT STD_LOGIC;                      -- FT245's WR
      -- D     : INOUT STD_LOGIC_VECTOR(7 downto 0); -- FT245's D[7..0]

      DoutR : OUT STD_LOGIC;	    -- Data Out Ready
      DinR  : OUT STD_LOGIC;	    -- Data In Ready (now it's output, as control signal - read enable)
      -- Din   : IN STD_LOGIC_VECTOR(7 downto 0);  -- port where data to FT245 is piped
      -- Dout  : OUT STD_LOGIC_VECTOR(7 downto 0)  -- port where data from FT245 is read
      mF : IN STD_LOGIC  -- memory full - from fifo buffer
      ; -- pre-last semicolon
      mE : IN STD_LOGIC  -- memory empty - from fifo buffer

      -- debug
      -- DBG_state       : OUT STD_LOGIC_VECTOR(1 downto 0)
      -- DBG_stcnt       : OUT STD_LOGIC_VECTOR(1 downto 0)
    );
  END COMPONENT;

  -- declarin' a Verilog FIFO here
  COMPONENT versatile_sd_fifo_1buf
    PORT(
      dat_i       : IN std_logic_vector(7 downto 0);
      we_i        : IN std_logic;
      re_i        : IN std_logic;
      wr_clk      : IN std_logic;
      rd_clk      : IN std_logic;
      dat_o       : OUT std_logic_vector(7 downto 0);
      fifo_full   : OUT std_logic; -- only one buffer now
      fifo_empty  : OUT std_logic; -- only one buffer now
      fifo_aempty : OUT std_logic; -- async empty - should be set also whenever buffer is not empty
      rst         : IN std_logic
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


  -- END DECLARE STATES for STATE MACHINES ======


  -- DECLARE REGISTERS ==========================

  -- "constants" to emulate low and high logic level,
  --   (if needed to "ground" something)
  SIGNAL LO: STD_LOGIC :='0';
  SIGNAL HI: STD_LOGIC :='1';
  SIGNAL FLOATZ: STD_LOGIC :='Z'; -- undriven net, instead of OPEN: AR #18415
  -- ATTRIBUTE keep of LO, HI, FLOATZ : SIGNAL IS "true" ;
  -- ATTRIBUTE s of LO, HI, FLOATZ : SIGNAL IS "true" ;
  -- ATTRIBUTE s of FLOATZ : SIGNAL IS "true" ; -- Line 27: Could not find net(s) 'pPWREN_ft245' in the design.
  -- ATTRIBUTE keep of FLOATZ : SIGNAL IS "true" ; -- Line 27: Could not find net(s) 'pPWREN_ft245' in the design.

  -- declare 'wire': internal "variables" - registers, since
  --   we must connect the instantiated objects somewhere,
  --   even internal registers (when not using pins direct).

  -- initialize the signals - else the synthesizer optimizes them away!

  -- SIGNAL gCLK: STD_LOGIC :='0'; -- 'wire' for the clock
  -- no need for clock wire - use the entity port name (pin) pgCLK
  -- directly (we otherwise could assign it right after BEGIN)

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
  SIGNAL fFULL  : STD_LOGIC :='0'; -- 'fifo full wire'
  SIGNAL fEMPTY : STD_LOGIC :='0'; -- 'fifo empty wire'

  SIGNAL wRst : STD_LOGIC := 'Z'; -- startup reset 'wire' (power-on reset)
                                  -- used also for versatile fifo..

  ATTRIBUTE keep of bRXFn, bRDn, bTXEn, bWR, bDri, bDwo, wDoutR, wDinR, fFULL, fEMPTY, wRst : SIGNAL IS "true" ;
  ATTRIBUTE s of bRXFn, bRDn, bTXEn, bWR, bDri, bDwo, wDoutR, wDinR, fFULL, fEMPTY, wRst : SIGNAL IS "true" ;
  ATTRIBUTE clock_signal of pgCLK : SIGNAL IS "yes";


  -- END DECLARE REGISTERS ======================


-- IMPLEMENT ENGINE of 'CORE' ===================
-- -- define all connections between components (port map)
-- -- and write all applicable state machines on this level
BEGIN

  -- initializations:

  -- LO and HI are here in case we eventually need them,
  -- but for now, they're both 'assigned but never used'
  LO <= '0';
  HI <= '1';

  FLOATZ <= 'Z'; -- gets rid of 'used but never assigned'
  -- pPWREN_ft245 <= FLOATZ; -- doesn't really work for par
  pPWREN_ft245 <= 'Z'; -- fuse: Parameter OKtoREAD of mode in can not be associated with a formal port of mode out.; since <= 'Z' here optimizes away FLOATZ, regardless of previous statement
  -- pDBG <= OPEN; -- cannot: parse error, unexpected OPEN

  -- assign 'register' to port
  -- (hopefully, changes to regs will be preserved)
  -- pRDn_ft245 <= bRDn;
  -- pWR_ft245 <= bWR;

  -- assign port to 'register'
  -- bRXFn <= pRXFn_ft245;
  -- bTXEn <= pTXEn_ft245;

  -- instances of components, and their wiring (port maps)...

  -- in a VHDL file:
  -- -- for Verilog component, must give explicit connection
  -- -- for VHDL component, can just list in order (but, it's bad style)

  -- instance of FT245 bidirectional bus interface
  -- buss_if245 : busFT245if -- Verilog
  buss_if245 : busFT245ifVHD -- VHDL
  PORT MAP(
      clk     => pgCLK,
      -- interface to USB module
      rxf_n_i => pRXFn_ft245,
      txe_n_i => pTXEn_ft245,
      rd_n_o  => pRDn_ft245,
      wr_o    => pWR_ft245,
      d_io    => pD_ft245,
      -- interface to FPGA logic
      rxf_n_o   => bRXFn,
      txe_n_o   => bTXEn,
      rd_n_i    => bRDn,
      wr_i      => bWR,
      d_read_o  => bDri,  -- 'out' for bus; 'in' for FPGA process
      d_write_i => bDwo   -- 'in' for bus; 'out' for FPGA process
  );

  -- instance of FT245 processing interface component
  proc_if245: processFT245if -- VHDL
  PORT MAP(
      CLK   => pgCLK,
      -- OKtoREAD => OPEN, -- FLOATZ, -- 'Z': Parameter OKtoREAD of mode in can not be associated with a formal port of mode out.; OPEN: No default value for unconnected port <OKtoREAD>. -- removed; mostly outports can be kept open
      nRXF  => bRXFn,
      nTXE  => bTXEn,
      nRD   => bRDn,
      WR    => bWR,
      -- D     => OPEN, -- not needed anymore; split by bus-if
      -- in fact, we don't need to pass
      -- data through the processor -
      -- data should be exchanged directly
      -- with fifo buffer; the processor
      -- should simply raise
      --   (write) out ready -> write enable
      --   (read) in ready - read enable
      --Din   => bDri,
      --Dout  => bDwo
      -- however, we DO also have fifo empty/full as inputs!
      mF => fFULL,
      mE => fEMPTY,
      DoutR => wDoutR,
      DinR  => wDinR
      -- DBG_state => pDBG(3 downto 2),
      -- DBG_stcnt => pDBG(1 downto 0)
  );

  -- instance of the fifo component
  membuf: versatile_sd_fifo_1buf
  PORT MAP(
    dat_i       => bDri,
    dat_o       => bDwo,
    we_i        => wDoutR,
    re_i        => wDinR,
    wr_clk      => pgCLK,
    rd_clk      => pgCLK, -- rd_clk => pass_PinR_E,
    fifo_full   => fFULL,
    fifo_aempty => OPEN,  -- here OPEN is OK, no 'HDLParsers:856' ?!
    fifo_empty  => fEMPTY,
    rst         => wRst
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
    insig   => bTXEn,
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

  -- END STATE MACHINES CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END structure;
-- END ARCHITECTURE -----------------------------
