`timescale 1ns/1ps
(* rom_extract = "yes" *)
module ROM #(
// Parameters
    parameter   DATA_WIDTH          = 16,
    parameter   ADDR_WIDTH          = 6,
    parameter   INIT                = "weight.txt",
    parameter   TYPE                = "block"
) (
// Port Declarations
    input  wire                         CLK,
    input  wire                         RESET,
    input  wire  [ADDR_WIDTH-1:0]       ADDRESS,
    input  wire                         ENABLE,
    output reg   [DATA_WIDTH-1:0]       DATA_OUT,
    output reg                          DATA_OUT_VALID
);

// ******************************************************************
// Internal variables
// ******************************************************************
    reg     [DATA_WIDTH-1:0]        mem[0:(1<<ADDR_WIDTH)-1];     //Memory
    reg     [ADDR_WIDTH-1:0]        address;
    (* rom_style = TYPE, Keep = "true" *)
    reg     [DATA_WIDTH-1:0]        rdata;
	 
// ******************************************************************
// Read Logic
// ******************************************************************

    always @ (posedge CLK)
    begin : READ_VALID
        if (RESET) begin
            DATA_OUT_VALID <= 1'b0;
        end else if (ENABLE) begin
            DATA_OUT_VALID <= 1'b1;
        end
    end
    
//    always @ (posedge CLK)
//    begin : READ_ADDR
//        if(!RESET) begin
//            address <= ADDRESS;
//        end else begin
//            address <= 0;
//        end
//    end


//    always @ (posedge CLK)
//    begin : READ_DATA
//        if(!RESET) begin
//            if (ENABLE)
//                DATA_OUT <= mem[address];
//            else
//                DATA_OUT <= DATA_OUT;
//        end else begin
//            DATA_OUT <= {DATA_WIDTH{1'b0}};
//        end
//    end

//    assign DATA_OUT = mem[ADDRESS];

// ******************************************************************
// Initialization
// ******************************************************************

initial $readmemh (INIT, mem);

always @(ADDRESS) begin
    rdata <= mem[ADDRESS];
 end
 

 always @(posedge CLK) begin
    if (ENABLE)
        DATA_OUT <= rdata;
end
  
endmodule 
