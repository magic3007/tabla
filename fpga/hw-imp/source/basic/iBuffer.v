`timescale 1ns/1ps
(* rom_extract = "yes" *)
module iBuffer (
	clk,
	rdAddr,
	dataOut
);
	//--------------------------------------------------------------------------------------
	parameter integer addrLen = 5;
	parameter integer dataLen = 32;
	parameter integer peId	= 1;
	parameter type	= "block";
	
	localparam integer unit = peId%10 + 'h30;
	localparam integer tens = peId/10%10 + 'h30;
	localparam init = {"hw-imp/source/instructions/pe", tens, unit, ".txt"};

	//--------------------------------------------------------------------------------------
	input clk;
	input[addrLen - 1: 0] rdAddr;
	output reg[dataLen - 1: 0] dataOut;

	//--------------------------------------------------------------------------------------
	reg[dataLen - 1: 0] mem	[0: (1 << addrLen) - 1];
	
    reg     [addrLen-1:0]	address;
    (* rom_style = type, Keep = "true" *)
    reg     [dataLen-1:0]	rdata;
	
	// ******************************************************************
	// Initialization
	// ******************************************************************
	initial $readmemb (init, mem);

	//-------------------------------------------------------------------------------------
 	always @(posedge clk) begin
        dataOut <= mem[rdAddr];
	end
	
endmodule