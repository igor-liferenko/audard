//http://www.myhdl.org/doku.php/projects:ft245r
module busFT245if( clk,
                rxf_n_i, txe_n_i, rd_n_o, wr_o, d_io,
                rxf_n_o, txe_n_o, rd_n_i, wr_i, d_read_o, d_write_i);

  input         clk;

  // interface to USB module
  input         rxf_n_i;
  input         txe_n_i;
  output        rd_n_o;
  output        wr_o;
  inout   [7:0] d_io;
  wire    [7:0] d_io;
  reg     [7:0] tmp_d_io;

  // interface to MyHDL logic
  output        rxf_n_o;
  output        txe_n_o;
  input         rd_n_i;
  input         wr_i;
  output  [7:0] d_read_o;
  wire    [7:0] d_read_o;
  input   [7:0] d_write_i;
  wire    [7:0] d_write_i;

  // initialize the registers - else the synthesizer optimizes them away!
  // but, apparently not as zeroes - else they end up driving bus!
  reg [7:0] d_write_reg = 8'bzzzzzzzz; // 8'b00000000;
  reg [7:0] d_io_reg = 8'bzzzzzzzz; // 8'b00000000;
  wire is_d_io_active = 1'bz;
  wire databus_zero = 1'bz;

  // signals from USB module
  assign rxf_n_o = rxf_n_i;
  assign txe_n_o = txe_n_i;

  // signals to USB module
  assign wr_o = wr_i;
  assign rd_n_o = rd_n_i;


  assign d_io = tmp_d_io;

  // in ISE, the tri-state buffer buft needs active low;
  // so synthesizer tries to autohandle that, but note
  // it does !(A)+!(B) = !(A&B)
  // wr_i = 1 - want to write; rd_n_i = cannot read; is_d_io_active = is_write_direction
  assign is_d_io_active = (wr_i & rd_n_i); // good for debug :)
  // assign d_io = (is_d_io_active) ? d_write_reg : 8'bz; // was : 8'bz or : d_io
  assign d_read_o = (!is_d_io_active) ? d_io_reg : 8'bz; // added, was  = d_io_reg
  assign databus_zero = (tmp_d_io == 8'b0) ? 1'b1 : 1'b0 ;


  always@(posedge clk) begin
    if (is_d_io_active == 1'b1)
      begin
		tmp_d_io <= d_write_reg;
      end
	else
      begin
		tmp_d_io <=  8'bz;
      end
    //~ if (is_d_io_active == 1'b1)
      //~ begin
        d_write_reg <= d_write_i;
      //~ end
    //~ else
      //~ begin
        d_io_reg <= tmp_d_io;
      //~ end
    //d_read_o <= d_io_reg;  //"Illegal left hand side of nonblocking assignment"
                                          // use 'assign d_read_o = d_io_reg;' instead
  end

endmodule

