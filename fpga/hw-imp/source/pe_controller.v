`include "inst.vh"

`timescale 1ns/1ps

module pe_controller
#(
//--------------------------------------------------------------------------------------
	parameter destNum               = 3,
	parameter srcNum                = 3,
	parameter fnLen                 = 3,
	parameter nameLen               = 3,
	parameter indexLen              = 8,
	parameter weightAddrLen         = 5,
	parameter interimAddrLen        = 2,
	parameter instLen               = fnLen + nameLen*destNum + nameLen*srcNum + indexLen*(destNum+srcNum),
 	parameter dataAddrLen           = 5,
 	parameter metaAddrLen           = 2
//--------------------------------------------------------------------------------------
) (
//--------------------------------------------------------------------------------------
	input  wire clk, reset,
	input  wire [instLen - 1 : 0] inst_in,
	input  wire inst_in_v,
	
	input  wire eol_flag,  
	
	input wire inst_stall,
	input wire bus_contention,	
	
	output reg [fnLen - 1 : 0] pe_compute_fn,
	output reg inst_out_v, inst_out_v_dd,

	output reg pe_core_weight_wrt,
	output reg pe_core_gradient_wrt,
	output reg pe_core_interim_wrt,
	
	output reg pe_core_pe_neig_wrt, pe_core_pu_neig_wrt,
	
	output reg [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr, pe_core_weight_wrt_addr,
	output reg [interimAddrLen - 1 : 0] pe_core_interim_wrt_addr,
	
	output reg [indexLen - 1 : 0 ] pe_core_pe_bus_wrt_addr, pe_core_gb_bus_wrt_addr,
	
	output reg [dataAddrLen - 1 : 0] pe_core_data_rd_addr,
	output reg [weightAddrLen - 1 : 0]  pe_core_weight_rd_addr, pe_core_gradient_rd_addr,
	output reg [interimAddrLen - 1 : 0] pe_core_interim_rd_addr,
	output reg [metaAddrLen - 1 : 0] pe_core_meta_rd_addr,

	output reg pe_neigh_data_rq, pu_neigh_data_rq,
	output reg pe_bus_data_rq, gb_bus_data_rq,
	
	output reg src0_rq, src1_rq, src2_rq,
	
	output reg [indexLen - 1: 0] src0Index, src1Index, src2Index,
	
	output reg [srcNum - 1 : 0 ] src0Name, src1Name, src2Name,
	
//	output reg inst_eoc, 
	output reg inst_eol 
//	output reg  inst_restart
//--------------------------------------------------------------------------------------
);
	
	 wire [fnLen - 1 : 0] pe_compute_fn_d;

	 wire pe_core_weight_wrt_d;
	 wire pe_core_gradient_wrt_d;
	 wire pe_core_interim_wrt_d;
	
	 wire pe_core_pe_neig_wrt_d, pe_core_pu_neig_wrt_d;
	
	 wire [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr_d, pe_core_weight_wrt_addr_d;
	 wire [interimAddrLen - 1 : 0] pe_core_interim_wrt_addr_d;
	
	 wire [indexLen - 1 : 0 ] pe_core_pe_bus_wrt_addr_d, pe_core_gb_bus_wrt_addr_d;
	
	 wire [dataAddrLen - 1 : 0] pe_core_data_rd_addr_d;
	 wire [weightAddrLen - 1 : 0]  pe_core_weight_rd_addr_d, pe_core_gradient_rd_addr_d;
	 wire [interimAddrLen - 1 : 0] pe_core_interim_rd_addr_d;
	 wire [metaAddrLen - 1 : 0] pe_core_meta_rd_addr_d;

	 wire src0_rq_d, src1_rq_d, src2_rq_d;
	 
	 wire [indexLen - 1: 0] src0Index_d, src1Index_d, src2Index_d;
	
	 wire [srcNum - 1 : 0 ] src0Name_d, src1Name_d, src2Name_d;

	 wire inst_eol_d; 
//	 wire inst_eoc_d;
//	 wire inst_restart_d;
	 
//--------------------------------------------------------------------------------------
	wire [destNum - 1 : 0 ] dest0Name, dest1Name, dest2Name;
	wire[indexLen - 1: 0] dest0Index, dest1Index, dest2Index;
	wire dest0_rq, dest1_rq, dest2_rq;
	
	instCutter
	#(
		.destNum(destNum),
		.srcNum(srcNum),
		.fnLen(fnLen),
		.nameLen(nameLen),
		.indexLen(indexLen)
	)
	instCutterUnit(
		.instword(inst_in),
		.instword_v(inst_in_v),
		.fn(pe_compute_fn_d),
		
		.dest0Name(dest0Name),
		.dest0Index(dest0Index),

		.dest1Name(dest1Name),
		.dest1Index(dest1Index),
	
		.dest2Name(dest2Name),
		.dest2Index(dest2Index),

		.src0Name(src0Name_d),
		.src0Index(src0Index_d),

		.src1Name(src1Name_d),
		.src1Index(src1Index_d),

		.src2Name(src2Name_d),
		.src2Index(src2Index_d)
	);
		
	assign dest0_rq = |dest0Name && inst_in_v;
	assign dest1_rq = |dest1Name && inst_in_v;
	assign dest2_rq = |dest2Name && inst_in_v; 
	
	assign src0_rq_d = |src0Name_d && inst_in_v;
	assign src1_rq_d = |src1Name_d && inst_in_v;
	assign src2_rq_d = |src2Name_d && inst_in_v;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	wire [(1 << destNum) - 1 : 0] dest0_decoder_out;
	wire [(1 << destNum) - 1: 0] dest1_decoder_out;
	wire [(1 << destNum) - 1: 0] dest2_decoder_out;
	
	decoder
	#(
		.inputLen(destNum)
	)
	decode_dest0(
		dest0Name,
 		dest0_decoder_out 
	);
	
	decoder
	#(
		.inputLen(destNum)
	)
	decode_dest1(
		dest1Name,
 		dest1_decoder_out 
	);
	
	decoder
	#(
		.inputLen(destNum)
	)
	decode_dest2(
		dest2Name,
 		dest2_decoder_out 
	);
	
	assign pe_core_gradient_wrt_d = (dest0_decoder_out[`NAMESPACE_GRADIENT] || dest1_decoder_out[`NAMESPACE_GRADIENT] || dest2_decoder_out[`NAMESPACE_GRADIENT]) && inst_in_v;
	assign pe_core_weight_wrt_d = (dest0_decoder_out[`NAMESPACE_WEIGHT] || dest1_decoder_out[`NAMESPACE_WEIGHT ] || dest2_decoder_out[`NAMESPACE_WEIGHT]) && inst_in_v;
	assign pe_core_interim_wrt_d = (dest0_decoder_out[`NAMESPACE_INTERIM] || dest1_decoder_out[`NAMESPACE_INTERIM] || dest2_decoder_out[`NAMESPACE_INTERIM] ) && inst_in_v;
	
	wire [weightAddrLen - 1 : 0] gradient_wrt_addr0, gradient_wrt_addr1, gradient_wrt_addr2;
	
	assign gradient_wrt_addr0 = dest0Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest0_decoder_out[`NAMESPACE_GRADIENT]}};
	assign gradient_wrt_addr1 = dest1Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest1_decoder_out[`NAMESPACE_GRADIENT]}};
	assign gradient_wrt_addr2 = dest2Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest2_decoder_out[`NAMESPACE_GRADIENT]}};

	assign pe_core_gradient_wrt_addr_d =  gradient_wrt_addr0 | gradient_wrt_addr1 | gradient_wrt_addr2;
	
	wire [weightAddrLen - 1 : 0] weight_wrt_addr0, weight_wrt_addr1, weight_wrt_addr2;
	
	assign weight_wrt_addr0 = dest0Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest0_decoder_out[`NAMESPACE_WEIGHT]}};
	assign weight_wrt_addr1 = dest1Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest1_decoder_out[`NAMESPACE_WEIGHT]}};
	assign weight_wrt_addr2 = dest2Index[weightAddrLen - 1 : 0] & {weightAddrLen{dest2_decoder_out[`NAMESPACE_WEIGHT]}};
	
	assign pe_core_weight_wrt_addr_d =  weight_wrt_addr0 | weight_wrt_addr1 | weight_wrt_addr2;	
	
	wire [interimAddrLen - 1 : 0] interim_wrt_addr0, interim_wrt_addr1, interim_wrt_addr2;
	
	assign interim_wrt_addr0 = dest0Index[interimAddrLen - 1 : 0] & {interimAddrLen{dest0_decoder_out[`NAMESPACE_INTERIM]}};
	assign interim_wrt_addr1 = dest1Index[interimAddrLen - 1 : 0] & {interimAddrLen{dest1_decoder_out[`NAMESPACE_INTERIM]}};
	assign interim_wrt_addr2 = dest2Index[interimAddrLen - 1 : 0] & {interimAddrLen{dest2_decoder_out[`NAMESPACE_INTERIM]}};
	
	assign pe_core_interim_wrt_addr_d =  interim_wrt_addr0 | interim_wrt_addr1 | interim_wrt_addr2;

	//--------------------------------------------------------------------------------------
	wire [indexLen - 1 : 0 ] pe_core_bus_wrt_addr;
	wire pe_core_pe_bus_wrt, pe_core_gb_bus_wrt;

	assign pe_core_pe_bus_wrt = (dest0_decoder_out[`NAMESPACE_BUS] && ~dest0Index[0]) || (~dest1Index[0] && dest1_decoder_out[`NAMESPACE_BUS]) || (~dest2Index[0] && dest2_decoder_out[`NAMESPACE_BUS]) & inst_in_v;
	assign pe_core_gb_bus_wrt = (dest0_decoder_out[`NAMESPACE_BUS] && dest0Index[0]) || (dest1Index[0] && dest1_decoder_out[`NAMESPACE_BUS]) || (dest2Index[0] && dest2_decoder_out[`NAMESPACE_BUS]) & inst_in_v;
	
	assign pe_core_bus_wrt_addr = ({indexLen{dest0_decoder_out[`NAMESPACE_BUS]}} & dest0Index[indexLen - 1 : 0]) | ({indexLen{dest1_decoder_out[`NAMESPACE_BUS]}} & dest1Index[indexLen - 1 : 0]) | ({indexLen{dest2_decoder_out[`NAMESPACE_BUS]}} & dest2Index[indexLen - 1 : 0]);

	assign pe_core_pe_bus_wrt_addr_d = {pe_core_bus_wrt_addr[indexLen - 1 : 1],{pe_core_pe_bus_wrt}}; 
	assign pe_core_gb_bus_wrt_addr_d = {pe_core_bus_wrt_addr[indexLen - 1 : 1],{pe_core_gb_bus_wrt}};

	wire pe_core_neig_wrt, pe_core_neig_index;
	
	assign pe_core_neig_wrt =  dest0_decoder_out[`NAMESPACE_NEIGHBOR ] || dest1_decoder_out[`NAMESPACE_NEIGHBOR] || dest2_decoder_out[`NAMESPACE_NEIGHBOR];
	assign pe_core_neig_index = dest0Index[0] | dest1Index[0] | dest2Index[0];
	assign pe_core_pe_neig_wrt_d = pe_core_neig_wrt && ~(pe_core_neig_index) && inst_in_v;
	assign pe_core_pu_neig_wrt_d = pe_core_neig_wrt && pe_core_neig_index && inst_in_v;
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
	wire [(1 << srcNum) - 1 : 0] src0_decoder_out;
	wire [(1 << srcNum) - 1 : 0] src1_decoder_out;
	wire [(1 << srcNum) - 1 : 0] src2_decoder_out;
	
	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src0(
		src0Name_d,
 		src0_decoder_out 
	);
	
	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src1(
		src1Name_d,
 		src1_decoder_out 
	);
	
	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src2(
		src2Name_d,
 		src2_decoder_out 
	);
	/* 
	
	wire [srcNum - 1 : 0] srcDataInV, srcWeightInV, srcGradientInV, srcInterimInV, srcMetaInV;
	wire src0NeighValid, src1NeighValid, src2NeighValid; 
	wire src0BusValid, src1BusValid, src2BusValid;
	
	wire pe_neigh_data_rq_d0, pe_neigh_data_rq_d1, pe_neigh_data_rq_d2, pe_neigh_data_rq_d;
	wire pu_neigh_data_rq_d0, pu_neigh_data_rq_d1, pu_neigh_data_rq_d2, pu_neigh_data_rq_d;
	wire pe_bus_data_rq_d0, pe_bus_data_rq_d1, pe_bus_data_rq_d2, pe_bus_data_rq_d;
	wire gb_bus_data_rq_d0, gb_bus_data_rq_d1, gb_bus_data_rq_d2, gb_bus_data_rq_d;
	
	assign srcDataInV = {srcNum{pe_data_in_v}} & {src2_decoder_out[`NAMESPACE_DATA], src1_decoder_out[`NAMESPACE_DATA], src0_decoder_out[`NAMESPACE_DATA]};
	assign srcWeightInV = {srcNum{pe_weight_in_v}} & {src2_decoder_out[`NAMESPACE_WEIGHT], src1_decoder_out[`NAMESPACE_WEIGHT], src0_decoder_out[`NAMESPACE_WEIGHT]};
	assign srcGradientInV = {srcNum{pe_gradient_in_v}} & {src2_decoder_out[`NAMESPACE_GRADIENT], src1_decoder_out[`NAMESPACE_GRADIENT], src0_decoder_out[`NAMESPACE_GRADIENT]};
	assign srcInterimInV = {srcNum{pe_interim_in_v}} & {src2_decoder_out[`NAMESPACE_INTERIM], src1_decoder_out[`NAMESPACE_INTERIM], src0_decoder_out[`NAMESPACE_INTERIM]};
	assign srcMetaInV = {srcNum{pe_meta_in_v}} & {src2_decoder_out[`NAMESPACE_META], src1_decoder_out[`NAMESPACE_META], src0_decoder_out[`NAMESPACE_META]};

	assign src0NeighValid = (src0_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src0Index_d[0] && pe_neigh_data_in_v) || (src0Index_d[0] && pu_neigh_data_in_v));
	assign src1NeighValid = (src1_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src1Index_d[0] && pe_neigh_data_in_v) || (src1Index_d[0] && pu_neigh_data_in_v));
	assign src2NeighValid = (src2_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src2Index_d[0] && pe_neigh_data_in_v) || (src2Index_d[0] && pu_neigh_data_in_v));
	
	assign src0BusValid = (src0_decoder_out[`NAMESPACE_BUS]) && ((~src0Index_d[0] && pe_bus_data_in_v) || (src0Index_d[1] && gb_bus_data_in_v));
	assign src1BusValid = (src1_decoder_out[`NAMESPACE_BUS]) && ((~src1Index_d[0] && pe_bus_data_in_v) || (src1Index_d[1] && gb_bus_data_in_v));
	assign src2BusValid = (src2_decoder_out[`NAMESPACE_BUS]) && ((~src2Index_d[0] && pe_bus_data_in_v) || (src2Index_d[1] && gb_bus_data_in_v));
	
	assign src0_v_d = (srcDataInV[0] || srcWeightInV[0] || srcGradientInV[0]  || srcInterimInV[0] || srcMetaInV[0] || src0NeighValid || src0BusValid) && inst_in_v;
	assign src1_v_d = (srcDataInV[1] || srcWeightInV[1] || srcGradientInV[1]  || srcInterimInV[1] || srcMetaInV[1] || src1NeighValid || src1BusValid) && inst_in_v;
	assign src2_v_d = (srcDataInV[2] || srcWeightInV[2] || srcGradientInV[2]  || srcInterimInV[2] || srcMetaInV[2] || src2NeighValid || src2BusValid) && inst_in_v;
	*/
	
	assign pe_neigh_data_rq_d0 = src0_decoder_out[`NAMESPACE_NEIGHBOR] && ~src0Index_d[0] ;
	assign pe_neigh_data_rq_d1 = src1_decoder_out[`NAMESPACE_NEIGHBOR] && ~src1Index_d[0] ;
	assign pe_neigh_data_rq_d2 = src2_decoder_out[`NAMESPACE_NEIGHBOR] && ~src2Index_d[0] ;
	assign pe_neigh_data_rq_d = pe_neigh_data_rq_d0 || pe_neigh_data_rq_d1 || pe_neigh_data_rq_d2;
	
	assign pu_neigh_data_rq_d0 = src0_decoder_out[`NAMESPACE_NEIGHBOR] && src0Index_d[0] ;
	assign pu_neigh_data_rq_d1 = src1_decoder_out[`NAMESPACE_NEIGHBOR] && src1Index_d[0] ;
	assign pu_neigh_data_rq_d2 = src2_decoder_out[`NAMESPACE_NEIGHBOR] && src2Index_d[0] ;
	assign pu_neigh_data_rq_d = pu_neigh_data_rq_d0 || pu_neigh_data_rq_d1 || pu_neigh_data_rq_d2;
	
	assign pe_bus_data_rq_d0 = src0_decoder_out[`NAMESPACE_BUS] && ~src0Index_d[0] ;
	assign pe_bus_data_rq_d1 = src1_decoder_out[`NAMESPACE_BUS] && ~src1Index_d[0] ;
	assign pe_bus_data_rq_d2 = src2_decoder_out[`NAMESPACE_BUS] && ~src2Index_d[0] ;
	assign pe_bus_data_rq_d = pe_bus_data_rq_d0 || pe_bus_data_rq_d1 || pe_bus_data_rq_d2;
	 
	assign gb_bus_data_rq_d0 = src0_decoder_out[`NAMESPACE_BUS] && src0Index_d[0];
	assign gb_bus_data_rq_d1 = src1_decoder_out[`NAMESPACE_BUS] && src1Index_d[0];
	assign gb_bus_data_rq_d2 = src2_decoder_out[`NAMESPACE_BUS] && src2Index_d[0];
	assign gb_bus_data_rq_d = gb_bus_data_rq_d0 || gb_bus_data_rq_d1 || gb_bus_data_rq_d2;

	
	wire [weightAddrLen - 1 : 0] weight_rd_addr0, weight_rd_addr1, weight_rd_addr2;
	wire [dataAddrLen - 1 : 0] data_rd_addr0, data_rd_addr1, data_rd_addr2;
	wire [weightAddrLen - 1 : 0] gradient_rd_addr0, gradient_rd_addr1, gradient_rd_addr2;
	wire [metaAddrLen - 1 : 0] meta_rd_addr0, meta_rd_addr1, meta_rd_addr2;
	wire [interimAddrLen - 1 : 0] interim_rd_addr0, interim_rd_addr1, interim_rd_addr2;
	
	assign data_rd_addr0 = src0Index_d[dataAddrLen - 1 : 0] & {dataAddrLen{src0_decoder_out[`NAMESPACE_DATA]}};
	assign data_rd_addr1 = src1Index_d[dataAddrLen - 1 : 0] & {dataAddrLen{src1_decoder_out[`NAMESPACE_DATA]}};
	assign data_rd_addr2 = src2Index_d[dataAddrLen - 1 : 0] & {dataAddrLen{src2_decoder_out[`NAMESPACE_DATA]}};
	assign pe_core_data_rd_addr_d = data_rd_addr0 | data_rd_addr1 | data_rd_addr2;
	
	assign weight_rd_addr0 = src0Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src0_decoder_out[`NAMESPACE_WEIGHT]}};
	assign weight_rd_addr1 = src1Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src1_decoder_out[`NAMESPACE_WEIGHT]}};
	assign weight_rd_addr2 = src2Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src2_decoder_out[`NAMESPACE_WEIGHT]}};
	assign pe_core_weight_rd_addr_d = weight_rd_addr0 | weight_rd_addr1 | weight_rd_addr2;
	
	assign gradient_rd_addr0 = src0Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src0_decoder_out[`NAMESPACE_GRADIENT]}};
	assign gradient_rd_addr1 = src1Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src1_decoder_out[`NAMESPACE_GRADIENT]}};
	assign gradient_rd_addr2 = src2Index_d[weightAddrLen - 1 : 0] & {weightAddrLen{src2_decoder_out[`NAMESPACE_GRADIENT]}};
	assign pe_core_gradient_rd_addr_d = gradient_rd_addr0 | gradient_rd_addr1 | gradient_rd_addr2;
	
	assign interim_rd_addr0 = src0Index_d[interimAddrLen - 1 : 0] & {interimAddrLen{src0_decoder_out[`NAMESPACE_INTERIM]}};
	assign interim_rd_addr1 = src1Index_d[interimAddrLen - 1 : 0] & {interimAddrLen{src1_decoder_out[`NAMESPACE_INTERIM]}};
	assign interim_rd_addr2 = src2Index_d[interimAddrLen - 1 : 0] & {interimAddrLen{src2_decoder_out[`NAMESPACE_INTERIM]}};
	assign pe_core_interim_rd_addr_d = interim_rd_addr0 | interim_rd_addr1 | interim_rd_addr2;
	
	assign meta_rd_addr0 = src0Index_d[metaAddrLen - 1 : 0] & {metaAddrLen{src0_decoder_out[`NAMESPACE_META]}};
	assign meta_rd_addr1 = src1Index_d[metaAddrLen - 1 : 0] & {metaAddrLen{src1_decoder_out[`NAMESPACE_META]}};
	assign meta_rd_addr2 = src2Index_d[metaAddrLen - 1 : 0] & {metaAddrLen{src2_decoder_out[`NAMESPACE_META]}};
	assign pe_core_meta_rd_addr_d = meta_rd_addr0 | meta_rd_addr1 | meta_rd_addr2;
	//--------------------------------------------------------------------------------------
	
	//assign inst_stall = (src0_rq_d && ~src0_v_d) || (src1_rq_d && ~src1_v_d) || (src2_rq_d && ~src2_v_d); 
	
	assign inst_eol_d = ~(|src0Name_d || |src1Name_d || |src2Name_d || |dest0Name || |dest0Name || |dest0Name) && inst_in_v;

//	assign inst_eoc_d = inst_in_v && inst_eol_d && eol_flag;
	
//	assign inst_restart_d = ~inst_eoc_d && inst_eol_d;
	
	wire load_control_signals;
	assign load_control_signals = ~(bus_contention || inst_stall);
	
	//--------------------------------------------------------------------------------------
	//extra delay to compensate for the BRAM
	reg [fnLen - 1 : 0] pe_compute_fn_dd;
	reg pe_core_weight_wrt_dd;
	reg pe_core_gradient_wrt_dd;
	reg pe_core_interim_wrt_dd;
	reg pe_core_pe_neig_wrt_dd, pe_core_pu_neig_wrt_dd;
	reg [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr_dd, pe_core_weight_wrt_addr_dd;
	reg [interimAddrLen - 1 : 0] pe_core_interim_wrt_addr_dd;
	reg [indexLen - 1 : 0 ] pe_core_pe_bus_wrt_addr_dd, pe_core_gb_bus_wrt_addr_dd;
	reg [interimAddrLen - 1 : 0] pe_core_interim_rd_addr_dd;
	reg pe_neigh_data_rq_dd, pu_neigh_data_rq_dd, pe_bus_data_rq_dd, gb_bus_data_rq_dd;
	reg src0_rq_dd, src1_rq_dd, src2_rq_dd;
	reg [indexLen - 1: 0] src0Index_dd, src1Index_dd, src2Index_dd; 
	reg inst_eol_dd;
//	reg inst_eoc_dd;
//	reg inst_restart_dd;
	//--------------------------------------------------------------------------------------
	
	always @(posedge clk) begin
		if(reset)
		begin
			pe_compute_fn <= 0;

			pe_core_weight_wrt <= 0;
	 		pe_core_gradient_wrt <= 0;
	 		pe_core_interim_wrt <= 0;
	
	 		pe_core_pe_neig_wrt <= 0;
	 		pe_core_pu_neig_wrt <= 0;
	
	 		pe_core_gradient_wrt_addr <= 0; 
	 		pe_core_weight_wrt_addr <= 0;
	 		pe_core_interim_wrt_addr <= 0;
	
	 		pe_core_pe_bus_wrt_addr <= 0;
	 		pe_core_gb_bus_wrt_addr <= 0;
	
	 		pe_core_data_rd_addr <= 0;
	 		pe_core_weight_rd_addr <= 0;
	 		pe_core_gradient_rd_addr <= 0;
	 		pe_core_interim_rd_addr <= 0;
	 		pe_core_meta_rd_addr <= 0;
	 		
	 		inst_out_v <= 0;

	 		src0_rq <= 0; 
	 		src1_rq <= 0; 
	 		src2_rq <= 0;
	 		
	 		src0Name <= 0;
	 		src1Name <= 0;
	 		src2Name <= 0;
	 		
//			inst_eoc <= 0;
			inst_eol <= 0;
//			inst_restart <= 0;
			
			pe_compute_fn_dd <= 0;
			pe_core_weight_wrt_dd <= 0;
			pe_core_gradient_wrt_dd <= 0;
			pe_core_interim_wrt_dd <= 0;
			pe_core_pe_neig_wrt_dd <= 0; 
			pe_core_pu_neig_wrt_dd <= 0;
			pe_core_gradient_wrt_addr_dd <= 0;
			pe_core_weight_wrt_addr_dd <= 0;
			pe_core_interim_wrt_addr_dd <= 0;
			pe_core_pe_bus_wrt_addr_dd <= 0; 
			pe_core_gb_bus_wrt_addr_dd <= 0;
			pe_core_interim_rd_addr_dd <= 0;
			pe_neigh_data_rq_dd <= 0;
			pu_neigh_data_rq_dd <= 0;
			pe_bus_data_rq_dd <= 0;
			gb_bus_data_rq_dd <= 0;
			src0_rq_dd <= 0;
			src1_rq_dd <= 0; 
			src2_rq_dd <= 0;
			src0Index_dd <= 0; 
			src1Index_dd <= 0;
			src2Index_dd <= 0; 
//			inst_eoc_dd <= 0;
			inst_eol_dd <= 0; 
//			inst_restart_dd <= 0;
			
		end
		else if(load_control_signals)
		begin
			pe_core_data_rd_addr <= pe_core_data_rd_addr_d;
	 		pe_core_weight_rd_addr <= pe_core_weight_rd_addr_d;
	 		pe_core_gradient_rd_addr <= pe_core_gradient_rd_addr_d;
	 		pe_core_meta_rd_addr <= pe_core_meta_rd_addr_d;
			
			pe_compute_fn <= pe_compute_fn_dd;

			pe_core_weight_wrt <= pe_core_weight_wrt_dd;
	 		pe_core_gradient_wrt <= pe_core_gradient_wrt_dd;
	 		pe_core_interim_wrt <= pe_core_interim_wrt_dd;
	
	 		pe_core_pe_neig_wrt <= pe_core_pe_neig_wrt_dd;
	 		pe_core_pu_neig_wrt <= pe_core_pu_neig_wrt_dd;
	
	 		pe_core_gradient_wrt_addr <= pe_core_gradient_wrt_addr_dd; 
	 		pe_core_weight_wrt_addr  <= pe_core_weight_wrt_addr_dd;
	 		pe_core_interim_wrt_addr <= pe_core_interim_wrt_addr_dd;
	
	 		pe_core_pe_bus_wrt_addr <= pe_core_pe_bus_wrt_addr_dd;
	 		pe_core_gb_bus_wrt_addr <= pe_core_gb_bus_wrt_addr_dd;
	 		
	 		pe_core_interim_rd_addr <= pe_core_interim_rd_addr_dd;
	 		
	 		pe_neigh_data_rq <= pe_neigh_data_rq_dd;
	 		pu_neigh_data_rq <= pu_neigh_data_rq_dd;
	 		pe_bus_data_rq   <= pe_bus_data_rq_dd;
	 		gb_bus_data_rq   <= gb_bus_data_rq_dd;
	 	
	 		inst_out_v <= inst_out_v_dd;

	 		src0_rq <= src0_rq_dd; 
	 		src1_rq <= src1_rq_dd; 
	 		src2_rq <= src2_rq_dd;
	
	 		src0Index <= src0Index_dd;
	 		src1Index <= src1Index_dd;
	 		src2Index <= src2Index_dd;
	 		
	 		src0Name <= src0Name_d;
	 		src1Name <= src1Name_d;
	 		src2Name <= src2Name_d;
	 		 
//			inst_eoc <= inst_eoc_dd;
			inst_eol <= inst_eol_dd;
//			inst_restart <= inst_restart_dd;
			
			pe_compute_fn_dd <= pe_compute_fn_d;

			pe_core_weight_wrt_dd <= pe_core_weight_wrt_d;
	 		pe_core_gradient_wrt_dd <= pe_core_gradient_wrt_d;
	 		pe_core_interim_wrt_dd <= pe_core_interim_wrt_d;
	
	 		pe_core_pe_neig_wrt_dd <= pe_core_pe_neig_wrt_d;
	 		pe_core_pu_neig_wrt_dd <= pe_core_pu_neig_wrt_d;
	
	 		pe_core_gradient_wrt_addr_dd <= pe_core_gradient_wrt_addr_d; 
	 		pe_core_weight_wrt_addr_dd  <= pe_core_weight_wrt_addr_d;
	 		pe_core_interim_wrt_addr_dd <= pe_core_interim_wrt_addr_d;
	
	 		pe_core_pe_bus_wrt_addr_dd <= pe_core_pe_bus_wrt_addr_d;
	 		pe_core_gb_bus_wrt_addr_dd <= pe_core_gb_bus_wrt_addr_d;
	
	 		pe_core_interim_rd_addr_dd <= pe_core_interim_rd_addr_d;
	 		
	 		pe_neigh_data_rq_dd <= pe_neigh_data_rq_d;
	 		pu_neigh_data_rq_dd <= pu_neigh_data_rq_d;
	 		pe_bus_data_rq_dd   <= pe_bus_data_rq_d;
	 		gb_bus_data_rq_dd   <= gb_bus_data_rq_d;
	 	
	 		inst_out_v_dd <= inst_in_v;

	 		src0_rq_dd <= src0_rq_d; 
	 		src1_rq_dd <= src1_rq_d; 
	 		src2_rq_dd <= src2_rq_d;
	
	 		src0Index_dd <= src0Index_d;
	 		src1Index_dd <= src1Index_d;
	 		src2Index_dd <= src2Index_d;
	 		 
//			inst_eoc_dd <= inst_eoc_d;
			inst_eol_dd <= inst_eol_d;
//			inst_restart_dd <= inst_restart_d;
			
		end
	
	end
		
endmodule
