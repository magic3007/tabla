`timescale 1ns/1ps
`include "../include/inst.vh"

module pe_controller_tb(
);

	parameter destNum               = 3;
	parameter srcNum                = 3;
	parameter fnLen                 = 3;
	parameter nameLen               = 3;
	parameter indexLen              = 2;
	parameter weightAddrLen         = 2;
	parameter interimAddrLen        = 2;
	parameter instLen               = fnLen + nameLen*destNum + nameLen*srcNum + indexLen*(destNum+srcNum);
    parameter dataAddrLen           = 2;
    parameter metaAddrLen           = 2;

	reg clk;
	reg reset;

	reg [instLen - 1 : 0] inst_in;
	reg inst_in_v;
	
	reg eol_flag;  
	reg pe_data_in_v, pe_weight_in_v, pe_gradient_in_v, pe_interim_in_v, pe_meta_in_v;
	reg pe_neigh_data_in_v, pu_neigh_data_in_v;
	reg pe_bus_data_in_v, gb_bus_data_in_v;	
	
	wire [fnLen - 1 : 0] pe_compute_fn;

	wire pe_core_weight_wrt;
	wire pe_core_gradient_wrt;
	wire pe_core_interim_wrt;
	
	wire pe_core_pe_neig_wrt, pe_core_pu_neig_wrt;
	
	wire [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr, pe_core_weight_wrt_addr;
	wire [interimAddrLen - 1 : 0] pe_core_interim_wrt_addr;
	
	wire [indexLen - 2 : 0 ] pe_core_pe_bus_wrt_addr, pe_core_gb_bus_wrt_addr;
	
	wire [dataAddrLen - 1 : 0] pe_core_data_rd_addr;
	wire [weightAddrLen - 1 : 0]  pe_core_weight_rd_addr, pe_core_gradient_rd_addr;
	wire [interimAddrLen - 1 : 0] pe_core_interim_rd_addr;
	wire [metaAddrLen - 1 : 0] pe_core_meta_rd_addr;

	wire src0_rq, src1_rq, src2_rq;
	
	wire src0_v, src1_v, src2_v;
	
	wire [srcNum - 1 : 0 ] src0Name, src1Name, src2Name;

	wire inst_stall;
	wire inst_eoc, inst_eol;
	

	pe_controller#(.destNum(destNum),
		.srcNum(srcNum),
		.fnLen(fnLen),
		.nameLen(nameLen),
		.weightAddrLen(weightAddrLen),
		.interimAddrLen(interimAddrLen),
		.indexLen(indexLen),
    	.dataAddrLen(dataAddrLen),
    	.dataAddrLen(dataAddrLen)
	)
	controller_tb(
		
		clk, reset,

		inst_in,
		inst_in_v,
		
		eol_flag,  
		
		pe_data_in_v, pe_weight_in_v, pe_gradient_in_v, pe_interim_in_v, pe_meta_in_v,
		
		pe_neigh_data_in_v, pu_neigh_data_in_v,
		pe_bus_data_in_v, gb_bus_data_in_v,	
	
		pe_compute_fn,

		pe_core_weight_wrt,
		pe_core_gradient_wrt,
		pe_core_interim_wrt,
	
		pe_core_pe_neig_wrt, pe_core_pu_neig_wrt,
	
		pe_core_gradient_wrt_addr, pe_core_weight_wrt_addr,
		pe_core_interim_wrt_addr,
	
		pe_core_pe_bus_wrt_addr, pe_core_gb_bus_wrt_addr,
	
		pe_core_data_rd_addr,
		pe_core_weight_rd_addr, pe_core_gradient_rd_addr,
		pe_core_interim_rd_addr,
		pe_core_meta_rd_addr,

		src0_rq, src1_rq, src2_rq,
		
		src0_v, src1_v, src2_v,
		
		src0Name, src1Name, src2Name,

		inst_stall,
		inst_eoc, inst_eol
	);
	
	initial
	begin
		$dumpfile("./bin/pe_controller.vcd");
		$dumpvars(0, pe_controller_tb);
		$monitor("clk,pe_controller_out");
	end
	
	//EXPECTED VALUES
	//--------------------------------------------------------------------------------------

	reg [fnLen - 1 : 0] pe_compute_fn_exp;

	reg pe_core_weight_wrt_exp;
	reg pe_core_gradient_wrt_exp;
	reg pe_core_interim_wrt_exp;
	
	reg pe_core_pe_neig_wrt_exp, pe_core_pu_neig_wrt_exp;
	
	reg [weightAddrLen - 1 : 0] pe_core_gradient_wrt_addr_exp, pe_core_weight_wrt_addr_exp;
	reg [interimAddrLen - 1 : 0] pe_core_interim_wrt_addr_exp;
	
	reg [indexLen - 2 : 0 ] pe_core_pe_bus_wrt_addr_exp, pe_core_gb_bus_wrt_addr_exp;
	
	reg [dataAddrLen - 1 : 0] pe_core_data_rd_addr_exp;
	reg [weightAddrLen - 1 : 0]  pe_core_weight_rd_addr_exp, pe_core_gradient_rd_addr_exp;
	reg [interimAddrLen - 1 : 0] pe_core_interim_rd_addr_exp;
	reg [metaAddrLen - 1 : 0] pe_core_meta_rd_addr_exp;

	reg src0_rq_exp, src1_rq_exp, src2_rq_exp;
	
	reg src0_v_exp, src1_v_exp, src2_v_exp;
	
	reg [srcNum - 1 : 0 ] src0Name_exp, src1Name_exp, src2Name_exp;

	reg inst_stall_exp;
	reg inst_eoc_exp, inst_eol_exp;
	
	
	task test_random_inputs;

    	reg   [dataLen-1:0] expected_data;
    	reg   [dataLen-1:0] received_data;

    	begin
        	// Generate Random Inputs
        	rand_inputs;
        	// Get Expected Data
        	
       	 	expected_result_task;

        	// Get Data From PE
        	@(negedge clk);
        	received_data = resultOut;

        	if (received_data !== expected_data)
        	begin
            	$display ("\tError: Expected data:%d Recieved data:%d", expected_data, received_data);
            	print_function(2);
            	print_inputs(2);
            	fail_flag = 1'b1;
        	end
        	else begin
           		if (VERBOSITY > 1) $display ("\tInfo: Expected data:%d Recieved data:%d", expected_data, received_data);
        	end
    	end
	endtask
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	task expected_result_task;
		begin
			pe_compute_fn_exp = inst_in[ 6*(indexLen + nameLen) + fnLen - 1 : 6*(indexLen + nameLen) ];
			
			dest0Name_exp = inst_in [ 6*(indexLen + nameLen) - 1 : 6*indexLen + 5*nameLen ] & {nameLen{inst_in_v}};
			dest0Index_exp = inst_in [ 6*indexLen + 5*nameLen - 1 : 5*(indexLen + nameLen) ] & {indexLen{inst_in_v}};
	
			dest1Name_exp = inst_in [ 5*(indexLen + nameLen) - 1 : 5*indexLen + 4*nameLen ] & {nameLen{inst_in_v}};
			dest1Index_exp = inst_in [ 5*indexLen + 4*nameLen - 1 : 4*(indexLen + nameLen) ] & {indexLen{inst_in_v}};
	
			dest2Name_exp = inst_in [ 4*(indexLen + nameLen) - 1 : 4*indexLen + 3*nameLen ] & {nameLen{inst_in_v}};
			dest2Index_exp = inst_in [ 4*indexLen + 3*nameLen - 1 : 3*(indexLen + nameLen) ] & {indexLen{inst_in_v}};
	
			src0Name_exp = inst_in [ 3*(indexLen + nameLen) - 1 : 3*indexLen + 2*nameLen ] & {nameLen{inst_in_v}};
			src0Index_exp = inst_in [ 3*indexLen + 2*nameLen - 1 : 2*(indexLen + nameLen) ] & {indexLen{inst_in_v}};
	
			src1Name_exp = inst_in [ 2*(indexLen + nameLen) - 1 : 2*indexLen + nameLen ] & {nameLen{inst_in_v}};
			src1Index_exp = inst_in [ 2*indexLen + nameLen - 1 : indexLen + nameLen ] & {indexLen{inst_in_v}};
	
			src2Name_exp = inst_in [ indexLen + nameLen - 1 : indexLen ] & {nameLen{instword_v}};
			src2Index_exp = inst_in [indexLen - 1 : 0] & {indexLen{inst_in_v}};
			
			//--------------------------------------------------------------------------------------
			//DESTINATION DECODING
			//--------------------------------------------------------------------------------------
			case(dest0Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_wrt_exp = 1;
					pe_core_weight_wrt_addr_exp = dest0Index_exp;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_wrt_exp = 1;
					pe_core_interim_wrt_addr_exp = dest0Index_exp;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_wrt_exp = 1;
					pe_core_gradient_wrt_addr_exp = dest0Index_exp;
				end
				`NAMESPACE_NEIGHBOR: begin
					pe_core_pe_neig_wrt_exp = ~dest0Index_exp[0];
					pe_core_pu_neig_wrt_exp = dest0Index_exp[0];
					pe_core_pe_bus_wrt_addr_exp = dest0Index_exp[indexLen - 1 : 1];
					pe_core_gb_bus_wrt_addr_exp = dest0Index_exp[indexLen - 1 : 1];
				end
				default: begin
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_addr_exp = 0;
					pe_core_interim_wrt_exp = 0;
					pe_core_interim_wrt_addr_exp = 0;
					pe_core_gradient_wrt_exp = 0;
					pe_core_gradient_wrt_addr_exp = 0;
					pe_core_pe_neig_wrt_exp = 0;
					pe_core_pu_neig_wrt_exp = 0;
					pe_core_pe_bus_wrt_addr_exp = 0;
					pe_core_gb_bus_wrt_addr_exp = 0;
				end
			endcase
			
			case(dest1Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_wrt_exp = 1;
					pe_core_weight_wrt_addr_exp = dest1Index_exp;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_wrt_exp = 1;
					pe_core_interim_wrt_addr_exp = dest1Index_exp;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_wrt_exp = 1;
					pe_core_gradient_wrt_addr_exp = dest1Index_exp;
				end
				`NAMESPACE_NEIGHBOR: begin
					pe_core_pe_neig_wrt_exp = ~dest1Index_exp[0];
					pe_core_pu_neig_wrt_exp = dest1Index_exp[0];
					pe_core_pe_bus_wrt_addr_exp = dest1Index_exp[indexLen - 1 : 1];
					pe_core_gb_bus_wrt_addr_exp = dest1Index_exp[indexLen - 1 : 1];
				end
				default: begin
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_addr_exp = 0;
					pe_core_interim_wrt_exp = 0;
					pe_core_interim_wrt_addr_exp = 0;
					pe_core_gradient_wrt_exp = 0;
					pe_core_gradient_wrt_addr_exp = 0;
					pe_core_pe_neig_wrt_exp = 0;
					pe_core_pu_neig_wrt_exp = 0;
					pe_core_pe_bus_wrt_addr_exp = 0;
					pe_core_gb_bus_wrt_addr_exp = 0;
				end
			endcase
			
			case(dest2Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_wrt_exp = 1;
					pe_core_weight_wrt_addr_exp = dest2Index_exp;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_wrt_exp = 1;
					pe_core_interim_wrt_addr_exp = dest2Index_exp;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_wrt_exp = 1;
					pe_core_gradient_wrt_addr_exp = dest2Index_exp;
				end
				`NAMESPACE_NEIGHBOR: begin
					pe_core_pe_neig_wrt_exp = ~dest2Index_exp[0];
					pe_core_pu_neig_wrt_exp = dest2Index_exp[0];
					pe_core_pe_bus_wrt_addr_exp = dest2Index_exp[indexLen - 1 : 1];
					pe_core_gb_bus_wrt_addr_exp = dest2Index_exp[indexLen - 1 : 1];
				end
				default: begin
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_exp = 0;
					pe_core_weight_wrt_addr_exp = 0;
					pe_core_interim_wrt_exp = 0;
					pe_core_interim_wrt_addr_exp = 0;
					pe_core_gradient_wrt_exp = 0;
					pe_core_gradient_wrt_addr_exp = 0;
					pe_core_pe_neig_wrt_exp = 0;
					pe_core_pu_neig_wrt_exp = 0;
					pe_core_pe_bus_wrt_addr_exp = 0;
					pe_core_gb_bus_wrt_addr_exp = 0;
				end
			endcase
			
			//--------------------------------------------------------------------------------------
			//SOURCE DECODING
			//--------------------------------------------------------------------------------------
			case(src0Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_rd_addr_exp = src0Index_exp;
					src0_v_exp = pe_weight_in_v;
				end
				`NAMESPACE_DATA: begin
					pe_core_data_rd_addr_exp = src0Index_exp;
					src0_v_exp = pe_data_in_v;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_rd_addr_exp = src0Index_exp;
					src0_v_exp = pe_interim_in_v;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_rd_addr_exp = src0Index_exp;
					src0_v_exp = pe_gradient_in_v;
				end
				`NAMESPACE_META: begin
					pe_core_meta_rd_addr_exp = src0Index_exp;
					src0_v_exp = pe_meta_in_v;
				end
				`NAMESPACE_NEIGHBOR: begin
					src0_v_exp = (pe_neigh_data_in_v && ~src0Index_exp[0]) || (pu_neigh_data_in_v && src0Index_exp[0]);
				end
				`NAMESPACE_BUS: begin
					src0_v_exp = (pe_bus_data_in_v && ~src0Index_exp[0]) || (gb_bus_data_in_v && src0Index_exp[0]);
				end
				default: begin
					src0_v_exp = 0;
					pe_core_weight_rd_addr_exp = 0;
					pe_core_data_rd_addr_exp = 0;
					pe_core_interim_rd_addr_exp = 0; 
					pe_core_gradient_rd_addr_exp = 0;
					pe_core_meta_rd_addr_exp = 0;
				end
			endcase
			
			case(src1Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_rd_addr_exp = src1Index_exp;
					src1_v_exp = pe_weight_in_v;
				end
				`NAMESPACE_DATA: begin
					pe_core_data_rd_addr_exp = src1Index_exp;
					src1_v_exp = pe_data_in_v;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_rd_addr_exp = src1Index_exp;
					src1_v_exp = pe_interim_in_v;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_rd_addr_exp = src1Index_exp;
					src1_v_exp = pe_gradient_in_v;
				end
				`NAMESPACE_META: begin
					pe_core_meta_rd_addr_exp = src1Index_exp;
					src1_v_exp = pe_meta_in_v;
				end
				`NAMESPACE_NEIGHBOR: begin
					src1_v_exp = (pe_neigh_data_in_v && ~src1Index_exp[0]) || (pu_neigh_data_in_v && src1Index_exp[0]);
				end
				`NAMESPACE_BUS: begin
					src1_v_exp = (pe_bus_data_in_v && ~src1Index_exp[0]) || (gb_bus_data_in_v && src1Index_exp[0]);
				end
				default: begin
					src1_v_exp = 0;
					pe_core_weight_rd_addr_exp = 0;
					pe_core_data_rd_addr_exp = 0;
					pe_core_interim_rd_addr_exp = 0; 
					pe_core_gradient_rd_addr_exp = 0;
					pe_core_meta_rd_addr_exp = 0;
				end
			endcase
			
			case(src2Name_exp)
				`NAMESPACE_WEIGHT: begin
					pe_core_weight_rd_addr_exp = src2Index_exp;
					src2_v_exp = pe_weight_in_v;
				end
				`NAMESPACE_DATA: begin
					pe_core_data_rd_addr_exp = src2Index_exp;
					src2_v_exp = pe_data_in_v;
				end
				`NAMESPACE_INTERIM: begin
					pe_core_interim_rd_addr_exp = src2Index_exp;
					src2_v_exp = pe_interim_in_v;
				end
				`NAMESPACE_GRADIENT: begin
					pe_core_gradient_rd_addr_exp = src2Index_exp;
					src2_v_exp = pe_gradient_in_v;
				end
				`NAMESPACE_META: begin
					pe_core_meta_rd_addr_exp = src2Index_exp;
					src2_v_exp = pe_meta_in_v;
				end
				`NAMESPACE_NEIGHBOR: begin
					src2_v_exp = (pe_neigh_data_in_v && ~src2Index_exp[0]) || (pu_neigh_data_in_v && src2Index_exp[0]);
				end
				`NAMESPACE_BUS: begin
					src2_v_exp = (pe_bus_data_in_v && ~src2Index_exp[0]) || (gb_bus_data_in_v && src2Index_exp[0]);
				end
				default: begin
					src2_v_exp = 0;
					pe_core_weight_rd_addr_exp = 0;
					pe_core_data_rd_addr_exp = 0;
					pe_core_interim_rd_addr_exp = 0; 
					pe_core_gradient_rd_addr_exp = 0;
					pe_core_meta_rd_addr_exp = 0;
				end
			endcase
			
		
			src0_rq_exp = |src0Name_exp && inst_in_v; 
			src1_rq_exp = |src1Name_exp && inst_in_v; 
			src2_rq_exp = |src2Name_exp && inst_in_v;
		
			inst_stall_exp = (src0_rq_exp && ~src0_v_exp) || (src1_rq_exp && ~src1_v_exp) || (src2_rq_exp && ~src2_v_exp);
			inst_eol_exp = ~(|src0Name_exp || |src0Name_exp || |src0Name_exp || |dest0Name_exp || |dest0Name_exp || |dest0Name_exp);
			inst_eoc_exp = inst_eol_exp && eol_flag && inst_in_v; 
			
		end	
	endtask
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	task test_main;
    	begin
        	for (i=0; i<4; i=i+1) begin
            	fn = i;
            	print_function(2);
            	repeat (10000) begin
                	fn_test(i);
            	end
            	$display ("Passed");
        	end
        	$display("Testing with Random Functions");
        	repeat (10000) begin
            	random_test;
        	end
       		$display ("Passed");
    	end
	endtask
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	task check_fail;
    	if (fail_flag && !reset) 
   	 	begin
        	$display("%c[1;31m",27);
        	$display ("Test Failed");
        	$display("%c[0m",27);
        	$finish;
  	  end
	endtask
	//--------------------------------------------------------------------------------------

	//--------------------------------------------------------------------------------------
	initial begin
    	$display("***************************************");
    	$display ("Testing PE Controller");
    	$display("***************************************");
    	clk = 0;
    	reset = 0;
    	@(negedge clk);
    	reset = 1;
    	@(negedge clk);
    	reset = 0;

  	 	 test_main;

    	$display("%c[1;34m",27);
    	$display ("Test Passed");
    	$display("%c[0m",27);
    	$finish;
	end

	always @ (posedge clk)
	begin
    	check_fail;
	end
	//-------------------------------------------------------------------------------------	


	always
	begin
		#10 clk = !clk;
	end

endmodule


/*
initial 
	begin
		clk = 0;
		reset = 1;
		
		#20
		reset <= 0;
		inst_in <= 33'b10100000000000000001000100000000;
		inst_in_v <= 1;
		eol_flag <= 0; 
		pe_neigh_data_in_v <= 0;
		pu_neigh_data_in_v <= 0;
		pe_bus_data_in_v <= 0;
		gb_bus_data_in_v <= 0;	
		
		#20
		inst_in = 33'b11100011100000000001000100010000;

		#20
		inst_in = 33'b00100101100100000110001000100000;
		
		#100
		$finish;
			
	end
*/
//33'b00 10000 00000 00000 00100 01000 00000
