`timescale 1ns/1ps
module register(
	clk, 
	dataIn,
	dataOut,
	reset,
	wrEn
);
	//--------------------------------------------------------------------------------------
	parameter LEN = 9;

    //--------------------------------------------------------------------------------------
    input              clk;
    input              reset;
    input              wrEn;
    input[LEN - 1: 0]  dataIn;
    output[LEN - 1: 0] dataOut;

    //--------------------------------------------------------------------------------------
    reg[LEN - 1: 0] data;

    //--------------------------------------------------------------------------------------
    always @(posedge clk) begin
    	if (reset)
        	data <= 0;
    	
    	else if (wrEn)
        	data <= dataIn; 	
    end

    //--------------------------------------------------------------------------------------
    assign dataOut = data;	

endmodule

	
