`timescale 1ns/1ps
`include "inst.vh"

module pe_empty 
#(
	//--------------------------------------------------------------------------------------
	parameter peId 					= 0,
	parameter puId					= 0,
	parameter logNumPe				= 3,
	parameter logNumPu				= 0,
	parameter memDataLen			= 16,
	parameter logMemNamespaces      = 2,  //number of namespaces written by memory (instruction, data, weight, meta)

    parameter indexLen              = 8,  //index len of the src and destinations in the instruction 
    parameter dataLen               = 16,
    parameter logNumPeMemColumn		= 2
	//--------------------------------------------------------------------------------------
) (
	//--------------------------------------------------------------------------------------
    input  wire                             clk,
    input  wire                             reset,
    
    input  wire								start,
    
    //coming from memory to PE
    input  wire                             mem_wrt_valid,
    input  wire								mem_weight_rd_valid,
    
    input  wire	[logNumPeMemColumn - 1 : 0]	peId_mem_in,
    input  wire [logMemNamespaces - 1  : 0] mem_data_type,
    
    //going in and out of memory
    input  wire [memDataLen - 1 : 0]        mem_data_input,
    output wire [memDataLen - 1 : 0]        mem_data_output,
    
    //going to memory from PE
 //   output wire                           inst_eoc, ,
 	output wire								inst_eol,
    
    input  wire [dataLen - 1 : 0]           pe_neigh_data_in,
    input  wire                             pe_neigh_data_in_v,
    
    input  wire [dataLen - 1 : 0]           pu_neigh_data_in,
    input  wire                             pu_neigh_data_in_v,
    
    input  wire [dataLen - 1 : 0]           pe_bus_data_in,
    input  wire                             pe_bus_data_in_v,
    
    input  wire [dataLen - 1 : 0]           gb_bus_data_in,
    input  wire                             gb_bus_data_in_v,
    
    output wire [dataLen - 1 : 0]           pe_neigh_data_out,
    output wire                             pe_neigh_data_out_v,
    
    output wire [dataLen - 1 : 0]           pu_neigh_data_out,
    output wire                             pu_neigh_data_out_v,
    
    output wire [dataLen - 1 : 0]           pe_bus_data_out,
    output wire [peBusIndexLen - 1 : 0]     pe_bus_data_out_v,
    input  wire 							pe_bus_contention, 							
    
    output wire [dataLen - 1 : 0]           gb_bus_data_out,
    output wire [gbBusIndexLen - 1 : 0]     gb_bus_data_out_v,
    input  wire 							gb_bus_contention
	//----------------------------------------------------------------------------------------
);


	assign inst_eol = 1'b0;
	
    assign pe_neigh_data_out = {dataLen{0}};
    assign pe_neigh_data_out_v = 1'b0;
    
    assign pu_neigh_data_out = {dataLen{0}};
   	assign pu_neigh_data_out_v = 1'b0;
    
    assign pe_bus_data_out = {dataLen{0}};
    assign pe_bus_data_out_v = {peBusIndexLen{0}};					
    
    assign gb_bus_data_out = {dataLen{0}};
    assign gb_bus_data_out_v = {gbBusIndexLen{0}};

endmodule