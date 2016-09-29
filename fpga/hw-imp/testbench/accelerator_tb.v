module  accelerator_tb;
	// ******************************************************************
	// PARAMETERS
	// ******************************************************************
	localparam logNumPu					= 3;
	localparam logNumPe					= 3;
	localparam memDataLen				= 16;  //width of the data coming from the memory
	localparam dataLen					= 16;
	localparam indexLen					= 8; 
    localparam logMemNamespaces       	= 2;  //instruction, data, weight, meta
    localparam logNumMemColumns			= 4;	
    
	localparam numPe                 	= 1 << logNumPe;
    localparam numPu                 	= 1 << logNumPu; 
    localparam peBusIndexLen         	= logNumPe + 1;
    localparam gbBusIndexLen         	= logNumPu + 1;
    localparam numMemColumns			= 1 << logNumMemColumns;
    localparam numPuMemColumns 			= numMemColumns/numPu;
    localparam logNumPeMemColumn		= logNumPu + logNumPe - logNumMemColumns;
    localparam memCtrlIn				= logMemNamespaces + (logNumPeMemColumn+1)*numMemColumns;
    
	reg reset;
	reg clk;
	reg start;
	reg mem_rd_wrt;
	reg [memCtrlIn - 1 : 0] 				mem_ctrl_in;

    reg [memDataLen*numMemColumns - 1 : 0] 	mem_data_input;
    wire [memDataLen*numMemColumns - 1 : 0]  				mem_data_output;
    
    wire                            		eol;
    wire                            		eoc;

	accelerator #(
		.logNumPu(logNumPu),
		.logNumPe(logNumPe),
		.memDataLen(memDataLen),  //width of the data coming from the memory
		.dataLen(dataLen),
		.indexLen(indexLen),
    	.logMemNamespaces(logMemNamespaces)  //instruction, data, weight, meta
	)
	accelerator_unit(
    	.clk(clk),
    	.reset(reset),
    	.start(start),
    	.mem_rd_wrt(mem_rd_wrt),
   	 	.mem_ctrl_in(mem_ctrl_in),
    	.mem_data_input(mem_data_input),
    	.mem_data_output(mem_data_output),
       
    	.eol(eol),
    	.eoc(eoc)
	);
	
	
	always #5 clk = ~clk;

	initial
    begin
        $dumpfile("hw-imp/bin/waveform/accelerator_tb.vcd");
        $dumpvars(0,accelerator_tb);
    end
    
    
   	initial begin
   	clk = 0;
   	reset = 1;
   	start = 0;
   	mem_rd_wrt = 0;

	#10
	reset = 0;
	mem_ctrl_in = 50'b100;
    mem_data_input = 256'b0000000000000000;
	
	#10 mem_data_input = 256'b0100000000010000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10	mem_data_input	= 256'b01010;
	
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0100000001000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000010000000;
	#10	mem_data_input	= 256'b00010;
	
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0100000010101000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000100000000;
	#10	mem_data_input = 256'b01010;
	
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000010110000;
	#10 mem_data_input = 256'b0001111000001101;
	#10 mem_data_input = 256'b0000000111100000;
	#10	mem_data_input = 256'b01010;
	
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10	mem_data_input = 256'b0000000000000000;
	
	#10 mem_ctrl_in = 50'b101; 
		mem_data_input = 256'h12;
		
	#10 mem_ctrl_in = 50'b110; 
		mem_data_input = 16'h34;
	
	#10 mem_ctrl_in = 50'b101; 
		mem_data_input = 16'h56;
		
	#10 mem_ctrl_in = 50'b110; 
		mem_data_input = 16'h78;
	
	#10 mem_ctrl_in = 50'b110; 
		mem_data_input = 16'h9A;
	
	#10 mem_ctrl_in = 50'b111; 
		mem_data_input = 16'h12;
	
	#10 mem_ctrl_in = 50'b1100; 
		mem_data_input = 256'b0000000000000000;
		
	#10 mem_data_input = 256'b0100000000010000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000001100000;
	#10	mem_data_input = 256'b01110;
	
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b0000000000000000;
	#10	mem_data_input = 256'b0000000000000000;
	
	
	#10 mem_ctrl_in = 50'b1101;
		mem_data_input  = 3;
		
	#10 mem_ctrl_in = 50'b1110;
		mem_data_input  = 18;
	
	#10 mem_ctrl_in = 50'b11100;
		mem_data_input = 256'b0000000000000000;
		
	#10 mem_data_input = 256'b1000000000111000;
	#10 mem_data_input = 256'b0000000000000000;
	#10 mem_data_input = 256'b000000000000000;
	#10	mem_data_input = 256'b00110;
	
	#10 mem_ctrl_in = 50'b11101;
		mem_data_input  = 121;
	
		
	#10 mem_ctrl_in = 50'b0;
	
	#5 start = 1;
	
	#10
	start = 0;
	
	#400
	$finish;
	
	end
endmodule
