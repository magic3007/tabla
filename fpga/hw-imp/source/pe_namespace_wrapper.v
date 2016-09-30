`timescale 1ns/1ps
module pe_namespace_wrapper(
    //--------------------------------------------------------------------------------------
    input clk,
    input reset,
    input start,
    
    //from the memory to PE Namespace
    input mem_wrt_valid,
    input mem_weight_rd_valid,
    
    input [logNumPeMemColumn - 1 : 0 ] peId_mem_in,
    input [logMemNamespaces - 1 : 0] mem_data_type,
    input [dataLen - 1 : 0] mem_data_input,
    output[dataLen - 1 : 0] mem_data_output,
    //--------------------------------------------------------------------------------------
    
    //from the PE Core to Memory 
    output pe_namespace_wrt_done,
    
    input pe_core_inst_stall,
    input pe_core_bus_contention,
    
    input [dataAddrLen - 1 : 0] pe_core_data_rd_addr,
    
    input [weightAddrLen - 1 : 0] pe_core_weight_wrt_addr,
    input pe_core_weight_wrt,
    input [dataLen - 1 : 0] pe_core_weight_wrt_data,
    input [weightAddrLen - 1 : 0] pe_core_weight_rd_addr,
    
    input [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr,
    input pe_core_gradient_wrt,
    input [dataLen - 1 : 0] pe_core_gradient_wrt_data,
    input [weightAddrLen - 1 : 0] pe_core_gradient_rd_addr,
    
    input [metaAddrLen - 1 : 0]pe_core_meta_rd_addr,
    
    //--------------------------------------------------------------------------------------
    output [instLen - 1 : 0] pe_namespace_inst_out,
    output pe_namespace_inst_valid,
    
    output pe_namespace_data_out_v,
    output pe_namespace_weight_out_v,
    output pe_namespace_gradient_out_v,
    output pe_namespace_meta_out_v,
    output [dataLen - 1 : 0] pe_namespace_data_out,
    output [dataLen - 1 : 0] pe_namespace_weight_out,        
    output [dataLen - 1 : 0] pe_namespace_gradient_out,
    output [dataLen - 1 : 0] pe_namespace_meta_out
    
);

    //--------------------------------------------------------------------------------------
    parameter peId = 0;
    parameter logNumPe = 3;
    parameter indexLen = 8;
    parameter instAddrLen = 6;
    parameter dataAddrLen = 5;
    parameter weightAddrLen = 5;
    parameter metaAddrLen = 2;
    parameter dataLen = 16;
    parameter instLen = 69;
    parameter logMemNamespaces = 2; //instruction, data, weight, meta
    parameter memDataLen = 16;
    parameter logNumPeMemColumn		= 2;
    //--------------------------------------------------------------------------------------
    
    wire pe_namespace_inst_wrt;
    wire [instLen - 1 : 0] pe_namespace_inst;
    
    wire pe_namespace_data_wrt;
    wire [dataAddrLen - 1 : 0] pe_namespace_data_wrt_addr;
    
    wire [dataLen - 1 : 0] pe_namespace_data;
    
    wire mem_weight_wrt;
    wire [weightAddrLen - 1 : 0]  mem_weight_wrt_addr;
    wire [weightAddrLen - 1 : 0]  weight_read_back_addr;				
    
    wire pe_namespace_meta_wrt;
    wire [metaAddrLen - 1 : 0] pe_namespace_meta_wrt_addr;

    wire pe_namespace_inst_fifo_full;
    
    wire inst_restart;
    
    
    pe_mem_interface #(
        .peId                       ( peId                          ),
        .logNumPe                   ( logNumPe                      ),    
        .dataLen                    ( dataLen                       ),
        .instLen                    ( instLen                       ),    
        .indexLen                   ( indexLen                   	),
        .dataAddrLen                ( dataAddrLen                   ),
        .weightAddrLen              ( weightAddrLen                 ),
        .metaAddrLen                ( metaAddrLen                   ),
        .logMemNamespaces           ( logMemNamespaces              ),
        .memDataLen                 ( memDataLen                    ),
        .logNumPeMemColumn			( logNumPeMemColumn				) 
    )
    pe_mem_interface_unit(
        .clk                        ( clk                           ),
        .reset                      ( reset                         ),
        .mem_wrt_valid              ( mem_wrt_valid                 ),
        .mem_weight_rd_valid		( mem_weight_rd_valid			),
        .peId_mem_in                ( peId_mem_in                   ),
        .mem_data_type              ( mem_data_type                 ),
        .mem_data_input             ( mem_data_input                ),
        .mem_data_output            ( mem_data_output               ),

        .inst_restart				( inst_restart					), 
        .pe_namespace_weight_out    ( pe_namespace_weight_out       ),
        .weight_read_back_addr		( weight_read_back_addr			),
        .pe_namespace_wrt_done      ( pe_namespace_wrt_done         ),
        
//        .pe_inst_fifo_full          ( pe_namespace_inst_fifo_full   ),      
//        .pe_namespace_inst_wrt      ( pe_namespace_inst_wrt         ),
//        .pe_namespace_inst          ( pe_namespace_inst             ),
    
        .pe_namespace_data_wrt      ( pe_namespace_data_wrt         ),
        .data_wrt_addr              ( pe_namespace_data_wrt_addr    ),
        
        .pe_namespace_data          ( pe_namespace_data             ),
    
        .pe_namespace_weight_wrt    ( mem_weight_wrt                ),
        .weight_wrt_addr            ( mem_weight_wrt_addr           ),
    
        .pe_namespace_meta_wrt      ( pe_namespace_meta_wrt         ),
        .meta_wrt_addr              ( pe_namespace_meta_wrt_addr    )
    );
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    
    wire [weightAddrLen - 1 : 0] pe_namespace_weight_wrt_addr  = mem_weight_wrt ? mem_weight_wrt_addr : pe_core_weight_wrt_addr;
    wire pe_namespace_weight_wrt  = mem_weight_wrt || pe_core_weight_wrt;
    wire [dataLen - 1 : 0] pe_namespace_weight_data  = mem_weight_wrt ? pe_namespace_data : pe_core_weight_wrt_data;
    
    assign pe_namespace_data_out_v = (pe_namespace_data_wrt_addr > pe_core_data_rd_addr);
    assign pe_namespace_weight_out_v = (mem_weight_wrt_addr > pe_core_weight_rd_addr);
    assign pe_namespace_gradient_out_v = 1'b1;
    assign pe_namespace_meta_out_v = (pe_namespace_meta_wrt_addr > pe_core_meta_rd_addr);
    
    
    wire [weightAddrLen - 1 : 0] weight_rd_addr; 
    
    assign weight_rd_addr = (mem_weight_rd_valid && peId == peId_mem_in) ? weight_read_back_addr : pe_core_weight_rd_addr;
    
    pe_namespace#(
    	.peId						( peId							),
        .instAddrLen                ( instAddrLen                   ),
        .dataLen                    ( dataLen                       ),
        .instLen                    ( instLen                       ),    
        .dataAddrLen                ( dataAddrLen                   ),
        .weightAddrLen              ( weightAddrLen                 ),
        .metaAddrLen                ( metaAddrLen                   )
    )
    pe_namespace_unit(
        .clk                        ( clk                           ),
        .reset                      ( reset                         ),
        .start						( start							),
 		.lastInst					( inst_restart					),    
        
//        .inst_wrt                   ( pe_namespace_inst_wrt         ),
//        .inst_in                    ( pe_namespace_inst             ),
//        .inst_fifo_full             ( pe_namespace_inst_fifo_full   ),
    
        .inst_stall                 ( pe_core_inst_stall            ),
        .bus_contention				( pe_core_bus_contention		),
        
        .inst_out                   ( pe_namespace_inst_out         ),
        .inst_valid                 ( pe_namespace_inst_valid       ),

        .data_wrt                   ( pe_namespace_data_wrt         ),
        .data_wrt_addr              ( pe_namespace_data_wrt_addr    ),
        .data_rd_addr               ( pe_core_data_rd_addr          ),
        .data_in                    ( pe_namespace_data             ),
        .data_out                   ( pe_namespace_data_out         ),
    
        .weight_wrt                 ( pe_namespace_weight_wrt       ),
        .weight_wrt_addr            ( pe_namespace_weight_wrt_addr  ),
        .weight_rd_addr             ( weight_rd_addr       	 		),
        .weight_in                  ( pe_namespace_data             ),
        .weight_out                 ( pe_namespace_weight_out       ),
        
        .gradient_wrt               ( pe_core_gradient_wrt          ),
        .gradient_wrt_addr          ( pe_core_gradient_wrt_addr     ),
        .gradient_rd_addr           ( pe_core_gradient_rd_addr      ),
        .gradient_in                ( pe_core_gradient_wrt_data     ),
        .gradient_out               ( pe_namespace_gradient_out     ),
    
        .meta_wrt                   ( pe_namespace_meta_wrt         ),
        .meta_wrt_addr              ( pe_namespace_meta_wrt_addr    ),
        .meta_rd_addr               ( pe_core_meta_rd_addr          ),
        .meta_in                    ( pe_namespace_data             ),
        .meta_out                   ( pe_namespace_meta_out         )
    );
    //--------------------------------------------------------------------------------------

endmodule
