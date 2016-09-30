`timescale 1ns/1ps

module buffer(
	clk,
	reset,
	wrt,
	wrt_addr,
	rd_addr,
	data_in,
	data_out
);

	//--------------------------------------------------------------------------------------
	parameter addrLen = 6;
	parameter dataLen = 32;
	parameter memSize = 1 << addrLen;
	parameter ram_type = "distributed";
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	
	input wrt;
	
	input [ addrLen - 1 : 0 ] wrt_addr;
	input [ addrLen - 1 : 0 ] rd_addr;
	input [ dataLen - 1 : 0 ] data_in;
	
	output reg [ dataLen - 1 : 0 ] data_out;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	(* ram_style = ram_type *)
	reg [ dataLen - 1 : 0 ] mem [ 0 : memSize - 1 ];
	//--------------------------------------------------------------------------------------
	
	always @(posedge clk) begin
		data_out <= mem[rd_addr];
		
		if (wrt == 1) 
			mem[wrt_addr] <= data_in;
	end

endmodule


module bufferRD(
	clk,
	reset,
	wrt,
	wrt_addr,
	rd_addr,
	data_in,
	data_out
);

	//--------------------------------------------------------------------------------------
	parameter addrLen = 6;
	parameter dataLen = 32;
	parameter memSize = 1 << addrLen;
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	input clk;
	input reset;
	
	input wrt;
	
	input [ addrLen - 1 : 0 ] wrt_addr;
	input [ addrLen - 1 : 0 ] rd_addr;
	input [ dataLen - 1 : 0 ] data_in;
	
	output [ dataLen - 1 : 0 ] data_out;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	reg [ dataLen - 1 : 0 ] mem [ 0 : memSize - 1 ];
	//--------------------------------------------------------------------------------------
	
	always @(posedge clk) begin
		if (wrt == 1) mem[wrt_addr] <= data_in;
	end
	
	assign data_out = mem[rd_addr];

endmodule
