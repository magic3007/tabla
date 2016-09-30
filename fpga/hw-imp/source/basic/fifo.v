`timescale 1ns/1ps
module Fifo (
	clk,
	reset,

	rd,
	wrt,
	
	restart,
	
	dataOut,
	dataIn,

	empty,
	full
);
	//--------------------------------------------------------------------------------------
	parameter addrLen = 5;
	parameter dataLen = 32;

	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	
	input rd;
	input wrt;
	
	input restart;
	
	output[dataLen - 1: 0] dataOut;
	input[dataLen - 1: 0]  dataIn;
	
	output empty;
	output full;

	//--------------------------------------------------------------------------------------
	wire headCntEn;
	wire[addrLen - 1: 0] headIn;
	wire[addrLen - 1: 0] headOut;

	wire tailCntEn;
	wire[addrLen - 1: 0] tailIn;
	wire[addrLen - 1: 0] tailOut;

	wire fullEmptyBWrt;
	wire fullEmptyBIn;
	wire fullEmptyBOut;

	wire headTailEq;

	//--------------------------------------------------------------------------------------
	assign headCntEn = (rd & ~empty);
	assign headIn = 0;
	
	Cnter #(addrLen) head (
		clk,
		reset || restart,
		1'b0,
		headCntEn,
		headIn,
		headOut
	);

	//--------------------------------------------------------------------------------------
	assign tailCntEn = (wrt & ~full);
	assign tailIn = 0;
	
	Cnter #(addrLen) tail (
		clk,
		reset,
		1'b0,
		tailCntEn,
		tailIn,
		tailOut
	);

	//--------------------------------------------------------------------------------------
	assign fullEmptyBWrt = rd ^ wrt;
	assign fullEmptyBIn = wrt;
	
	FlipFlop fullEmptyB (
		clk,
		reset,
		fullEmptyBWrt,
		fullEmptyBIn,
		fullEmptyBOut
	);

	//--------------------------------------------------------------------------------------
	assign headTailEq = (headOut == tailOut);
	
	assign empty = (~fullEmptyBOut & headTailEq);
	assign full  = (fullEmptyBOut & headTailEq);
	
	//wire [dataLen - 1: 0] data0, data1, data2, data3;
	
	//--------------------------------------------------------------------------------------
	DpRegFile #(addrLen, dataLen) dpRegFile (
		clk,
		reset,
		headCntEn,
		tailCntEn,
		headOut,
		tailOut,
		dataOut,
		dataIn
	);

endmodule
