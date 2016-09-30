`timescale 1ns/1ps
`include "inst.vh"
`include "config.vh"

module pe 
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
 	//output wire                           inst_eoc, 
    output wire  							inst_eol,
    
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

	localparam destNum               = 3;
    localparam srcNum                = 3;
    localparam fnLen                 = 3;
    localparam nameLen               = 3;
    
    localparam instAddrLen           = `INDEX_INST;
    localparam dataAddrLen           = `INDEX_DATA;
    localparam weightAddrLen         = `INDEX_WEIGHT;
    localparam metaAddrLen           = `INDEX_META;
    localparam interimAddrLen        = `INDEX_INTERIM;
  
	localparam instLen               = fnLen + nameLen*destNum + nameLen*srcNum + indexLen*(destNum+srcNum);

	localparam peBusIndexLen         = logNumPe + 1;
    localparam gbBusIndexLen         = logNumPu + 1;
    
	//----------------------------------------------------------------------------------------
    //from controller
 
    wire weight_wrt;
    wire [weightAddrLen - 1 : 0 ] weight_wrt_addr;
    wire [dataLen - 1 : 0 ] weight_wrt_data;
    
    wire gradient_wrt;
    wire [weightAddrLen - 1 : 0 ] gradient_wrt_addr;
    wire [dataLen - 1 : 0 ] gradient_wrt_data;
    
    //to controller
    wire [instLen - 1 : 0] inst_read;
    wire inst_valid;
    wire pe_namespace_wrt_done;
    wire data_out_v, weight_out_v, gradient_out_v, meta_out_v;
    
    //generated here
    wire [dataAddrLen - 1 : 0 ] data_rd_addr;
    wire [weightAddrLen - 1 : 0 ] weight_rd_addr;
    wire [weightAddrLen - 1 : 0 ] gradient_rd_addr;
    wire [metaAddrLen - 1 : 0 ] meta_rd_addr;
    
    //operand data
    wire [dataLen - 1 : 0 ] op_data_read;
    wire [dataLen - 1 : 0 ] op_weight_read;
    wire [dataLen - 1 : 0 ] op_gradient_read;
    wire [dataLen - 1 : 0 ] op_meta_read;
    
	//----------------------------------------------------------------------------------------
	//stall logic
	wire inst_stall_bram, inst_stall_comp, inst_stall;
	
	wire [srcNum - 1 : 0] src0Name, src1Name, src2Name;
	reg  [srcNum - 1 : 0] src0Name_d, src1Name_d, src2Name_d;
	wire src0_v, src1_v, src2_v;
	wire src0_v_bram, src1_v_bram, src2_v_bram;
	reg  src0_v_bram_d, src1_v_bram_d, src2_v_bram_d;
	
	wire [indexLen - 1: 0] src0Index, src1Index, src2Index;
	wire bus_contention;
	
	wire [(1 << srcNum) - 1 : 0] src0_decoder_out, src1_decoder_out, src2_decoder_out;
	reg [(1 << srcNum) - 1 : 0] src0_decoder_out_d, src1_decoder_out_d, src2_decoder_out_d;	

	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src0(
		src0Name,
 		src0_decoder_out 
	);
	
	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src1(
		src1Name,
 		src1_decoder_out 
	);
	
	decoder
	#(
		.inputLen(srcNum)
	)
	decode_src2(
		src2Name,
 		src2_decoder_out 
	);
	
	always @(posedge clk) begin
		if(reset) begin
			src0_decoder_out_d <= 0;
			src1_decoder_out_d <= 0;
			src2_decoder_out_d <= 0;
		
			src0_v_bram_d <= 0;
			src1_v_bram_d <= 0;
			src2_v_bram_d <= 0;
			src0Name_d <= 0;
			src1Name_d <= 0;
			src2Name_d <= 0;
		end
		else if(~( inst_stall || bus_contention)) begin
			src0_decoder_out_d <= src0_decoder_out;
			src1_decoder_out_d <= src1_decoder_out;
			src2_decoder_out_d <= src2_decoder_out;
			
			src0_v_bram_d <= src0_v_bram;
			src1_v_bram_d <= src0_v_bram;
			src2_v_bram_d <= src0_v_bram;
			
			src0Name_d <= src0Name;
			src1Name_d <= src1Name;
			src2Name_d <= src2Name;
		end
	end
	
	//generating the stall function
	//---------------------------------------------------------------------------------------
	wire inst_valid_out, inst_valid_out_d;
	
	wire pe_neigh_data_clear, pu_neigh_data_clear;
    wire pe_neigh_data_rq, pu_neigh_data_rq;
    
    wire [dataLen - 1 : 0] pe_bus_data_reg, gb_bus_data_reg;
    wire pe_bus_data_reg_v , gb_bus_data_reg_v;
    
    wire [dataLen - 1 : 0] bus_data_out; 
    wire interim_out_v, interim_in_v;
    wire pe_neigh_data_reg_v, pu_neigh_data_reg_v;
    
	bram_stall 
	#(
		.srcNum(srcNum)
	)
	bram_stall_unit(
		.data_out_v(data_out_v),
		.weight_out_v(weight_out_v),
		.gradient_out_v(gradient_out_v),
		.meta_out_v(meta_out_v),
		
		.src0_decoder_out(src0_decoder_out),
		.src1_decoder_out(src1_decoder_out),
		.src2_decoder_out(src2_decoder_out),
		
		.src0_v_bram(src0_v_bram),
		.src1_v_bram(src1_v_bram),
		.src2_v_bram(src2_v_bram),
		
		.inst_valid(inst_valid_out_d),
		
		.inst_stall_bram(inst_stall_bram)
	);
	
	comp_stall #(
		.srcNum(srcNum),
		.indexLen(indexLen)
	)
	comp_stall_unit(
		.interim_out_v(interim_out_v),
		
		.pe_neigh_data_reg_v(pe_neigh_data_reg_v),
		.pu_neigh_data_reg_v(pu_neigh_data_reg_v),
		
		.pe_bus_data_reg_v(pe_bus_data_reg_v),
		.gb_bus_data_reg_v(gb_bus_data_reg_v),
		
		.src0Index(src0Index),
		.src1Index(src1Index),
		.src2Index(src2Index),
		
		.src0_decoder_out(src0_decoder_out_d),
		.src1_decoder_out(src1_decoder_out_d),
		.src2_decoder_out(src2_decoder_out_d),
		
		.src0_v_bram(src0_v_bram_d),
		.src1_v_bram(src1_v_bram_d),
		.src2_v_bram(src2_v_bram_d),
		
		.inst_valid(inst_valid_out),
		
		.src0_v(src0_v),
		.src1_v(src1_v),
		.src2_v(src2_v),
		
		.inst_stall_comp(inst_stall_comp)
	);
	
	assign inst_stall = inst_stall_comp || inst_stall_bram;
	
	//----------------------------------------------------------------------------------------
    pe_namespace_wrapper
    #(
    	.peId						( peId						),
    	.logNumPe					( logNumPe					),	
        .indexLen                	( indexLen               	),
        .instAddrLen                ( instAddrLen               ),
        .dataAddrLen                ( dataAddrLen               ),
        .weightAddrLen              ( weightAddrLen             ),
        .metaAddrLen                ( metaAddrLen               ),
        .dataLen                    ( dataLen                   ),
        .instLen                    ( instLen                   ),
        .logMemNamespaces           ( logMemNamespaces          ),
        .memDataLen					( memDataLen				),
        .logNumPeMemColumn			( logNumPeMemColumn			) 
    )
    pe_namespace_wrapper_unit(
        .clk                        ( clk                       ),
        .reset                      ( reset                     ),
        .start						( start						),
//        .inst_restart				( inst_restart				),
        
        .mem_wrt_valid				( mem_wrt_valid				),
        .mem_weight_rd_valid		( mem_weight_rd_valid		),
		.peId_mem_in				( peId_mem_in				),
        .mem_data_type              ( mem_data_type             ),
        .mem_data_input             ( mem_data_input            ),
        .mem_data_output            ( mem_data_output           ),
                          
        .pe_namespace_wrt_done      ( pe_namespace_wrt_done     ), 
    
        .pe_core_inst_stall         ( inst_stall                ),
        .pe_core_bus_contention		( bus_contention			),
        
        .pe_core_data_rd_addr       ( data_rd_addr              ),
    
        .pe_core_weight_wrt_addr    ( weight_wrt_addr           ),
        .pe_core_weight_wrt         ( weight_wrt                ),
        .pe_core_weight_wrt_data    ( weight_wrt_data           ),
        .pe_core_weight_rd_addr     ( weight_rd_addr            ),
    
        .pe_core_gradient_wrt_addr  ( gradient_wrt_addr         ),
        .pe_core_gradient_wrt       ( gradient_wrt              ),
        .pe_core_gradient_wrt_data  ( gradient_wrt_data         ),
        .pe_core_gradient_rd_addr   ( gradient_rd_addr          ),
    
        .pe_core_meta_rd_addr       ( meta_rd_addr              ),
       
        .pe_namespace_inst_out      ( inst_read                 ),
        .pe_namespace_inst_valid    ( inst_valid                ),
        
        .pe_namespace_data_out_v	( data_out_v                ), 
        .pe_namespace_weight_out_v	( weight_out_v				), 
        .pe_namespace_gradient_out_v( gradient_out_v			), 
        .pe_namespace_meta_out_v	( meta_out_v				),
        
        .pe_namespace_data_out      ( op_data_read              ),
        .pe_namespace_weight_out    ( op_weight_read            ),
        .pe_namespace_gradient_out  ( op_gradient_read          ),
        .pe_namespace_meta_out      ( op_meta_read              )
    );
    //----------------------------------------------------------------------------------------
    

    //----------------------------------------------------------------------------------------
    wire interim_wrt;
    wire [interimAddrLen - 1 : 0 ] interim_wrt_addr;
    wire [dataLen - 1 : 0 ] interim_data_in;
    wire [interimAddrLen - 1 : 0 ] interim_rd_addr;
    wire [dataLen - 1 : 0 ] interim_data_out;
    
    bufferRD #(
        .addrLen                    ( interimAddrLen            ), 
        .dataLen                    ( dataLen                   )
    ) interimBuffer ( 
        .clk                        ( clk                       ),
        .reset                      ( reset                     ),
        .wrt                        ( interim_wrt               ),
        .wrt_addr                   ( interim_wrt_addr          ),
        .rd_addr                    ( interim_rd_addr           ),
        .data_in                    ( interim_data_in           ),
        .data_out                   ( interim_data_out          )
    );
    
    register#(
        .LEN                        ( 1                         )
    )
    interimRegV(
        .clk                        ( clk                       ), 
        .dataIn                     ( interim_in_v         		),
        .dataOut                    ( interim_out_v             ),
        .reset                      ( reset                     ),
        .wrEn                       ( interim_wrt               )
    );
    
    
    //to check if the incoming data from neighbour PE or PU is valid
    wire [dataLen - 1 : 0] pe_neigh_data_reg, pu_neigh_data_reg;
    
    wire [dataLen - 1 : 0] neigh_data_out; 
    assign neigh_data_out = pe_neigh_data_reg_v ? pe_neigh_data_reg : pu_neigh_data_reg; 
       
    assign pe_neigh_data_clear = ~inst_stall && pe_neigh_data_rq && ~bus_contention && inst_valid_out;
    assign pu_neigh_data_clear = ~inst_stall && pu_neigh_data_rq && ~bus_contention && inst_valid_out;
    
    register#(
        .LEN                        ( dataLen                   )
    )
    peNeigReg(
        .clk                        ( clk                       ), 
        .dataIn                     ( pe_neigh_data_in          ),
        .dataOut                    ( pe_neigh_data_reg         ),
        .reset                      ( reset                     ),
        .wrEn                       ( pe_neigh_data_in_v        )
    );
    
    register#(
        .LEN                        ( 1                         )
    )
    peNeigRegV(
        .clk                        ( clk                       				 	), 
        .dataIn                     ( (pe_neigh_data_in_v || ~pe_neigh_data_clear) 	),
        .dataOut                    ( pe_neigh_data_reg_v      					  	),
        .reset                      ( reset                     				  	),
        .wrEn                       ( (pe_neigh_data_in_v || pe_neigh_data_clear) 	)
    );
    
   	register#(
        .LEN                        ( dataLen                   )
    )
    puNeigReg(
        .clk                        ( clk                       ), 
        .dataIn                     ( pu_neigh_data_in         	),
        .dataOut                    ( pu_neigh_data_reg         ),
        .reset                      ( reset                     ),
        .wrEn                       ( pu_neigh_data_in_v       	)
    );
    
    register#(
        .LEN                        ( 1                         )
    )
    puNeigRegV(
        .clk                        ( clk                       				   ), 
        .dataIn                     ( (pu_neigh_data_in_v || ~pu_neigh_data_clear) ),
        .dataOut                    ( pu_neigh_data_reg_v      					   ),
        .reset                      ( reset                     				   ),
        .wrEn                       ( (pu_neigh_data_in_v || pu_neigh_data_clear)  )
    );
    
   
    assign bus_data_out = pe_bus_data_reg_v ? pe_bus_data_reg : gb_bus_data_reg; 
    
    wire pe_bus_data_clear, gb_bus_data_clear;
    wire pe_bus_data_rq, gb_bus_data_rq;
    
    assign pe_bus_data_clear = ~inst_stall && pe_bus_data_rq;
    assign gb_bus_data_clear = ~inst_stall && gb_bus_data_rq;

    register#(
        .LEN                        ( dataLen                   )
    )
    peBusReg(
        .clk                        ( clk                       ), 
        .dataIn                     ( pe_bus_data_in  			),
        .dataOut                    ( pe_bus_data_reg           ),
        .reset                      ( reset                     ),
        .wrEn                       ( pe_bus_data_in_v 		 	)
    );    
    
    register#(
        .LEN                        ( 1                         )
    )
    peBusRegV(
        .clk                        ( clk                       				), 
        .dataIn                     ( (pe_bus_data_in_v  || ~pe_bus_data_clear)	),
        .dataOut                    ( pe_bus_data_reg_v         				),
        .reset                      ( reset                     				),
        .wrEn                       ( (pe_bus_data_in_v || pe_bus_data_clear)	)
    );
    
   register#(
        .LEN                        ( dataLen                   )
    )
    gbBusReg(
        .clk                        ( clk                       ), 
        .dataIn                     ( gb_bus_data_in            ),
        .dataOut                    ( gb_bus_data_reg           ),
        .reset                      ( reset                     ),
        .wrEn                       ( gb_bus_data_in_v          )
    );    
    
    register#(
        .LEN                        ( 1                         )
    )
    gbBusRegV(
        .clk                        ( clk                       				), 
        .dataIn                     ( (gb_bus_data_in_v  || ~gb_bus_data_clear) ),
        .dataOut                    ( gb_bus_data_reg_v        					),
        .reset                      ( reset                    					),
        .wrEn                       ( (gb_bus_data_in_v  || gb_bus_data_clear)	)
    );
    //----------------------------------------------------------------------------------------
    
    //----------------------------------------------------------------------------------------
    wire [fnLen - 1 : 0] compute_fn;
    wire [indexLen - 1 : 0] pe_bus_wrt_addr;
    wire [indexLen - 1 : 0] gb_bus_wrt_addr;
    
    wire pe_neig_wrt;
    wire pu_neig_wrt;
    
    wire src0_rq, src1_rq, src2_rq;

    wire eol_flag;
    
    assign bus_contention = (~pe_bus_contention && pe_bus_wrt_addr[0]) || (~gb_bus_contention && gb_bus_wrt_addr[0] );
    
    pe_controller #(
        .destNum                    ( destNum                   ),
        .srcNum                     ( srcNum                    ),
        .fnLen                      ( fnLen                     ),
        .nameLen                    ( nameLen                   ),
        .indexLen                   ( indexLen                  ),
        .weightAddrLen              ( weightAddrLen             ),
        .interimAddrLen             ( interimAddrLen            ),
        .dataAddrLen             	( dataAddrLen            	),
        .metaAddrLen             	( metaAddrLen            	)
    )
    pe_controller_unit
    (
    	.clk						(clk						),
    	.reset						(reset						),	
        .inst_in                    ( inst_read                 ),
        .inst_in_v                  ( inst_valid                ),
        .inst_out_v					( inst_valid_out			),
        .inst_out_v_dd				( inst_valid_out_d			),
        
        .eol_flag                   ( eol_flag                  ),
        
        .pe_compute_fn              ( compute_fn                ),
        
        .pe_core_weight_wrt         ( weight_wrt                ),
        .pe_core_gradient_wrt       ( gradient_wrt              ), 
        .pe_core_interim_wrt        ( interim_wrt               ),
    
        .pe_core_gradient_wrt_addr  ( gradient_wrt_addr         ), 
        .pe_core_weight_wrt_addr    ( weight_wrt_addr           ), 
        .pe_core_interim_wrt_addr   ( interim_wrt_addr          ),
    
        .pe_core_pe_bus_wrt_addr    ( pe_bus_wrt_addr           ), 
        .pe_core_gb_bus_wrt_addr    ( gb_bus_wrt_addr           ),
        
        .pe_core_pe_neig_wrt        ( pe_neig_wrt               ),
        .pe_core_pu_neig_wrt        ( pu_neig_wrt               ),
    
        .pe_core_data_rd_addr       ( data_rd_addr              ), 
        .pe_core_weight_rd_addr     ( weight_rd_addr            ), 
        .pe_core_gradient_rd_addr   ( gradient_rd_addr          ),
        .pe_core_interim_rd_addr    ( interim_rd_addr           ), 
        .pe_core_meta_rd_addr       ( meta_rd_addr              ),
        
        .pe_neigh_data_rq 			( pe_neigh_data_rq			),
	 	.pu_neigh_data_rq 			( pu_neigh_data_rq			),
	 	.pe_bus_data_rq 			( pe_bus_data_rq			),
	 	.gb_bus_data_rq 			( gb_bus_data_rq			),

        .src0_rq                    ( src0_rq                   ), 
        .src1_rq                    ( src1_rq                   ), 
        .src2_rq                    ( src2_rq                   ),
        
        .src0Index                 	( src0Index                	),
        .src1Index                 	( src1Index                	),
        .src2Index                 	( src2Index                	),
        
        .src0Name                   ( src0Name                  ),
        .src1Name                   ( src1Name                  ),
        .src2Name                   ( src2Name                  ),
        
        .inst_stall                 ( inst_stall                ),
        .bus_contention				( bus_contention			),
 		//.inst_eoc                 ( inst_eoc                  ),
        .inst_eol					( inst_eol                  )
		//.inst_restart				( inst_restart				)
    );

    //----------------------------------------------------------------------------------------
    
    
    //----------------------------------------------------------------------------------------
    
    wire [dataLen - 1:0] operand0_data;
    wire [dataLen - 1:0] operand1_data;
    wire [dataLen - 1:0] operand2_data;
    
    op_selector#(
        .LEN                        ( dataLen                   )
    )
    operand0(
        .sel                        ( src0Name_d              	),
        .weight                     ( op_weight_read            ),
        .data                       ( op_data_read              ),
        .gradient                   ( op_gradient_read          ),
        .interim                    ( interim_data_out          ),                                            
        .meta                       ( op_meta_read              ),
        .neigh                      ( neigh_data_out            ),
        .bus                        ( bus_data_out              ),
        .out                        ( operand0_data             )
    );
    
    op_selector#(
        .LEN                        (  dataLen                  )
    )
    operand1(
        .sel                        ( src1Name_d              	),
        .weight                     ( op_weight_read            ),
        .data                       ( op_data_read              ),
        .gradient                   ( op_gradient_read          ),
        .interim                    ( interim_data_out          ),
        .meta                       ( op_meta_read              ),
        .neigh                      ( neigh_data_out            ),
        .bus                        ( bus_data_out              ),
        .out                        ( operand1_data             )
    );
    
    op_selector#(
        .LEN                        ( dataLen                   )
    )
    operand2(
        .sel                        ( src2Name_d	                ),
        .weight                     ( op_weight_read            ),
        .data                       ( op_data_read              ),
        .gradient                   ( op_gradient_read          ),
        .interim                    ( interim_data_out          ),
        .meta                       ( op_meta_read              ),
        .neigh                      ( neigh_data_out            ),
        .bus                        ( bus_data_out              ),
        .out                        ( operand2_data             )
    );
    //----------------------------------------------------------------------------------------
    
    
    //----------------------------------------------------------------------------------------
    wire pe_compute_done;
    wire pe_compute_valid;
    assign pe_compute_valid = pe_compute_done && ~inst_stall;
    wire eol_flag_in;
    wire [dataLen - 1:0] compute_data_out;
    
    pe_compute #(
        .dataLen                    ( dataLen                   ),
        .logNumFn                   ( fnLen                     ),
        .peId						( peId						),
    	.puId						( puId						)
    ) u_pe_compute (
        .operand1                   ( operand0_data             ),
        .operand1_v                 ( src0_v                    ),
        .operand2                   ( operand1_data             ),
        .operand2_v                 ( src1_v                    ),
        .operand3                   ( operand2_data             ),
        .operand3_v                 ( src2_v                    ),
        .fn                         ( compute_fn                ),
        .resultOut                  ( compute_data_out          ),
        .done                       ( pe_compute_done           ),
        .eol_flag					( eol_flag_in				)
    );
    
    register#(
        .LEN                        ( 1                         )
    )
    eolFlag(
        .clk                        ( clk                       ), 
        .dataIn                     ( eol_flag_in            	),
        .dataOut                    ( eol_flag          		),
        .reset                      ( reset                     ),
        .wrEn                       ( 1'b1     			        )
    );
    
    assign interim_data_in = compute_data_out;
    assign interim_in_v = pe_compute_valid;
    
    assign pe_neigh_data_out = compute_data_out;
    assign pu_neigh_data_out = compute_data_out;
    assign pe_bus_data_out = compute_data_out;
    assign gb_bus_data_out = compute_data_out;
    
    assign pe_neigh_data_out_v = pe_compute_valid & pe_neig_wrt;
    assign pu_neigh_data_out_v = pe_compute_valid & pu_neig_wrt;
    assign pe_bus_data_out_v = {peBusIndexLen{pe_compute_valid}} & pe_bus_wrt_addr[peBusIndexLen - 1 : 0];
    
    assign gb_bus_data_out_v = {gbBusIndexLen{pe_compute_valid}} & gb_bus_wrt_addr[gbBusIndexLen - 1 : 0]; 
    //----------------------------------------------------------------------------------------


endmodule

