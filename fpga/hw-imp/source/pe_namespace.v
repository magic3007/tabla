`timescale 1ns/1ps
module pe_namespace(
	clk,
	reset,	
	start,
//	inst_restart,
	lastInst,
	
	inst_stall,
	bus_contention,
	
	inst_out,
	inst_valid,

	data_wrt,
	data_wrt_addr,
	data_rd_addr,
	data_in,
	data_out,
	
	weight_wrt,
	weight_wrt_addr,
	weight_rd_addr,
	weight_in,
	weight_out,
	
	gradient_wrt,
	gradient_wrt_addr,
	gradient_rd_addr,
	gradient_in,
	gradient_out,
	
	meta_wrt,
	meta_wrt_addr,
	meta_rd_addr,
	meta_in,
	meta_out
);

	//this memory space comprises of the different sematically defined buffers: instruction, data, weights, gradient and meta
	
	//--------------------------------------------------------------------------------------
	parameter instAddrLen = 6;
	parameter dataLen = 32;
	parameter instLen = 32;
	parameter dataAddrLen = 5;
	parameter weightAddrLen = 5;
	parameter metaAddrLen = 2;
	parameter peId = 0;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	input start;
//	input inst_restart;
	
	input inst_wrt;
	input [instLen - 1: 0] 		inst_in;
	input inst_stall;
	input bus_contention;
	
	output [instLen - 1: 0] 		inst_out;
	output inst_fifo_full;
	output inst_valid;
	
	output lastInst;
	
	input data_wrt;
	input [dataAddrLen - 1 : 0] 	data_wrt_addr;
	input [dataAddrLen - 1 : 0] 	data_rd_addr;
	input [dataLen - 1 : 0 ] 		data_in;
	output [dataLen - 1 : 0 ] 		data_out;
	
	input weight_wrt;
	input [weightAddrLen - 1 : 0 ] 	weight_wrt_addr;
	input [weightAddrLen - 1 : 0 ]	weight_rd_addr;
	input [dataLen - 1 : 0 ]		weight_in;
	output [dataLen - 1 : 0 ]		weight_out;
	
	input gradient_wrt;
	input [weightAddrLen - 1 : 0 ] 	gradient_wrt_addr;
	input [weightAddrLen - 1 : 0 ] 	gradient_rd_addr;
	input [dataLen - 1 : 0 ]		gradient_in;
	output [dataLen - 1 : 0 ]		gradient_out;
	
	input meta_wrt;
	input [metaAddrLen - 1 : 0 ]	meta_wrt_addr;
	input [metaAddrLen - 1 : 0 ]	meta_rd_addr;
	input [dataLen - 1 : 0 ]		meta_in;
	output [dataLen - 1 : 0 ]		meta_out;
	//--------------------------------------------------------------------------------------

	//Instruction Buffer
	//--------------------------------------------------------------------------------------
	//wire inst_fifo_empty;
	
	wire startIn, startOut;
	wire lastInstIn, lastInstOut;
	
	assign lastInstIn = (inst_out == 0) && ~lastInstOut;

	assign startIn = (startOut || start) && ~lastInstIn;
	
	assign lastInst = lastInstIn;
	
	register#(.LEN(1))
	regStart(
		.clk(clk), 
		.dataIn(startIn),
		.dataOut(startOut),
		.reset(reset),
		.wrEn(~inst_stall && ~bus_contention)
	);
	
	register#(.LEN(1))
	regInstEnd(
		.clk(clk), 
		.dataIn(lastInstIn),
		.dataOut(lastInstOut),
		.reset(reset),
		.wrEn(~inst_stall && ~bus_contention)
	);
	
 	rdFifo #(.addrLen(instAddrLen), .dataLen(instLen)) 
 	instrFifo(
		.clk(clk),
		.reset(reset),

		.rd(~inst_stall && ~bus_contention && startIn),
		
		.restart(lastInstIn),
	
		.dataOut(inst_out)
	);
	
	assign inst_valid = startOut;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	//Data Buffer
	buffer #( .addrLen(dataAddrLen), .dataLen(dataLen), .ram_type ("block")  )
	dataBuffer( 
		clk,
		reset,
		data_wrt,
		data_wrt_addr,
		data_rd_addr,
		data_in,
		data_out
	);
	
	//--------------------------------------------------------------------------------------
	//weight Buffer
	buffer #( .addrLen(weightAddrLen), .dataLen(dataLen), .ram_type ("block")  )
	weightBuffer( 
		clk,
		reset,
		weight_wrt,
		weight_wrt_addr,
		weight_rd_addr,
		weight_in,
		weight_out
	);

	//--------------------------------------------------------------------------------------
	//gradient Buffer
	buffer #( .addrLen(weightAddrLen), .dataLen(dataLen), .ram_type ("block") )
	gradientBuffer( 
		clk,
		reset,
		gradient_wrt,
		gradient_wrt_addr,
		gradient_rd_addr,
		gradient_in,
		gradient_out
	);	
	
	//--------------------------------------------------------------------------------------
	//meta Buffer
	buffer #( .addrLen(metaAddrLen), .dataLen(dataLen), .ram_type ("distributed") )
	metaBuffer( 
		clk,
		reset,
		meta_wrt,
		meta_wrt_addr,
		meta_rd_addr,
		meta_in,
		meta_out
	);	
	//--------------------------------------------------------------------------------------
	
endmodule
