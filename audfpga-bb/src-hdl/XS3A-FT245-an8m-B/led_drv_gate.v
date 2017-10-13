//////////////////////////////////////////////////////////////////////////////////
// sdaau <sd[at]imi.aau.dk>, 2011
///////////////////////////////////////////////////////////////////////////////
// This source file is free software: you can redistribute it and/or modify //
// it under the terms of the GNU General Public License as published        //
// by the Free Software Foundation, either version 3 of the License, or     //
// (at your option) any later version.                                      //
//                                                                          //
// This source file is distributed in the hope that it will be useful,      //
// but WITHOUT ANY WARRANTY; without even the implied warranty of           //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            //
// GNU General Public License for more details.                             //
//                                                                          //
// You should have received a copy of the GNU General Public License        //
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    //
//////////////////////////////////////////////////////////////////////////////////



// we want to start a led signal each time a pulse comes in,
// and then keep it up around a 1 ms
// for clock 20 ns, 1 us = 1000 ns / 20 ns = 50; 10 us = 500;
// so counter up to 512=2^9
// 10 us ok for stream rd, but not for typing..
// 100 us => 5000 steps; 8192=2^13 ; visible typing, but not too much
// 500 us => 25000 steps; 32768=2^15 ; still a bit too little on typing
// 1 ms => 50000 steps; 65536=2^16 ; seems as good as it gets

// freq div? same thing as counter.. 20*2*2*2*2*2*2 = 1280 = 640 ns

`define MAXCOUNTSIZE 16

module led_drv_gate (
clk				, // clock
reset			, // Active high, syn reset
insig			, // input signal to be replicated
outled			  // output gated signal to drive a led
);

	input	clk,reset;
	input	insig;

	output	outled;
	reg outled; // so we can change it

	// constants
	parameter SIZE = 2;
	// ledstates
	parameter IDLE = 2'b00;
	parameter wait_for_incoming = 2'b01;
	parameter led_is_on = 2'b10;
	parameter led_is_off = 2'b11;

	parameter MAXCOUNT = 50000;
	parameter MAXCOUNTSIZE = `MAXCOUNTSIZE;

	// intern vars
	reg [MAXCOUNTSIZE-1:0]	led_counter = `MAXCOUNTSIZE'd0;
	reg [SIZE-1:0]			ledstate        = IDLE;


always @ (posedge clk)
begin : FSM_led
if (reset == 1'b1)
	begin
		//~ ledstate <= #1 IDLE; // WARNING:Xst:916 - "led_drv_gate.v" line 64: Delay is ignored for synthesis.
		ledstate <= IDLE;
		// gnt_0 <= 0;
	end
else
	case(ledstate)
		IDLE :
		begin
			ledstate <= wait_for_incoming;
			led_counter <= `MAXCOUNTSIZE'd0;
			outled <= 1'b0;
		end

		wait_for_incoming :
		if (insig == 1'b1)
			begin
				ledstate <= led_is_on;
			end
		else // insig == 1'b0
			begin
				ledstate <= wait_for_incoming;
			end

		led_is_on :
		if (led_counter < MAXCOUNT)
			begin
				ledstate <= led_is_on;
				led_counter <= led_counter + 1;
				outled <= 1'b1;
			end
		else // insig == 1'b0
			begin
				ledstate <= led_is_off;
			end

		led_is_off :
		begin
			ledstate <= IDLE;
			outled <= 1'b0;
		end

		default : ledstate <= IDLE;
	endcase
end

endmodule // End of Module arbiter

