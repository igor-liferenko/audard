module vfifo_dual_port_ram_dc_sw
  (
   d_a,
   adr_a,
   we_a,
   clk_a,
   q_b,
   adr_b,
   re_b, //used to have this commented
   clk_b
   );
   parameter DATA_WIDTH = 8;
   parameter ADDR_WIDTH = 9;
   input [(DATA_WIDTH-1):0]      d_a;
   input [(ADDR_WIDTH-1):0] 	 adr_a;
   input [(ADDR_WIDTH-1):0] 	 adr_b;
   input 			 we_a;
   input 			 re_b; //used to have this commented
   output [(DATA_WIDTH-1):0] 	 q_b;
   input 			 clk_a, clk_b;
   reg [(ADDR_WIDTH-1):0] 	 adr_b_reg;
   reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0] ; //exponentiation, 2^ADDR_WIDTH, reg[7:0] ram [511:0]

   //~ initial begin adr_b_reg = 'b0 ; end // no need, change CNT_RESET_VALUE in versatile_sd_counter;

   always @ (posedge clk_a)
   if (we_a)
     ram[adr_a] <= d_a;
   always @ (negedge clk_b) // was posedge
   if (re_b)
     adr_b_reg <= adr_b;
   assign q_b = ram[adr_b_reg];
endmodule
