//////////////////////////////////////////////////////////////////////
////                                                              ////
////  Versatile counter                                           ////
////                                                              ////
////  Description                                                 ////
////  Versatile counter, a reconfigurable binary, gray or LFSR    ////
////  counter                                                     ////
////                                                              ////
////  To Do:                                                      ////
////   - add LFSR with more taps                                  ////
////                                                              ////
////  Author(s):                                                  ////
////      - Michael Unneback, unneback@opencores.org              ////
////        ORSoC AB                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2009 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

// module name
`define CNT_MODULE_NAME versatile_sd_counter

// counter type = [BINARY, GRAY, LFSR]
//`define CNT_TYPE_BINARY
`define CNT_TYPE_GRAY
//`define CNT_TYPE_LFSR

// q as output
`define CNT_Q
// for gray type counter optional binary output
`define CNT_Q_BIN

// number of CNT bins
`define CNT_LENGTH 9

// clear
//`define CNT_CLEAR

// set
//`define CNT_SET // doesn't matter if undefined
`define CNT_SET_VALUE `CNT_LENGTH'h9

// rst
//`define CNT_RESET
//~ `define CNT_RESET_VALUE `CNT_LENGTH'h9
// set to zero on reset - matters for rst sig, even if undefined
`define CNT_RESET_VALUE `CNT_LENGTH'h0

// wrap around creates shorter cycle than maximum length
//`define CNT_WRAP // doesn't matter if undefined
`define CNT_WRAP_VALUE `CNT_LENGTH'h9

// clock enable
`define CNT_CE

// q_next as an output
//`define CNT_QNEXT

// q=0 as an output
//`define CNT_Z

// q_next=0 as a registered output
//`define CNT_ZQ


`define LFSR_LENGTH `CNT_LENGTH

module `CNT_MODULE_NAME
  (
`ifdef CNT_TYPE_GRAY
    output reg [`CNT_LENGTH:1] q,
`ifdef CNT_Q_BIN
    output [`CNT_LENGTH:1]    q_bin,
`endif
`else
`ifdef CNT_Q
    output [`CNT_LENGTH:1]    q,
`endif
`endif
`ifdef CNT_CLEAR
    input clear,
`endif
`ifdef CNT_SET
    input set,
`endif
`ifdef CNT_REW
    input rew,
`endif
`ifdef CNT_CE
    input cke,
`endif
`ifdef CNT_QNEXT
    output [`CNT_LENGTH:1] q_next,
`endif
`ifdef CNT_Z
    output z,
`endif
`ifdef CNT_ZQ
    output reg zq,
`endif
    input clk,
    input rst
   );

`ifdef CNT_SET
   parameter set_value = `CNT_SET_VALUE;
`endif
`ifdef CNT_WRAP
   parameter wrap_value = `CNT_WRAP_VALUE;
`endif

   // internal q reg
   reg [`CNT_LENGTH:1] qi;

`ifdef CNT_QNEXT
`else
   wire [`CNT_LENGTH:1] q_next;
`endif
`ifdef CNT_REW
   wire [`CNT_LENGTH:1] q_next_fw;
   wire [`CNT_LENGTH:1] q_next_rew;
`endif

`ifdef CNT_REW
`else
   assign q_next =
`endif
`ifdef CNT_REW
     assign q_next_fw =
`endif
`ifdef CNT_CLEAR
       clear ? `CNT_LENGTH'd0 :
`endif
`ifdef CNT_SET
	 set ? set_value :
`endif
`ifdef CNT_WRAP
	   (qi == wrap_value) ? `CNT_LENGTH'd0 :
`endif
`ifdef CNT_TYPE_LFSR
	     {qi[8:1],~(qi[`LFSR_LENGTH]^qi[1])};
`else
   qi + `CNT_LENGTH'd1;
`endif

`ifdef CNT_REW
   assign q_next_rew =
`ifdef CNT_CLEAR
     clear ? `CNT_LENGTH'd0 :
`endif
`ifdef CNT_SET
       set ? set_value :
`endif
`ifdef CNT_WRAP
	 (qi == `CNT_LENGTH'd0) ? wrap_value :
`endif
`ifdef CNT_TYPE_LFSR
	   {~(qi[1]^qi[2]),qi[`CNT_LENGTH:2]};
`else
   qi - `CNT_LENGTH'd1;
`endif
`endif

`ifdef CNT_REW
   assign q_next = rew ? q_next_rew : q_next_fw;
`endif

   always @ (posedge clk or posedge rst)
     if (rst)
       qi <= `CNT_LENGTH'd0;
     else
`ifdef CNT_CE
   if (cke)
`endif
     qi <= q_next;

`ifdef CNT_Q
`ifdef CNT_TYPE_GRAY
   always @ (posedge clk or posedge rst)
     if (rst)
       q <= `CNT_RESET_VALUE;
     else
`ifdef CNT_CE
       if (cke)
`endif
	 q <= (q_next>>1) ^ q_next;
`ifdef CNT_Q_BIN
   assign q_bin = qi;
`endif
`else
   assign q = q_next;
`endif
`endif

`ifdef CNT_Z
   assign z = (q == `CNT_LENGTH'd0);
`endif

`ifdef CNT_ZQ
   always @ (posedge clk or posedge rst)
     if (rst)
       zq <= 1'b1;
     else
`ifdef CNT_CE
       if (cke)
`endif
	 zq <= q_next == `CNT_LENGTH'd0;
`endif
endmodule
