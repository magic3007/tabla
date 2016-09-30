`timescale 1ns/1ps
`include "log.vh"
module shuffler
#(
// ******************************************************************
// PARAMETERS
// ******************************************************************
    parameter integer DATA_WIDTH  = 16,
    parameter integer NUM_DATA    = 16
// ******************************************************************
) (
// ******************************************************************
// IO
// ******************************************************************
    input  wire                             ACLK,
    input  wire                             ARESETN,
    input  wire                             RD_EN,
    input  wire                             WR_EN,
    input  wire [SHUFFLE_DATA_WIDTH-1:0]    DATA_IN,
    input  wire [SHUFFLE_CTRL_WIDTH-1:0]    CTRL_IN,
    output wire [SHUFFLE_DATA_WIDTH-1:0]    DATA_OUT
// ******************************************************************
);

// ******************************************************************
// Localparams
// ******************************************************************
    localparam integer SHUFFLE_DATA_WIDTH = DATA_WIDTH * NUM_DATA;
    localparam integer CTRL_WIDTH         = `C_LOG_2 (NUM_DATA);
    localparam integer SHUFFLE_CTRL_WIDTH = CTRL_WIDTH * NUM_DATA;
// ******************************************************************

// ******************************************************************
// Local wires and regs
// ******************************************************************
    genvar i;
    wire [SHUFFLE_DATA_WIDTH-1:0]    data_in_r;
    wire [SHUFFLE_CTRL_WIDTH-1:0]    ctrl_in_r;
    wire [SHUFFLE_DATA_WIDTH-1:0]    data_out;
// ******************************************************************

// ******************************************************************
// Register
// ******************************************************************
    register #(
        .LEN        ( SHUFFLE_DATA_WIDTH    )
    ) data_in_register (
        .clk        ( ACLK                  ),
        .reset      ( !ARESETN              ),
        .wrEn       ( RD_EN                 ),
        .dataIn     ( DATA_IN               ),
        .dataOut    ( data_in_r             )
    );

    register #(
        .LEN        ( SHUFFLE_CTRL_WIDTH    )
    ) ctrl_in_register (
        .clk        ( ACLK                  ),
        .reset      ( !ARESETN              ),
        .wrEn       ( RD_EN                 ),
        .dataIn     ( CTRL_IN               ),
        .dataOut    ( ctrl_in_r             )
    );

    register #(
        .LEN        ( SHUFFLE_DATA_WIDTH    )
    ) data_out_register (
        .clk        ( ACLK                  ),
        .reset      ( !ARESETN              ),
        .wrEn       ( WR_EN                 ),
        .dataIn     ( data_out              ),
        .dataOut    ( DATA_OUT              )
    );
// ******************************************************************

// ******************************************************************
// Mux instances
// ******************************************************************
generate
for (i=0; i<NUM_DATA; i=i+1)
begin : INST_MUXES

    wire [SHUFFLE_DATA_WIDTH-1:0] mux_data_in;
    wire [DATA_WIDTH        -1:0] mux_data_out;
    wire [CTRL_WIDTH        -1:0] mux_ctrl_in;

    assign mux_ctrl_in = ctrl_in_r [i*CTRL_WIDTH+:CTRL_WIDTH];
    assign mux_data_in = data_in_r;
    assign data_out [i*DATA_WIDTH+:DATA_WIDTH] = mux_data_out;

    mux #(
        .DATA_WIDTH     ( DATA_WIDTH    ),
        .NUM_DATA       ( NUM_DATA      )
    ) mux_shuffle (
        .DATA_IN        ( mux_data_in   ),
        .CTRL_IN        ( mux_ctrl_in   ),
        .DATA_OUT       ( mux_data_out  )
    );

end
endgenerate
// ******************************************************************

endmodule
