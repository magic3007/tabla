`timescale 1ns/1ps
module Cnter (
	clk,
	reset,
	wrt,
	cnt,
	dataIn,
	dataOut
);
	//--------------------------------------------------------------------------------------
	parameter len = 5;
	
	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	input wrt;
	input cnt;
	input[len - 1: 0] dataIn;
	output[len - 1: 0] dataOut;
	
	//--------------------------------------------------------------------------------------
	reg[len - 1: 0] data;
		
	//--------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		if (reset)
			data <= 0;
		
		else if (wrt)
			data <= dataIn;
		
		else if (cnt)
			data <= data + 1;

	end
	
	//--------------------------------------------------------------------------------------
	assign dataOut = data;

endmodule
