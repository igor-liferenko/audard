module versatile_fifo_async_cmp ( wptr, rptr, fifo_empty, fifo_aempty, fifo_full, wclk, rclk, rst ); //fifo_rd_lags

  parameter ADDR_WIDTH = 4;
  parameter N = ADDR_WIDTH-1;

  parameter Q1 = 2'b00;
  parameter Q2 = 2'b01;
  parameter Q3 = 2'b11;
  parameter Q4 = 2'b10;

  parameter going_empty = 1'b0;
  parameter going_full  = 1'b1;

  input [N:0]  wptr, rptr;
  output reg	fifo_empty, fifo_full;
  // WARNING:Xst:1426 can be ignored - but leaving these as they were:
  //~ output fifo_rd_lags;
  // output reg	fifo_empty = 1'b0; //ISE: WARNING:Xst:1426 - The value init of the FF/Latch fifo_empty hinder the constant cleaning in the block cmp1.    You should achieve better results by setting this init to 0. // ONLY if connections are to reg/signal, and not to real pins
  // output reg	fifo_full; //output reg	fifo_full = 1'b1;  //Xst:1426 - The value init of the FF/Latch fifo_full hinder the constant cleaning in the block cmp1.    You should achieve better results by setting this init to 1. // if all are set here, then cmp1 and cmp2  are removed from the design.
  input 	wclk, rclk, rst;

  reg 	direction, direction_set, direction_clr;
  // reg 	direction = 1'b1; //ISE: WARNING:Xst:1426 - The value init of the FF/Latch direction hinder the constant cleaning in the block cmp1.    You should achieve better results by setting this init to 1. // ONLY if connections are to reg/signal, and not to real pins
  // reg 	direction_set, direction_clr;

  output fifo_aempty;
  //reg fifo_aempty;
  //output async_full;
  wire async_empty, async_full;
  reg 	fifo_full2, fifo_empty2;
  // reg 	fifo_empty2 = 1'b0;    //ISE: The value init of the FF/Latch fifo_empty2 hinder the constant cleaning in the block cmp1.    You should achieve better results by setting this init to 0. // ONLY if connections are to reg/signal, and not to real pins
  // reg 	fifo_full2;   //reg 	fifo_full2 = 1'b1;  //The value init of the FF/Latch cmp1/fifo_full2 hinder the constant cleaning in the block versatile_sd_fifo_2buf.    You should achieve better results by setting this init to 1. // if all are set here, then cmp1 and cmp2  are removed from the design.

// added
initial begin
  fifo_full2=0; //
  fifo_empty2=1; //
  fifo_empty=1;
  fifo_full=0;
end

  // direction_set
  always @ (wptr[N:N-1] or rptr[N:N-1])
    case ({wptr[N:N-1],rptr[N:N-1]})
      {Q1,Q2} : direction_set <= 1'b1;
      {Q2,Q3} : direction_set <= 1'b1;
      {Q3,Q4} : direction_set <= 1'b1;
      {Q4,Q1} : direction_set <= 1'b1;
      default : direction_set <= 1'b0;
    endcase

  // direction_clear
  always @ (wptr[N:N-1] or rptr[N:N-1] or rst)
    if (rst)
      direction_clr <= 1'b1;
    else
      case ({wptr[N:N-1],rptr[N:N-1]})
        {Q2,Q1} : direction_clr <= 1'b1;
        {Q3,Q2} : direction_clr <= 1'b1;
        {Q4,Q3} : direction_clr <= 1'b1;
        {Q1,Q4} : direction_clr <= 1'b1;
        default : direction_clr <= 1'b0;
      endcase

  // yup - so, without the posedge in always - and with encapsulating "if (direction_set)" (so all states are defined in VHDL-ish way) - the WARNING:PhysDesignRules:372 - Gated clock. is now gone !!

  always @ (direction_set or direction_clr)
    if (direction_set)
      if (direction_clr)
        //if (direction_set) direction <= going_full; // impossible to have the both 1, but to prevent treatment of direction_set as clock - no help
         //else
        direction <= going_empty;
      else
        direction <= going_full;
    else
      direction <= going_empty;

  // synthesis attribute ASYNC_REG of direction_set is "TRUE";
  // synthesis attribute ASYNC_REG of async_full is "TRUE";
  // synthesis attribute ASYNC_REG of async_empty is "TRUE";
  // synthesis attribute ASYNC_REG of fifo_aempty is "TRUE";
  assign async_empty = (wptr == rptr) && (direction==going_empty);
  assign async_full  = (wptr == rptr) && (direction==going_full);
  //wire out ;
  assign fifo_aempty = (wptr == rptr)  ? 1'b1 : 1'b0;

  // NOTE that when wadr1 finally catches up with radr1 @ end (511);
  // then it is fifo_empty that becomes 1! - use that (fifo_empty & fifo_rd_full) as signal to reset counters/pointers???... actually, will use direction instead
  // direction_set is when radr=01xx.. > wadr=00xx... / radr=11xx.. > wadr=01xx...
  // direction_clr is when radr=10xx.. > wadr=00xx... / radr=11xx.. > wadr=10xx...
  // in set we lag a little - in clr we lag a lot; in either of these, wait for wr to catch up?
  // then will not have to reset counters?
  //~ assign fifo_rd_lags = (direction_set || direction_clr); // // effectively sets limit at quarter RAM..

  always @ (posedge wclk or posedge rst or posedge async_full)
    if (rst)
      {fifo_full, fifo_full2} <= 2'b00;
    else if (async_full)
      {fifo_full, fifo_full2} <= 2'b11;
    else
      {fifo_full, fifo_full2} <= {fifo_full2, async_full};

  //assign fifo_aempty = async_empty; // Reference to scalar reg 'fifo_aempty' is not a legal net lvalue // Reference to scalar wire 'fifo_aempty' is not a legal reg or variable lvalue


  always @ (posedge rclk or posedge async_empty)
  begin
    //fifo_aempty <= async_empty; // Xst:899 - datainout.v line 27: The logic for fifo_aempty does not match a known FF or Latch template.  //seems if we are in posedge async_empty, can't use it to assign? but below? //
    if (async_empty)
      {fifo_empty, fifo_empty2} <= 2'b11;
    else
      {fifo_empty,fifo_empty2} <= {fifo_empty2,async_empty};
  end

endmodule // async_comp
