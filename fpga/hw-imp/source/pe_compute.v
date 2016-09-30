`timescale 1ns/1ps
`include "inst.vh"
`include "config.vh"

module pe_compute
#(  //--------------------------------------------------------------------------------------
	parameter peId = 0,
	parameter puId = 0,
    parameter integer dataLen = 32,
    parameter integer logNumFn = 3
    //--------------------------------------------------------------------------------------
) ( //--------------------------------------------------------------------------------------
    input  wire [dataLen  - 1 : 0 ] operand1,
    input  wire                     operand1_v,
    input  wire [dataLen  - 1 : 0 ] operand2,
    input  wire                     operand2_v,
    input  wire [dataLen  - 1 : 0 ] operand3,
    input  wire                     operand3_v,
    input  wire [logNumFn - 1 : 0 ] fn,
    output reg  [dataLen  - 1 : 0 ] resultOut,
    output reg                      done,
    output wire                     eol_flag
);  //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    wire[dataLen - 1 : 0] immAdd;
    wire[dataLen - 1 : 0] immSub;
    wire overflowA;
    wire overflowS;
    wire addSubDone;
    assign addSubDone = 1'b1;
    
    addSub #(
        .LEN        ( dataLen       )
    ) addsub1(
        .in1        ( operand1      ),
        .in2        ( operand2      ),
        .outAdd     ( immAdd        ),
        .outSub     ( immSub        ),
        .overflowA  ( overflowA     ),
        .overflowS  ( overflowS     )
    );
    //--------------------------------------------------------------------------------------   

    //--------------------------------------------------------------------------------------
    wire[dataLen - 1 : 0]   immDiv;
    genvar i;
    `ifdef DIV
    generate
    	if(peId == 0 && puId == 0) begin
    		divider #(
        		.dataLen    ( dataLen       )
   	 		)
     		div_unit (
        		.in1        ( operand1      ),
        		.in2        ( operand2      ),
        		.out        ( immDiv        )
    		);
    	end
    endgenerate
    `else
    assign immDiv = 0;
    `endif
    //--------------------------------------------------------------------------------------
    
    
    //--------------------------------------------------------------------------------------
    wire[31 : 0]   immSig;
    wire[31 : 0]   immOperand1;
    
    assign immOperand1 = {{(32-dataLen){1'b0}}, operand1};
    
    `ifdef SIGMOID
    sigmoid #(
        .LEN        ( 32  )
    ) sig_unit ( 
        .in         (immOperand1 ),
        .out        ( immSig    )
        //.done       ( sigDone   )
    );
    
    `else
    assign immSig = 0;
    `endif
    
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    wire[dataLen - 1 : 0]   immSqrt;
    wire sqrtDone;
    assign immSqrt[dataLen - 1 : dataLen/2] = 0;
    
    `ifdef SQRT
    generate
    	if(peId == 0 && puId == 0) begin 
    		sqrt #(
        		.inLen      ( dataLen       )
    		) sqrt_unit (
        		.in         ( operand1      ),
        		.out        ( immSqrt[dataLen/2 - 1 : 0]),
        		.rout		(				),
        		.done       ( sqrtDone      )
    		);
        end
    endgenerate
    `else
    assign immSqrt[dataLen/2 - 1 : 0] = 0;
    `endif
    
    //--------------------------------------------------------------------------------------
    
    //--------------------------------------------------------------------------------------
    wire[dataLen - 1 : 0]   immGau;
    
    `ifdef GAUSSIAN
    gaussian #(
        .dataLen    ( dataLen       )
    ) g_unit (
        .in1        ( operand1      ),
        .out        ( immGau        )
    );
    `else
    assign immGau = 0;
    `endif
    //--------------------------------------------------------------------------------------
    
    
    //--------------------------------------------------------------------------------------
    wire[2*dataLen - 1 : 0]   immMac;
    wire macDone;
    wire macOverflow;
    mac #(
        .LEN        ( dataLen       )
    ) mac_unit (
        .in1        ( operand1      ),
        .in2        ( operand2      ),
        .preResult  ( operand3      ),
        .out        ( immMac        ),
        .overflow   ( macOverflow   ),
        .done       ( macDone       )
    );
    //-------------------------------------------------------------------------------------
    
    always @(*) begin
    	case(fn)
    		`FN_PASS: resultOut = operand1;
            `FN_ADD: resultOut = immAdd;
            `FN_SUB: resultOut = immSub;
            `FN_MUL: resultOut = immMac;
            `FN_MAC: resultOut = immMac[dataLen - 1 : 0];
            
            `ifdef DIV
            `FN_DIV: resultOut = immDiv;
            `endif
            
            `ifdef SQRT
            `FN_SQR: resultOut = immSqrt;
            `endif
            
            `ifdef SIGMOID
            `FN_SIG: resultOut = immSig[dataLen - 1 : 0];
            `endif
            
            `ifdef GAUSSIAN
            `FN_GAU: resultOut = immGau;
            `endif
            default: resultOut = 0;    
        endcase
    end
    
    always @(*) begin
    	case(fn)
    		`FN_PASS: done = operand1_v;
            `FN_ADD: done = operand1_v && operand2_v;
            `FN_SUB: done = operand1_v && operand2_v;
            `FN_MUL: done = macDone && operand1_v && operand2_v;
            `FN_MAC: done = macDone && operand1_v && operand2_v;
            
            `ifdef DIV
            `FN_DIV: done = operand1_v && operand2_v;
            `endif
            
            `ifdef SQRT
            `FN_SQR: done = sqrtDone && operand1_v;
            `endif
            
            `ifdef SIGMOID
            `FN_SIG: done = operand1_v; 
            `endif
            
            `ifdef GAUSSIAN
            `FN_GAU: done = operand1_v;
            `endif
            default: done = 0;    
        endcase
    end
    
    assign eol_flag = (fn == `FN_SUB) && (immSub == 0); 

endmodule
