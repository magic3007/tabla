`timescale 1ns/1ps

module accelerator #(
    parameter integer DATA_WIDTH        = 64,
    parameter integer BUFFER_ADDR_WIDTH = 5,
    parameter         TYPE              = "NA"
)
(
    input  wire                         ACLK,
    input  wire                         ARESETN,

    input  wire                         start,
    output wire                         done,

    input  wire                         inBuf_empty,
    input  wire [BUFFER_ADDR_WIDTH : 0] inBuf_count,
    output wire                         inBuf_pop,
    input  wire [DATA_WIDTH - 1    : 0] data_from_inBuf,

    input  wire                         outBuf_full,
    input  wire [BUFFER_ADDR_WIDTH : 0] outBuf_count,
    output wire                         outBuf_push,
    output wire [DATA_WIDTH - 1    : 0] data_to_outBuf
);

generate
if (TYPE == "LOOPBACK")
begin

    reg inBuf_data_valid, outBuf_data_valid;
    
    assign inBuf_pop = !inBuf_empty;
    
    always @(posedge ACLK)
    begin:READ_DATA_VALID
        if (!ARESETN) begin
            inBuf_data_valid <= 1'b0;
        end else begin
            inBuf_data_valid <= inBuf_pop;
        end
    end


    reg [DATA_WIDTH-1:0] data_out;
    reg data_out_valid;

    assign data_to_outBuf = data_out;
    assign outBuf_push = data_out_valid;

    always @(posedge ACLK)
    begin:WRITE_DATA
        if (!ARESETN) begin
            data_out_valid    <= 1'b0;
        end else if (inBuf_data_valid) begin
            data_out_valid    <= 1'b1;
        end else begin
            data_out_valid    <= 1'b0;
        end
    end
    always @(posedge ACLK)
    begin:WRITE_DATA_VALID
        if (!ARESETN) begin
            data_out <= 0;
        end else begin
            data_out <= data_from_inBuf;
        end
    end
end
else begin

    reg inBuf_data_valid, outBuf_data_valid;
    
    assign inBuf_pop = !inBuf_empty;
    
    always @(posedge ACLK)
    begin:READ_DATA_VALID
        if (!ARESETN) begin
            inBuf_data_valid <= 1'b0;
        end else begin
            inBuf_data_valid <= inBuf_pop;
        end
    end
    localparam integer MUL_OPERAND_WIDTH = DATA_WIDTH/2;
    wire enable = inBuf_data_valid;
    wire [MUL_OPERAND_WIDTH-1:0] mul_0 = data_from_inBuf[DATA_WIDTH-1:MUL_OPERAND_WIDTH];
    wire [MUL_OPERAND_WIDTH-1:0] mul_1 = data_from_inBuf[MUL_OPERAND_WIDTH-1:0];

    wire [DATA_WIDTH-1:0] out;
    wire out_valid;
    assign data_to_outBuf = out;
    assign outBuf_push = out_valid;

    multiplier #(
        .WIDTH_0            ( MUL_OPERAND_WIDTH     ),
        .WIDTH_1            ( MUL_OPERAND_WIDTH     ),
        .WIDTH_OUT          ( DATA_WIDTH            )
    ) mul_test (
        .CLK                ( ACLK                  ), //input  
        .RESET              ( !ARESETN              ), //input  
        .ENABLE             ( enable                ), //input  
        .MUL_0              ( mul_0                 ), //input  
        .MUL_1              ( mul_1                 ), //input
        .OUT                ( out                   ), //output 
        .OUT_VALID          ( out_valid             )  //output 
    );
end
endgenerate

endmodule
