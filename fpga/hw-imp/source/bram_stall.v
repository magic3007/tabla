`timescale 1ns/1ps
`include "inst.vh"

module bram_stall 
#(
	parameter srcNum = 3
)
(
	input data_out_v,
	input weight_out_v,
	input gradient_out_v,
	input meta_out_v,
		
	input [(1 << srcNum) - 1 : 0] src0_decoder_out,
	input [(1 << srcNum) - 1 : 0] src1_decoder_out,
	input [(1 << srcNum) - 1 : 0] src2_decoder_out,
		
	input inst_valid,
	
	output src0_v_bram, src1_v_bram, src2_v_bram,
		
	output inst_stall_bram
	
);	

	wire src0_rq_bram, src1_rq_bram, src2_rq_bram;
	
	wire [srcNum - 1 : 0] srcDataInV, srcWeightInV, srcGradientInV, srcMetaInV;
	
	assign srcDataInV = {srcNum{data_out_v}} & {src2_decoder_out[`NAMESPACE_DATA], src1_decoder_out[`NAMESPACE_DATA], src0_decoder_out[`NAMESPACE_DATA]};
	assign srcWeightInV = {srcNum{weight_out_v}} & {src2_decoder_out[`NAMESPACE_WEIGHT], src1_decoder_out[`NAMESPACE_WEIGHT], src0_decoder_out[`NAMESPACE_WEIGHT]};
	assign srcGradientInV = {srcNum{gradient_out_v}} & {src2_decoder_out[`NAMESPACE_GRADIENT], src1_decoder_out[`NAMESPACE_GRADIENT], src0_decoder_out[`NAMESPACE_GRADIENT]};
	assign srcMetaInV = {srcNum{meta_out_v}} & {src2_decoder_out[`NAMESPACE_META], src1_decoder_out[`NAMESPACE_META], src0_decoder_out[`NAMESPACE_META]};
	
	assign src0_v_bram = (srcDataInV[0] || srcWeightInV[0] || srcGradientInV[0]  || srcMetaInV[0]) && inst_valid;
	assign src1_v_bram = (srcDataInV[1] || srcWeightInV[1] || srcGradientInV[1]  || srcMetaInV[1]) && inst_valid;
	assign src2_v_bram = (srcDataInV[2] || srcWeightInV[2] || srcGradientInV[2]  || srcMetaInV[2]) && inst_valid;
	
	assign src0_rq_bram = src0_decoder_out[`NAMESPACE_DATA] || src0_decoder_out[`NAMESPACE_WEIGHT] || src0_decoder_out[`NAMESPACE_GRADIENT] || src0_decoder_out[`NAMESPACE_META];
	assign src1_rq_bram = src1_decoder_out[`NAMESPACE_DATA] || src1_decoder_out[`NAMESPACE_WEIGHT] || src1_decoder_out[`NAMESPACE_GRADIENT] || src1_decoder_out[`NAMESPACE_META];
	assign src2_rq_bram = src2_decoder_out[`NAMESPACE_DATA] || src2_decoder_out[`NAMESPACE_WEIGHT] || src2_decoder_out[`NAMESPACE_GRADIENT] || src2_decoder_out[`NAMESPACE_META];
	
	assign inst_stall_bram =  (src0_rq_bram && ~src0_v_bram) || (src1_rq_bram && ~src1_v_bram) || (src2_rq_bram && ~src2_v_bram);
	
endmodule