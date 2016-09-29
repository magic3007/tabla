`timescale 1ns/1ps
module rdFifo (
	clk,
	reset,

	rd,
	
	restart,
	
	dataOut
);
	//--------------------------------------------------------------------------------------
	parameter addrLen = 5;
	parameter dataLen = 32;
	parameter peId = 0;

	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	
	input rd;
	
	input restart;
	
	output[dataLen - 1: 0] dataOut;

	//--------------------------------------------------------------------------------------
	wire headCntEn;
	wire[addrLen - 1: 0] headIn;
	wire[addrLen - 1: 0] headOut;

	wire fullEmptyBWrt;
	wire fullEmptyBIn;
	wire fullEmptyBOut;

	wire headTailEq;

	//--------------------------------------------------------------------------------------
	assign headIn = 0;
	
	Cnter #(addrLen) head (
		clk,
		reset,
		restart,
		rd,
		headIn,
		headOut
	);
	
	//--------------------------------------------------------------------------------------
	iBuffer #(
		.addrLen(addrLen), 
		.dataLen(dataLen), 
		.peId(peId)
	) 
	inst_buffer (
		.clk(clk),
		.rdAddr(headOut),
		.dataOut(dataOut)
	);

endmodule
