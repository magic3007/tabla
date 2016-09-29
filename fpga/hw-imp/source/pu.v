`timescale 1ns/1ps
`include "inst.vh"

module pu
#(
	parameter numPeValid			= 5,
    parameter puId                  = 0,
    parameter logNumPu              = 0,
    parameter logNumPe              = 3,
    parameter memDataLen            = 16, //width of the data coming from the memory
    parameter dataLen               = 16,
    parameter indexLen              = 8,
    parameter logMemNamespaces      = 2,  //instruction, data, weight, meta
    parameter numPuMemColumns		= 2,
   	parameter logNumPeMemColumn		= 2
)
(
    input  wire                             	clk,
    input  wire                             	reset,
    input  wire									start,
    input  wire									mem_rd_wrt,
    input  wire [memCtrlIn - 1 : 0]  			ctrl_mem_in,
    input  wire [logMemNamespaces - 1 : 0]  	mem_data_type,
    input  wire [memDataLenIn - 1 : 0]  		mem_data_input,
    output wire [memDataLenIn - 1 : 0]  		mem_data_output,
    
    input wire [dataLen - 1           : 0]  	pu_neigh_data_in,
    input wire                              	pu_neigh_data_in_v,
        
    input wire [dataLen - 1           : 0]  	gb_bus_data_in,
    input wire 								  	gb_bus_data_in_v,
    input wire									gb_bus_contention,
       
    output reg                             		inst_eol,
	//output wire                             	inst_eoc,
    
    output wire [dataLen - 1          : 0]  	pu_neigh_data_out,
    output wire                             	pu_neigh_data_out_v,
    
    output wire [dataLen - 1          : 0]  	gb_bus_data_out,
    output wire [gbBusIndexLen - 1    : 0]  	gb_bus_data_out_v
);
    //--------------------------------------------------------------------------------------
    localparam numPe                = 1 << logNumPe;
    localparam numPu                = 1 << logNumPu; 
    localparam peBusIndexLen        = logNumPe + 1;
    localparam gbBusIndexLen        = logNumPu + 1;
    localparam memCtrlIn			= (logNumPeMemColumn+1)*numPuMemColumns;
    localparam memDataLenIn			= memDataLen*numPuMemColumns;
    localparam numPeMemColumn		= 1 << logNumPeMemColumn;
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
	//wire [numPe - 1 : 0]                		inst_eoc_pe;
	//assign inst_eoc = |inst_eoc_pe;
    wire [numPe - 1 : 0]                		inst_eol_pe;
    always @(posedge clk) inst_eol <= &inst_eol_pe;
    //--------------------------------------------------------------------------------------
    
    //--------------------------------------------------------------------------------------
    //global bus check for the data if valid for this PU ID  
    
    wire [dataLen*numPe - 1          : 0]  gb_bus_data_out_w;
   	wire [gbBusIndexLen*numPe - 1    : 0]  gb_bus_data_out_v_w;
   	
   	
   	assign gb_bus_data_out = gb_bus_data_out_w[dataLen - 1 : 0];
   	assign gb_bus_data_out_v = gb_bus_data_out_v_w[gbBusIndexLen - 1 : 0];
 	//--------------------------------------------------------------------------------------
    
    //--------------------------------------------------------------------------------------
    //Within PU data and data valid handling
    wire [dataLen - 1 : 0 ]             pe_bus_data_in;
    wire [peBusIndexLen - 1 : 0 ]       pe_bus_data_in_v;
    wire [numPe - 1 : 0]				pe_bus_ctrl;
    
    wire [dataLen*numPe - 1 : 0] 		pe_bus_data_out;
    wire [numPe*peBusIndexLen - 1 : 0] 	pe_bus_data_out_v;
    
    genvar i;
    generate
    	for (i = 0; i < numPe; i = i + 1) begin
    		assign pe_bus_ctrl[i] = (i==0) ? pe_bus_data_out_v[i*peBusIndexLen] : ~pe_bus_ctrl[i-1] && pe_bus_data_out_v[i*peBusIndexLen];
    		assign pe_bus_data_in = ( pe_bus_ctrl[i] == 1) ? pe_bus_data_out[i*dataLen+:dataLen] : {dataLen{1'bz}};
    		assign pe_bus_data_in_v = (pe_bus_ctrl[i] == 1) ? pe_bus_data_out_v[i*peBusIndexLen+:peBusIndexLen] : {peBusIndexLen{1'bz}};
    	end
 	endgenerate
 	
 	wire [numPe - 1 : 0 ]  pe_bus_data_in_v_pe_decoder_out;
    wire [numPe - 1 : 0 ]  pe_bus_data_in_v_pe;
    
    decoder
    #(
        .inputLen(logNumPe)
    )
    pe_bus_decoder(
        pe_bus_data_in_v[logNumPe : 1],
        pe_bus_data_in_v_pe_decoder_out 
    );
    
    assign pe_bus_data_in_v_pe = pe_bus_data_in_v_pe_decoder_out & {numPe{pe_bus_data_in_v[0]}};
 
    //--------------------------------------------------------------------------------------

	wire [dataLen*numPe - 1 : 0 ] pe_neigh_data_out;
	wire [numPe - 1 : 0] pe_neigh_data_out_v;
	
	wire [dataLen*numPe - 1 : 0 ] pu_neigh_data_out_w;
	wire [numPe - 1 : 0] pu_neigh_data_out_v_w;
	
	assign pu_neigh_data_out = pu_neigh_data_out_w[dataLen - 1 : 0 ];
	assign pu_neigh_data_out_v = pu_neigh_data_out_v_w[0];	

	wire [dataLen*numPe - 1 : 0] mem_data_output_w;
	
	
	generate
	for(i = 0; i < numPe; i = i + 1) begin
		if(i < numPeValid) begin
	 		pe 
   			#(
        		//--------------------------------------------------------------------------------------
        		.peId(i),
        		.puId(puId),
        		.logNumPu(logNumPu),
        		.logNumPe(logNumPe),
        		.memDataLen(memDataLen),
        		.indexLen(indexLen),
        		.dataLen(dataLen),
        		.logMemNamespaces(logMemNamespaces),
        		.logNumPeMemColumn(logNumPeMemColumn) 
        		//--------------------------------------------------------------------------------------
    		) pe_unit(
        		//--------------------------------------------------------------------------------------
        		.clk(clk),
        		.reset(reset),
        		.start(start),
    
    			.mem_weight_rd_valid(ctrl_mem_in[(logNumPeMemColumn+1)*(i/numPeMemColumn)] && mem_rd_wrt),
        		.mem_wrt_valid(ctrl_mem_in[(logNumPeMemColumn+1)*(i/numPeMemColumn)] && ~mem_rd_wrt),
        		.peId_mem_in(ctrl_mem_in[((logNumPeMemColumn+1)*(i/numPeMemColumn)+1)+:logNumPeMemColumn]),
        		.mem_data_type(mem_data_type),

				.mem_data_input (mem_data_input[memDataLen*(i/numPeMemColumn)+:memDataLen]),
        		.mem_data_output (mem_data_output_w[i*memDataLen+:memDataLen]),
 		
//        		.inst_eoc(inst_eoc_pe[i]),
        		.inst_eol(inst_eol_pe[i]),
    
        		.pe_neigh_data_in(pe_neigh_data_out[((i+1)%numPe)*dataLen+:dataLen]),
        		.pe_neigh_data_in_v(pe_neigh_data_out_v[((i+1)%numPe)]),
        
        		.pu_neigh_data_in(pu_neigh_data_in),
        		.pu_neigh_data_in_v((i == 0) && pu_neigh_data_in_v),
        
        		.pe_bus_data_in(pe_bus_data_in),
        		.pe_bus_data_in_v(pe_bus_data_in_v_pe[i]),
        	
        		.gb_bus_data_in(gb_bus_data_in),
        		.gb_bus_data_in_v((i == 0) && gb_bus_data_in_v),
        	
        		.pe_neigh_data_out(pe_neigh_data_out[i*dataLen+:dataLen]),
        		.pe_neigh_data_out_v(pe_neigh_data_out_v[i]),
        	
        		.pu_neigh_data_out(pu_neigh_data_out_w[i*dataLen+:dataLen]),
        		.pu_neigh_data_out_v(pu_neigh_data_out_v_w[i]),
        	
 				.pe_bus_data_out(pe_bus_data_out[i*dataLen+:dataLen]),
				.pe_bus_data_out_v(pe_bus_data_out_v[i*peBusIndexLen+:peBusIndexLen]),
				.pe_bus_contention(pe_bus_ctrl[i]),
        	
				.gb_bus_data_out(gb_bus_data_out_w[i*dataLen+:dataLen]),
				.gb_bus_data_out_v(gb_bus_data_out_v_w[i*gbBusIndexLen+:gbBusIndexLen]),
				.gb_bus_contention(gb_bus_contention)
        		//---------------------------------------------------------------------------------------
    	);
    end
	else begin
			pe_empty 
   			#(
        		//--------------------------------------------------------------------------------------
        		.peId(i),
        		.puId(puId),
        		.logNumPu(logNumPu),
        		.logNumPe(logNumPe),
        		.memDataLen(memDataLen),
        		.indexLen(indexLen),
        		.dataLen(dataLen),
        		.logMemNamespaces(logMemNamespaces),
        		.logNumPeMemColumn(logNumPeMemColumn) 
        		//--------------------------------------------------------------------------------------
    		) pe_unit(
        		//--------------------------------------------------------------------------------------
        		.clk(clk),
        		.reset(reset),
        		.start(start),
    
    			.mem_weight_rd_valid(ctrl_mem_in[(logNumPeMemColumn+1)*(i/numPeMemColumn)] && mem_rd_wrt),
        		.mem_wrt_valid(ctrl_mem_in[(logNumPeMemColumn+1)*(i/numPeMemColumn)] && ~mem_rd_wrt),
        		.peId_mem_in(ctrl_mem_in[((logNumPeMemColumn+1)*(i/numPeMemColumn)+1)+:logNumPeMemColumn]),
        		.mem_data_type(mem_data_type),

				.mem_data_input (mem_data_input[memDataLen*(i/numPeMemColumn)+:memDataLen]),
        		.mem_data_output (mem_data_output_w[i*memDataLen+:memDataLen]),
 		
//       		.inst_eoc(inst_eoc_pe[i]),
        		.inst_eol(inst_eol_pe[i]),
    
        		.pe_neigh_data_in(pe_neigh_data_out[((i+1)%numPe)*dataLen+:dataLen]),
        		.pe_neigh_data_in_v(pe_neigh_data_out_v[((i+1)%numPe)]),
        
        		.pu_neigh_data_in(pu_neigh_data_in),
        		.pu_neigh_data_in_v((i == 0) && pu_neigh_data_in_v),
        
        		.pe_bus_data_in(pe_bus_data_in),
        		.pe_bus_data_in_v(pe_bus_data_in_v_pe[i]),
        	
        		.gb_bus_data_in(gb_bus_data_in),
        		.gb_bus_data_in_v((i == 0) && gb_bus_data_in_v),
        	
        		.pe_neigh_data_out(pe_neigh_data_out[i*dataLen+:dataLen]),
        		.pe_neigh_data_out_v(pe_neigh_data_out_v[i]),
        	
        		.pu_neigh_data_out(pu_neigh_data_out_w[i*dataLen+:dataLen]),
        		.pu_neigh_data_out_v(pu_neigh_data_out_v_w[i]),
        	
 				.pe_bus_data_out(pe_bus_data_out[i*dataLen+:dataLen]),
				.pe_bus_data_out_v(pe_bus_data_out_v[i*peBusIndexLen+:peBusIndexLen]),
				.pe_bus_contention(pe_bus_ctrl[i]),
        	
				.gb_bus_data_out(gb_bus_data_out_w[i*dataLen+:dataLen]),
				.gb_bus_data_out_v(gb_bus_data_out_v_w[i*gbBusIndexLen+:gbBusIndexLen]),
				.gb_bus_contention(gb_bus_contention)
        		//---------------------------------------------------------------------------------------
    	);
	
	end
   
	end
	endgenerate

	reg [logNumPeMemColumn*numPe/numPeMemColumn-1 : 0] peId_mem_in_r;
	
	generate
	for(i=0; i < numPe/numPeMemColumn; i = i + 1) begin
		always @(posedge clk) peId_mem_in_r[i*logNumPeMemColumn+:logNumPeMemColumn] <= ctrl_mem_in[((logNumPeMemColumn+1)*i+1)+:logNumPeMemColumn];
		
    	mux
    	#(
    		.DATA_WIDTH(dataLen),
    		.NUM_DATA(numPeMemColumn)
    	)   
    	mux_weight_rd(
    		.DATA_IN(mem_data_output_w[dataLen*numPeMemColumn*i+: dataLen*numPeMemColumn]),
    		.CTRL_IN(peId_mem_in_r[logNumPeMemColumn*i+:logNumPeMemColumn]),
    		.DATA_OUT(mem_data_output[dataLen*i+:dataLen])
    	);
    end
	endgenerate

endmodule
