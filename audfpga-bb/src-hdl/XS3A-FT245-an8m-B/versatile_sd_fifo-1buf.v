// note the original should contain 4 buffers = 2 in, 2 out = each of 512 bytes (it corresponds to fpga_flash_fifo in versatile_fifo docs)
// then we also try to make only 2 buffers - one in, one out
// original prefixes were w b _ (Wishbone) and s d _ (SD card)
// then we rename to u s b f t _ (FTDI USB) and f p g a _ (FPGA internal) , respectively...
// NOW, here we have but one buffer - writable from one side, readable from other, with different clock domains.
// so instead of u s b f t _ and f p g a _ , will refer to r d _ and w r _ sides of the buffer..

module versatile_sd_fifo_1buf
  (
    input [7:0]  dat_i, // data input
    output [7:0] dat_o, // data output
    input 	 we_i, // write enable input - works only on wr_clk
    input 	 re_i, //read enable input -  works only on rd_clk
    input 	 wr_clk,
    input 	 rd_clk, // one buffer, but we leave this since we want dual clock

    output fifo_full, // only one buffer // actually means rptr==wptr; "exhausted"! - from async cmp
    //~ output fifo_rd_full, // when rptr== ram size, (then buffer is "full"!) // done here
    output fifo_rd_lags, // based on direction_set/clr, so we do running check, instead when we hit end of ram
    output fifo_empty, // only one buffer
    output fifo_aempty, // only one buffer - "asynchron" empty (quicker)
    input 	 rst
  );


  // only one buffer now - but keep the "1" suffixes
  // orig 9 bit - [8:0] for .ADDR_WIDTH(9)
  // ah - it seems wptr==wadr in meaning, so use only one?!
  // yes - it used to be for q (gray), and q_bin separately ...
  // comment wptr1, rptr1 as we're not using them...
  //wire [8:0] 	 wptr1, rptr1; // write, read pointer
  wire [8:0] 	 wadr1, radr1; // write, read address

  // // synthesis attribute keep of unconnected1 is true;
  // // synthesis attribute keep of unconnected2 is true;
  // wire [8:0] 	 unconnected1, unconnected2; // dummy - unused/unconnected hack; lowers ammount of warnings to just 1 with attribute keep..
  // don't use, Xst:1580 shows anyways.. just leave open, get a ton of Xst:2677 - and filter those messages in GUI

  // wire 	 dpram_we_a;
  //wire [9:0] 	 dpram_a_a, dpram_a_b;   // dpram address wire [9:0] for  .ADDR_WIDTH(9) - only one buffer now, not 10 bit wide
  wire [8:0] 	 dpram_a_a;   // dpram address - only one buffer now, but these are write & read addresses //9 bit
  wire [8:0] 	 dpram_a_b;
  wire [7:0] 	 wdat_o; // seems need to define wire for a proper connection to RAM out

  wire rstplus;
  reg rstplusR; //was wire - do not init these
  reg rstplusR2;

  // replacement variables for cke contructs below
  wire wptr_en;
  wire rptr_en;
  reg wptr_en_once; //'one-shot'-ted; cannot be wire if set in FSM
  // reg wonce_state;
  reg rptr_en_once; //'one-shot'-ted; cannot be wire if set in FSM
  // reg ronce_state;

  //~ initial begin
    //~ //wonce_state=0;
    //~ //ronce_state=0;
  //~ end

  // mind the mixup here: if we get re_i, there is byte to read from FT,
  //   which means we want to write it to our RAM,
  //   unless the fifo is *full*!
  // Hence, do *not* use rptr_en=(re_i & !fifo_aempty); - use full there!
  // same for wptr!
	assign rptr_en = (re_i & !fifo_full);
	assign wptr_en = (we_i & !fifo_aempty);

	// assign dpram_we_a = (!fifo_aempty) ? we_i : 1'b0; // this gets automatically compacted with .cke(we_i & !fifo_full), -- not used anymore
	assign dpram_a_a = wadr1; //strictly write address

   // only one buffer now - but still need this - read address
	assign dpram_a_b = radr1;
	//assign dpram_re_b = (!fifo_empty) ? re_i : 1'b0; // added - should get automatically compacted with .cke(re_i & !fifo_empty)

	assign rstplus = (rst || rstplusR || (fifo_empty & fifo_rd_lags) );

  parameter defaultAudioNullValue = 8'b10000000; // 128
  //~ assign dat_o = (fifo_empty) ? defaultAudioNullValue : wdat_o;
  // naah - to test PWM values, just leave as was
  assign dat_o = wdat_o;


  // note: in this case, USB connection runs at 2Mbps; audio over that @ 44.1 kHz
  // thus, rptr is always in a position to run faster than wptr - rptr always reaches the end of buffer first
  // to avoid buffer wrap problem, added 'fifo rd full' - when rd reached end of buffer, do not ack FT's rd requests, until wptr manages to catch up (which will then reset both rptr and wptr).
  // in versatile code; the direction (_set, _clr) should assist with that in stages;
  // but this one is easier for me to handle now...
  // NOTE that when wadr1 finally catches up with radr1 @ end (511);
  // then it is fifo_empty that becomes 1! - use that (fifo_empty & fifo_rd_full) as signal to reset counters/pointers... actually, will use direction instead
  //~ assign fifo_rd_full = (radr1 == 2**ramAddrWidth-1);
  //~ assign fifo_rd_lags = (direction_set || direction_clr); // in async_cmp.v now
  // blocking read at  fifo_rd_lags = (direction_set || direction_clr); will effectively cap usage of RAM at quarter its size
  //~ wire wfifo_rd_lags;
  //~ assign fifo_rd_lags = wfifo_rd_lags;
  // well, quarter size may be too little - go back full
  //added
  parameter ramAddrWidth = 9; //RAM size (buffer array length) 2^9 = 512
  parameter ramDataWidth = 8; //size of a single entry in RAM array (8 bits)

  assign fifo_rd_lags = (radr1 == 2**ramAddrWidth-1);


  versatile_sd_counter wptr1_cnt
  (
    .q(),		// goes to async cmp; was (wptr1); q(unconnected1),
            // .q() - explicitly unconnected port
    .q_bin(wadr1), // dpram_a_a =wadr1;
    .cke(wptr_en_once), // was wptr_en
    .clk(wr_clk), // was wr_clk
    .rst(rstplus)
  );

  versatile_sd_counter rptr1_cnt
  (
    .q(),         // was .q(rptr1), q(unconnected2) - explicitly unconnected .q()
    .q_bin(radr1),
    .cke(rptr_en_once), // was rptr_en; was .cke(re_i & !fifo_empty),
    .clk(rd_clk), //was rd_clk
    .rst(rstplus)
  );

  versatile_fifo_async_cmp
  #
  (
    .ADDR_WIDTH(9) //was for two buffers 9
  )
  cmp1
  (
    //.wptr(wptr1),
    .wptr(wadr1),
    //.rptr(rptr1),
    .rptr(radr1),
    .fifo_empty(fifo_empty),
    .fifo_aempty(fifo_aempty),
    .fifo_full(fifo_full),
    //~ .fifo_rd_lags(wfifo_rd_lags),
    .wclk(wr_clk), // was wr_clk
    .rclk(rd_clk), // was rd_clk
    .rst(rstplus)
  );


  //added // must move up
  //~ parameter ramAddrWidth = 9; //RAM size (buffer array length) 2^9 = 512
  //~ parameter ramDataWidth = 8; //size of a single entry in RAM array (8 bits)


  //only one buffer now - but still want it dual clock.. - so use vfifo_dual_port_ram_dc_sw
  vfifo_dual_port_ram_dc_sw
  #
  (
    // .ADDR_WIDTH(10), //only one buffer now, no concatenation in  assign dpram_a_ - address goes direct
    .ADDR_WIDTH(ramAddrWidth),
    .DATA_WIDTH(ramDataWidth),
    .DEFAULT_NullValue(defaultAudioNullValue)
  )/* */
  dpram
  (
    .d_a(dat_i), // strictly write data in
    .adr_a(dpram_a_b),  //strictly write address - dpram_a_a=wadr1
                        // but as we're clocked with rptr now;
                        // use dpram_a_b=radr1 which changes with that clock
    .we_a(rptr_en), // write enable - only on (posedge clk_a);
                    // was: dpram_we_a - but we write to RAM,
                    //  when there is something to read from FT245!
    .clk_a(wr_clk),  // "write" clock, was usbft_clk, was wr_clk
    .q_b(wdat_o), // strictly read data out
    .adr_b(dpram_a_a), // strictly read address  - dpram_a_b=radr1
                        // but as we're clocked with wptr now;
                        // use dpram_a_a=wadr1 which changes with that clock
    //.re_b(dpram_we_b), // read enable - only on (posedge clk_b) // added bonus to prevent XX reads..
    // going back to read enable - to ensure proper transitions?
    .re_b(wptr_en), // we read from RAM only when FPGA wants to write to FT245!
    .clk_b(rd_clk) // "read" clock, was fpga_clk, was rd_clk
  );

  // 'one-shot' state machines
  // - to avoid multiple clocking of indexes, when
  // - signals come in for read & write
  // previous state machines too complicated;
  // go with posedge detectors

  // cannot do local var syntax in synth; do the usual
  reg wptr_en_s, wptr_en_d; // local vars
  wire wcond;
  assign wcond = ((wptr_en_d == 0) && (wptr_en_s == 1));

  always @ (posedge wr_clk)
  begin: proc_wonce
    wptr_en_s <= wptr_en;   // sync to clock
    wptr_en_d <= wptr_en_s; // previous; delay for edge detect
    if (wcond) // here must use &&, not "and"; but ERROR:Simulator:1013. "Assignment subexpression is not allowed here."
      wptr_en_once <= 1;
    else
      wptr_en_once <= 0;
  end // proc_wonce


  reg rptr_en_s, rptr_en_d; // local vars

  always @ (posedge rd_clk)
  begin: proc_ronce
    rptr_en_s <= rptr_en;   // sync to clock
    rptr_en_d <= rptr_en_s; // previous; delay for edge detect
    if ((rptr_en_d == 0) && (rptr_en_s == 1)) // here must use &&, not "and"
      rptr_en_once <= 1;
    else
      rptr_en_once <= 0;
  end // proc_wonce



// this doesn't seem to change the rstplus at all - but post-route streams..
always @ (posedge wr_clk or posedge rst or posedge fifo_full)
 if (rst)
   {rstplusR, rstplusR2} <= 2'b00;
 else if (fifo_full)
   {rstplusR, rstplusR2} <= 2'b11;
 else
   {rstplusR, rstplusR2} <= {rstplusR2, fifo_full};


endmodule // versatile_sd_fifo_1buf
