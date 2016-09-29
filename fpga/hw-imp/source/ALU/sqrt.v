`timescale 1ns/1ps
module sqrt (
	in,	//in should be unsigned
  	out,
  	rout,
  	done
);
	//--------------------------------------------------------------------------------------
	parameter inLen = 32;	//length of sqrt is dataLen/2
	parameter rLen = inLen / 2 + 1;
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	input [inLen - 1 : 0 ]  in;
	output [inLen / 2 - 1 : 0 ] out;
	output [rLen - 1 : 0] rout;
	output done;
	//--------------------------------------------------------------------------------------
integer i;
reg [rLen - 1 : 0] r;
reg [inLen / 2 - 1 : 0] q;

always @ (in) begin
	r = 0;
	q = 0;
	for (i = inLen / 2 - 1; i >= 0 ; i = i - 1) begin
		#1
		if (r[rLen - 1] == 0) begin
			r = (r << 2) | (in >> (i + i) & 3);
			r = r - ((q << 2) | 1);
		end else begin
			r = (r << 2) | (in >> (i + i) & 3);
			r = r + ((q << 2) | 3);
		end

		if (r[rLen - 1] == 0) begin
			q = (q << 1) | 1;
		end else begin
			q = (q << 1) | 0;
		end
	end
end
assign out = q;
assign rout = r;

assign done = 1;
endmodule
