`timescale 1ns/1ps
`include "inst.vh"

module comp_stall #(
	parameter srcNum = 3,
	parameter indexLen = 8
	)
	(
		input interim_out_v,
		
		input pe_neigh_data_reg_v,
		input pu_neigh_data_reg_v,
		
		input pe_bus_data_reg_v,
		input gb_bus_data_reg_v,
		
		input [indexLen - 1: 0] src0Index,
		input [indexLen - 1: 0] src1Index,
		input [indexLen - 1: 0] src2Index,
		
		input [(1 << srcNum) - 1 : 0] src0_decoder_out,
		input [(1 << srcNum) - 1 : 0] src1_decoder_out,
		input [(1 << srcNum) - 1 : 0] src2_decoder_out,
		
		input src0_v_bram, src1_v_bram, src2_v_bram,
		
		input inst_valid,
		
		output src0_v, src1_v, src2_v,
		
		output inst_stall_comp
	);	

	wire src0_v_comp, src1_v_comp, src2_v_comp;
	wire src0_rq_comp, src1_rq_comp, src2_rq_comp;
	
	wire [srcNum - 1 : 0] srcInterimInV;
	
	wire src0NeighValid, src1NeighValid, src2NeighValid; 
	wire src0BusValid, src1BusValid, src2BusValid;
	
	assign srcInterimInV = {srcNum{interim_out_v}} & {src2_decoder_out[`NAMESPACE_INTERIM], src1_decoder_out[`NAMESPACE_INTERIM], src0_decoder_out[`NAMESPACE_INTERIM]};

	assign src0NeighValid = (src0_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src0Index[0] && pe_neigh_data_reg_v) || (src0Index[0] && pu_neigh_data_reg_v));
	assign src1NeighValid = (src1_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src1Index[0] && pe_neigh_data_reg_v) || (src1Index[0] && pu_neigh_data_reg_v));
	assign src2NeighValid = (src2_decoder_out[`NAMESPACE_NEIGHBOR]) && ((~src2Index[0] && pe_neigh_data_reg_v) || (src2Index[0] && pu_neigh_data_reg_v));
	
	assign src0BusValid = (src0_decoder_out[`NAMESPACE_BUS]) && ((~src0Index[0] && pe_bus_data_reg_v) || (src0Index[1] && gb_bus_data_reg_v));
	assign src1BusValid = (src1_decoder_out[`NAMESPACE_BUS]) && ((~src1Index[0] && pe_bus_data_reg_v) || (src1Index[1] && gb_bus_data_reg_v));
	assign src2BusValid = (src2_decoder_out[`NAMESPACE_BUS]) && ((~src2Index[0] && pe_bus_data_reg_v) || (src2Index[1] && gb_bus_data_reg_v));
	
	assign src0_v_comp = (srcInterimInV[0] || src0NeighValid || src0BusValid) && inst_valid;
	assign src1_v_comp = (srcInterimInV[1] || src1NeighValid || src1BusValid) && inst_valid;
	assign src2_v_comp = (srcInterimInV[2] || src2NeighValid || src2BusValid) && inst_valid;
	
	assign src0_rq_comp = src0_decoder_out[`NAMESPACE_BUS] || src0_decoder_out[`NAMESPACE_NEIGHBOR] || src0_decoder_out[`NAMESPACE_INTERIM];
	assign src1_rq_comp = src1_decoder_out[`NAMESPACE_BUS] || src1_decoder_out[`NAMESPACE_NEIGHBOR] || src1_decoder_out[`NAMESPACE_INTERIM];
	assign src2_rq_comp = src2_decoder_out[`NAMESPACE_BUS] || src2_decoder_out[`NAMESPACE_NEIGHBOR] || src2_decoder_out[`NAMESPACE_INTERIM];

	assign inst_stall_comp = (src0_rq_comp && ~src0_v_comp) || (src1_rq_comp && ~src1_v_comp) || (src2_rq_comp && ~src2_v_comp); 
	
	assign src0_v =  src0_v_bram || src0_v_comp;
	assign src1_v =  src1_v_bram || src1_v_comp;
	assign src2_v =  src2_v_bram || src2_v_comp;
	
endmodule