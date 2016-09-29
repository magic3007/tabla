`timescale 1ns/1ps

`include "inst.vh"
`include "config.vh"

module accelerator
#(
	//DESIGN BUILDER TOUCH
    parameter numPeValid			= `NUM_PE_VALID,
    //DESIGN BUILDER UNTOUCH
    
    parameter logNumPu              = 3,
    parameter logNumPe              = 3,
    parameter memDataLen            = 16, //width of the data coming from the memory
    parameter dataLen               = 16,
    parameter indexLen              = 8,
    parameter logMemNamespaces      = 2,  //instruction, data, weight, meta
    parameter logNumMemColumns		= 4
)
(
    input  wire                             		clk,
    input  wire                             		reset,
    input  wire										start,
    input  wire [memCtrlIn - 1 : 0] 				mem_ctrl_in,
    input  wire 									mem_rd_wrt, 
  
    input  wire [memDataLen*numMemColumns - 1 : 0] 	mem_data_input,
    
    output wire [memDataLen*numMemColumns - 1 : 0]  mem_data_output,
    
    output reg                             			eol
 // output wire                            		eoc
);
    //--------------------------------------------------------------------------------------
    localparam numPu                = 1 << logNumPu; 
    localparam numPe   				= 1 << logNumPe; 
    localparam numMemColumns		= 1 << logNumMemColumns;
    localparam numPuMemColumns 		= numMemColumns/numPu;
    localparam peBusIndexLen        = logNumPe + 1;
    localparam gbBusIndexLen        = logNumPu + 1;
    localparam logNumPeMemColumn	= logNumPu + logNumPe - logNumMemColumns;
    localparam memCtrlIn			= logMemNamespaces + (logNumPeMemColumn+1)*numMemColumns;
    //--------------------------------------------------------------------------------------
    
    wire [memCtrlIn - logMemNamespaces - 1 : 0] mem_ctrl_in_column;
    
    assign mem_ctrl_in_column = mem_ctrl_in[memCtrlIn - 1 : logMemNamespaces];
    
    //--------------------------------------------------------------------------------------
    //Within PU data and data valid handling
    wire [dataLen - 1 : 0 ]             	gb_bus_data_in;
    wire [gbBusIndexLen - 1 : 0 ]       	gb_bus_data_in_v;
    wire [numPu - 1 : 0]					gb_bus_ctrl;
    
    wire [dataLen*numPu - 1 : 0] 			gb_bus_data_out;
    wire [numPu*gbBusIndexLen - 1 : 0] 		gb_bus_data_out_v;
    
    genvar i;
    generate
    	for (i = 0; i < numPu; i = i + 1) begin
    		assign gb_bus_ctrl[i] = (i==0) ? gb_bus_data_out_v[i*gbBusIndexLen] : ~gb_bus_ctrl[i-1] && gb_bus_data_out_v[i*gbBusIndexLen];
    		assign gb_bus_data_in = ( gb_bus_ctrl[i] == 1) ? gb_bus_data_out[i*dataLen+:dataLen] : {dataLen{1'bz}};
    		assign gb_bus_data_in_v = (gb_bus_ctrl[i] == 1) ? gb_bus_data_out_v[i*gbBusIndexLen+:gbBusIndexLen] : {gbBusIndexLen{1'bz}};
    	end
 	endgenerate
    //--------------------------------------------------------------------------------------

	wire [dataLen*numPu - 1 : 0 ] 	pu_neigh_data_out;
	wire [numPu - 1 : 0] 		  	pu_neigh_data_out_v;	
	
//	wire [numPu - 1 : 0]			eoc_pu;
//  assign eoc = |eoc_pu;
    
    wire [numPu - 1 : 0]			eol_pu;
    always @(posedge clk) eol <= &eol_pu;
    
    wire [numPu - 1 : 0 ]			gb_bus_data_in_v_pu_decoder_out;
    wire [numPu - 1 : 0 ]   		gb_bus_data_in_v_pu;
    
    decoder
    #(
        .inputLen(logNumPu)
    )
    gb_bus_decoder(
        gb_bus_data_in_v[logNumPu : 1],
        gb_bus_data_in_v_pu_decoder_out 
    );
    
    assign gb_bus_data_in_v_pu = gb_bus_data_in_v_pu_decoder_out & {numPu{gb_bus_data_in_v[0]}};

	generate
	for(i = 0; i < numPu; i= i + 1) begin
		 pu 
   		 #(
        	//--------------------------------------------------------------------------------------
        	.puId(i),
        	.numPeValid(numPeValid),
        	.logNumPu(logNumPu),
        	.logNumPe(logNumPe),
        	.memDataLen(memDataLen),
        	.indexLen(indexLen),
        	.dataLen(dataLen),
        	.logMemNamespaces(logMemNamespaces), 
        	.numPuMemColumns(numPuMemColumns),
        	.logNumPeMemColumn(logNumPeMemColumn)
        	//--------------------------------------------------------------------------------------
    	) pu_unit(
    		.clk(clk),
    		.reset(reset),
    		.start(start),
    		.mem_rd_wrt(mem_rd_wrt),
    		.ctrl_mem_in(mem_ctrl_in_column[(logNumPeMemColumn+1)*numPuMemColumns*i+:(logNumPeMemColumn+1)*numPuMemColumns]),
    		.mem_data_type(mem_ctrl_in[logMemNamespaces - 1 : 0]),
    		.mem_data_input(mem_data_input[numPuMemColumns*i*memDataLen+:numPuMemColumns*memDataLen]),
    		.mem_data_output(mem_data_output[numPuMemColumns*i*memDataLen+:numPuMemColumns*memDataLen]),
    
    		.pu_neigh_data_in(pu_neigh_data_out[((i+1)%numPu)*dataLen+:dataLen]),
    		.pu_neigh_data_in_v(pu_neigh_data_out_v[((i+1)%numPu)]),
        
    		.gb_bus_data_out(gb_bus_data_out[i*dataLen+:dataLen]),
    		.gb_bus_data_out_v(gb_bus_data_out_v[i*gbBusIndexLen+:gbBusIndexLen]),
    		.gb_bus_contention(gb_bus_ctrl[i]),
       
    		.inst_eol(eol_pu[i]),
//    		.inst_eoc(eoc_pu[i]),
    
    		.pu_neigh_data_out(pu_neigh_data_out[i*dataLen+:dataLen]),
    		.pu_neigh_data_out_v(pu_neigh_data_out_v[i]),
    
    		.gb_bus_data_in(gb_bus_data_in),
    		.gb_bus_data_in_v(gb_bus_data_in_v_pu[i])

        //---------------------------------------------------------------------------------------
    );	
	
	end
	endgenerate

endmodule
