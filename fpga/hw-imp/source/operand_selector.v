`timescale 1ns/1ps
module op_selector(
  	sel,
  	weight,
  	data,
  	gradient,
  	interim,
  	meta,
  	neigh,
  	bus,
  	out
);

	// *****************************************************************************
	parameter LEN = 8;
	
	// *****************************************************************************
	input     [2:0]        sel;
	input     [LEN-1 : 0]  weight;
	input     [LEN-1 : 0]  data;
	input     [LEN-1 : 0]  gradient;
	input     [LEN-1 : 0]  interim;
	input     [LEN-1 : 0]  meta;
	input     [LEN-1 : 0]  neigh;
	input     [LEN-1 : 0]  bus;
	output    [LEN-1 : 0]  out;


	// *****************************************************************************
	wire [LEN-1 : 0] out1;
	wire [LEN-1 : 0] out2;
	wire [LEN-1 : 0] out3;
	wire [LEN-1 : 0] out4;
	wire [LEN-1 : 0] out5;
	wire [LEN-1 : 0] out6;

	assign out1 = sel[0] ? weight : 0;
	assign out2 = sel[0] ? gradient: data;
	assign out3 = sel[0] ? meta: interim;
	assign out4 = sel[0] ? bus: neigh;

	assign out5 = sel[1] ? out2 : out1;
	assign out6 = sel[1] ? out4 : out3;

	assign out = sel[2] ? out6 : out5;

endmodule
