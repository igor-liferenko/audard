-------------------------------------------------------------------------------
-- busFT245if_tbw.vhd
-- This file is a testbench engine - just a quick test
-- of busFT245if.v
-- (test: ./xil_synt_test.sh busFT245if_tbw.vhd busFT245ifVHD.vhd)
-------------------------------------------------------------------------------
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
ENTITY busFT245if_tbw IS
END busFT245if_tbw;

ARCHITECTURE testbench_arch OF busFT245if_tbw IS
  FILE RESULTS: TEXT OPEN WRITE_MODE IS "busFT245if_tbw-results.txt";

  -- the COMPONENT defined below, is the component
  --   that this testbench will apply to (interface with)
  --   a.k.a the UUT/DUT (unit/device under test)
  --   (UUT also needs to be specified after BEGIN)
  -- bidirectional FT245 bus interface
  --  (verilog, from myhdl)
  -- COMPONENT busFT245if
  COMPONENT busFT245ifVHD
    PORT(
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
  END COMPONENT;

  -- component BUFT8
  -- port ( T: in std_logic;
       -- I : in std_logic_vector(7 downto 0);
       -- O : out std_logic_vector(7 downto 0));
  -- end component;

   -- DECLARE REGISTERS ==========================

  -- 'wires'
  -- we need to handle both inputs and outputs of UUT here
  SIGNAL wtCLK : std_logic := '0';

  SIGNAL wrxf_n_i : std_logic := 'Z';
  SIGNAL wtxe_n_i : std_logic := 'Z';
  SIGNAL wrd_n_o : std_logic := 'Z';
  SIGNAL wwr_o : std_logic := 'Z';
  SIGNAL wd_io : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z'); -- ok now, with VHDL UUT
  SIGNAL wd_io_mirror : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');

  SIGNAL wrxf_n_o : std_logic := 'Z';
  SIGNAL wtxe_n_o : std_logic := 'Z';
  SIGNAL wrd_n_i : std_logic := 'Z';
  SIGNAL wwr_i : std_logic := 'Z';
  SIGNAL wd_read_o : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');
  SIGNAL wd_write_i : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => 'Z');


  SIGNAL LO: STD_LOGIC :='0';
  SIGNAL HI: STD_LOGIC :='1';

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
  -- UUT : busFT245if -- Verilog
  -- UUT : ENTITY busFT245if -- Verilog -- "busFT245if is a Verilog module/UDP name. Direct instantiation of a Verilog module/UDP is not supported."
  UUT : busFT245ifVHD -- VHDL
  PORT MAP(
      clk     => wtCLK,
      -- interface to USB module
      rxf_n_i => wrxf_n_i,
      txe_n_i => wtxe_n_i,
      rd_n_o  => wrd_n_o,
      wr_o    => wwr_o,
      d_io    => wd_io,
      -- interface to FPGA logic
      rxf_n_o   => wrxf_n_o,
      txe_n_o   => wtxe_n_o,
      rd_n_i    => wrd_n_i,
      wr_i      => wwr_i,
      d_read_o  => wd_read_o,  -- 'out' for bus; 'in' for FPGA process
      d_write_i => wd_write_i   -- 'in' for bus; 'out' for FPGA process
  );

  --  Warning: No entity is bound for inst /busFT245if_tbw/dummy_BUFT8 of Component BUFT8
  -- dummy_BUFT8 : BUFT8
  -- port map (
    -- T => LO,
    -- I => wd_io,
    -- O => wd_io_mirror
  -- );

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


  -- simulate change of signals
  busFT245if_test_sim: PROCESS
  BEGIN
    -- startup values:
    -- busFT245if should have set WR to 0 as well..


    -- wd_io <= "ZZZZZZZZ"; -- init? no dice
    -- wd_io_mirror <= "ZZZZZZZZ"; -- "00000000";

    WAIT for OFFSET;  -- wait out the clock offset
    WAIT for 30 ns;   -- ... and 30 ns more

    wwr_i <= '0';
    WAIT for 30 ns;

    -- wd_io <= "01010101";
    wd_write_i <= "11110000";
    WAIT for 30 ns;

    wrd_n_i <= '0';
    WAIT for 30 ns;

    wd_write_i <= "ZZZZZZZZ";
    WAIT for 30 ns;

    WAIT for 30 ns;

    wrd_n_i <= '1';
    WAIT for 30 ns;

      wd_write_i <= "11110000";
      WAIT for 30 ns;

      wrd_n_i <= '0';
      wd_write_i <= "ZZZZZZZZ";
      WAIT for 30 ns;

    wwr_i <= '1';
    WAIT for 30 ns;

      wd_write_i <= "11110000";
      WAIT for 30 ns;

      wwr_i <= '0';
      wd_write_i <= "ZZZZZZZZ";
      WAIT for 30 ns;

    wrd_n_i <= '1';
    WAIT for 30 ns;

      -- real test write here, when RD#=1 and WR=1
      wd_write_i <= "11110000";
      WAIT for 30 ns;

      wwr_i <= '1';
      WAIT for 30 ns;

      wrd_n_i <= '0';
      WAIT for 30 ns;

      wd_write_i <= "ZZZZZZZZ";
      WAIT for 30 ns;

      wwr_i <= '0';
      WAIT for 30 ns;

    -- test read here - write to bus;
    -- should be effective any other state than RD#=1 and WR=1

    wd_io <= "10101010";
    WAIT for 30 ns;

    wd_io <= "ZZZZZZZZ";
    WAIT for 30 ns;

    wrd_n_i <= '1';
    WAIT for 30 ns;

      wd_io <= "10101010";
      WAIT for 30 ns;

      wd_io <= "ZZZZZZZZ";
      WAIT for 30 ns;

    wrd_n_i <= '1';
    WAIT for 30 ns;

    WAIT;

  END PROCESS busFT245if_test_sim;

  -- as wd_io would be input here (this being a latch?), it would be read from;
  -- the d_io 'inout' port has an 'out' role
  -- so hopefully this handles the U testbench isim problem:
  -- "driver inside the uut HAS A DEFAULT VALUE OF 'U'"
  -- not really..
  -- dummy_input: PROCESS(wtCLK, wd_io)
  -- BEGIN
    -- IF wtCLK = '1' AND wtCLK'event THEN
      -- wd_io_mirror <= wd_io;
    -- END IF;
  -- END PROCESS dummy_input;




  -- END PROCESSES (STATE MACHINES) CODE =====

-- END IMPLEMENT ENGINE of 'CORE' ===============
END testbench_arch;
-- END ARCHITECTURE -----------------------------
