`timescale 1ns/1ps
`include "log.vh"
module mem_interface
#(
// ******************************************************************
// PARAMETERS
// ******************************************************************
    parameter integer C_M_AXI_ADDR_WIDTH    = 32,
    parameter integer DATA_WIDTH            = 16,
    parameter integer NUM_DATA              = 16,
    parameter integer NUM_PE                = 64,
    parameter integer RD_BUF_ADDR_WIDTH     = 10,
    parameter integer NUM_AXI               = 1,
    parameter integer NAMESPACE_WIDTH       = 2,
    parameter integer TX_SIZE_WIDTH         = 9
// ******************************************************************
) (
// ******************************************************************
// IO
// ******************************************************************
    input  wire                             ACLK,
    input  wire                             ARESETN,
    input  wire [RD_IF_DATA_WIDTH-1:0]      rdata,
    output wire [RD_IF_DATA_WIDTH-1:0]      wdata,
    input  wire                             DATA_INOUT_WB,
    input  wire                             EOI,
    input  wire                             EOC,
    output wire [CTRL_PE_WIDTH-1:0]         CTRL_PE,

    output wire                             DATA_IO_DIR,

    // Master Interface Write Address
    output wire [32*NUM_AXI-1:0]            S_AXI_AWADDR,
    output wire [2*NUM_AXI-1:0]             S_AXI_AWBURST,
    output wire [4*NUM_AXI-1:0]             S_AXI_AWCACHE,
    output wire [6*NUM_AXI-1:0]             S_AXI_AWID,
    output wire [4*NUM_AXI-1:0]             S_AXI_AWLEN,
    output wire [2*NUM_AXI-1:0]             S_AXI_AWLOCK,
    output wire [3*NUM_AXI-1:0]             S_AXI_AWPROT,
    output wire [4*NUM_AXI-1:0]             S_AXI_AWQOS,
    output wire [1*NUM_AXI-1:0]             S_AXI_AWUSER,
    input  wire [1*NUM_AXI-1:0]             S_AXI_AWREADY,
    output wire [3*NUM_AXI-1:0]             S_AXI_AWSIZE,
    output wire [1*NUM_AXI-1:0]             S_AXI_AWVALID,
    
    // Master Interface Write Data
    output wire [RD_IF_DATA_WIDTH-1:0]      S_AXI_WDATA,
    output wire [6*NUM_AXI-1:0]             S_AXI_WID,
    output wire [1*NUM_AXI-1:0]             S_AXI_WUSER,
    output wire [1*NUM_AXI-1:0]             S_AXI_WLAST,
    input  wire [1*NUM_AXI-1:0]             S_AXI_WREADY,
    output wire [WSTRB_WIDTH-1:0]           S_AXI_WSTRB,
    output wire [1*NUM_AXI-1:0]             S_AXI_WVALID,

    // Master Interface Write Response
    input  wire [6*NUM_AXI-1:0]             S_AXI_BID,
    input  wire [1*NUM_AXI-1:0]             S_AXI_BUSER,
    output wire [1*NUM_AXI-1:0]             S_AXI_BREADY,
    input  wire [2*NUM_AXI-1:0]             S_AXI_BRESP,
    input  wire [1*NUM_AXI-1:0]             S_AXI_BVALID,
    
    // Master Interface Read Address
    output wire [32*NUM_AXI-1:0]            S_AXI_ARADDR,
    output wire [2*NUM_AXI-1:0]             S_AXI_ARBURST,
    output wire [4*NUM_AXI-1:0]             S_AXI_ARCACHE,
    output wire [6*NUM_AXI-1:0]             S_AXI_ARID,
    output wire [4*NUM_AXI-1:0]             S_AXI_ARLEN,
    output wire [2*NUM_AXI-1:0]             S_AXI_ARLOCK,
    output wire [3*NUM_AXI-1:0]             S_AXI_ARPROT,
    output wire [4*NUM_AXI-1:0]             S_AXI_ARQOS,
    output wire [1*NUM_AXI-1:0]             S_AXI_ARUSER,
    input  wire [1*NUM_AXI-1:0]             S_AXI_ARREADY,
    output wire [3*NUM_AXI-1:0]             S_AXI_ARSIZE,
    output wire [1*NUM_AXI-1:0]             S_AXI_ARVALID,

    // Master Interface Read Data 
    input  wire [RD_IF_DATA_WIDTH-1:0]      S_AXI_RDATA,
    input  wire [6*NUM_AXI-1:0]             S_AXI_RID,
    input  wire [1*NUM_AXI-1:0]             S_AXI_RUSER,
    input  wire [1*NUM_AXI-1:0]             S_AXI_RLAST,
    output wire [1*NUM_AXI-1:0]             S_AXI_RREADY,
    input  wire [2*NUM_AXI-1:0]             S_AXI_RRESP,
    input  wire [1*NUM_AXI-1:0]             S_AXI_RVALID,

    // TXN REQ
    input  wire                             rx_req,
    input  wire [TX_SIZE_WIDTH-1:0]         rx_req_size,
    output wire                             rx_done,

    input  wire                             start,
    output wire                             compute_start
// ******************************************************************
);

// ******************************************************************
// Localparams
// ******************************************************************
    localparam integer WSTRB_WIDTH          = (RD_BUF_DATA_WIDTH/8) * NUM_AXI;

    localparam integer RD_BUF_DATA_WIDTH    = DATA_WIDTH * NUM_DATA / NUM_AXI;
    localparam integer RD_IF_DATA_WIDTH     = DATA_WIDTH * NUM_DATA;
    localparam integer CTRL_PE_WIDTH        = (`C_LOG_2(NUM_PE/NUM_DATA) + 1) 
                                              * NUM_DATA + NAMESPACE_WIDTH;
    localparam integer SHIFTER_CTRL_WIDTH   = `C_LOG_2(NUM_DATA);
    localparam integer NUM_OPS              = 4;
    localparam integer OP_CODE_WIDTH        = `C_LOG_2 (NUM_OPS);
    localparam integer CTRL_BUF_DATA_WIDTH  = NUM_DATA * CTRL_PE_WIDTH + 
                                              SHIFTER_CTRL_WIDTH +
                                              OP_CODE_WIDTH;
    localparam integer CTRL_BUF_ADDR_WIDTH  = 12;
// ******************************************************************

// ******************************************************************
// Local wires and regs
// ******************************************************************
    wire [RD_IF_DATA_WIDTH-1:0]     rd_buf_data_out;
    wire [NUM_AXI-1:0]              rd_buf_full;
    wire [NUM_AXI-1:0]              rd_buf_empty;
    wire                            rd_buf_pop;

    wire [RD_IF_DATA_WIDTH-1:0]     wr_buf_data_out;
    wire [NUM_AXI-1:0]              wr_buf_full;
    wire [NUM_AXI-1:0]              wr_buf_empty;
    wire                            wr_buf_push;

    wire [CTRL_BUF_DATA_WIDTH-1:0]  ctrl_buf_data_in;
    wire [CTRL_BUF_DATA_WIDTH-1:0]  ctrl_buf_data_out;
    wire                            ctrl_buf_data_valid;
    wire [CTRL_BUF_ADDR_WIDTH-1:0]  ctrl_buf_addr;
    wire                            ctrl_buf_read_en;

    wire                            shifter_rd_en;
    wire [SHIFTER_CTRL_WIDTH -1:0]  shifter_ctrl_in;

    // WRITE from BRAM to DDR
    wire                            outBuf_empty;
    wire                            outBuf_pop;
    wire [RD_IF_DATA_WIDTH-1:0]     data_from_outBuf;
    wire [RD_BUF_ADDR_WIDTH:0]      outBuf_count;

    // READ from DDR to BRAM
    wire [RD_IF_DATA_WIDTH-1:0]     data_to_inBuf;
    wire [NUM_AXI-1:0]              inBuf_push;
    wire [NUM_AXI-1:0]              inBuf_full;
    wire [RD_BUF_ADDR_WIDTH * NUM_AXI:0]      inBuf_count;

    wire [RD_IF_DATA_WIDTH   -1:0]   data_out_shift;
    reg                              data_out_shift_valid;

    wire [NUM_AXI-1:0]               rx_done_inst;
// ******************************************************************

// ******************************************************************
// RD Fifo - Buffer for Read Interface
// ******************************************************************

assign inBuf_full = |rd_buf_full;
assign outBuf_empty = |wr_buf_empty; 

genvar gen;
generate
for (gen = 0; gen < NUM_AXI; gen = gen + 1)
begin : AXI_RD_BUF

    wire                         rd_push;
    wire [RD_BUF_DATA_WIDTH-1:0] rd_data_in;
    wire [RD_BUF_DATA_WIDTH-1:0] rd_data_out;
    wire                         rd_pop;
    wire                         rd_full;
    wire                         rd_empty;

    assign rd_data_in = data_to_inBuf[gen*RD_BUF_DATA_WIDTH+:RD_BUF_DATA_WIDTH];
    assign rd_push    = inBuf_push[gen];
    assign rd_pop     = rd_buf_pop;

    assign rd_buf_empty[gen] = rd_empty;
    assign rd_buf_full[gen] = rd_full;
    assign rd_buf_data_out[gen*RD_BUF_DATA_WIDTH+:RD_BUF_DATA_WIDTH] = rd_data_out;

    fifo #(
        .DATA_WIDTH             ( RD_BUF_DATA_WIDTH     ),
        .ADDR_WIDTH             ( RD_BUF_ADDR_WIDTH     )
    ) read_buffer (
        .clk                    ( ACLK                  ),
        .reset                  ( !ARESETN              ),
        .push                   ( rd_push               ),
        .pop                    ( rd_pop                ),
        .data_in                ( rd_data_in            ),
        .data_out               ( rd_data_out           ),
        .empty                  ( rd_empty              ),
        .full                   ( rd_full               ),
        .fifo_count             (                       )
    );

    wire                         wr_push;
    wire [RD_BUF_DATA_WIDTH-1:0] wr_data_in;
    wire [RD_BUF_DATA_WIDTH-1:0] wr_data_out;
    wire                         wr_pop;
    wire                         wr_full;
    wire                         wr_empty;

    assign wr_data_in = rdata[gen*RD_BUF_DATA_WIDTH+:RD_BUF_DATA_WIDTH];
    assign wr_push    = wr_buf_push;//DATA_INOUT_WB && DATA_IO_DIR;
    assign wr_pop     = outBuf_pop;

    assign wr_buf_empty[gen] = wr_empty;
    assign wr_buf_full[gen] = wr_full;
    assign data_from_outBuf[gen*RD_BUF_DATA_WIDTH+:RD_BUF_DATA_WIDTH] = wr_data_out;

    fifo_fwft #(
        .DATA_WIDTH             ( RD_BUF_DATA_WIDTH     ),
        .ADDR_WIDTH             ( RD_BUF_ADDR_WIDTH     )
    ) write_buffer (
        .clk                    ( ACLK                  ),
        .reset                  ( !ARESETN              ),
        .push                   ( wr_push               ),
        .pop                    ( wr_pop                ),
        .data_in                ( wr_data_in            ),
        .data_out               ( wr_data_out           ),
        .empty                  ( wr_empty              ),
        .full                   ( wr_full               ),
        .fifo_count             (                       )
    );

end
endgenerate

// ******************************************************************

// ******************************************************************
// Shifter
// ******************************************************************
    shifter
    #(
        .DATA_WIDTH             ( DATA_WIDTH            ),
        .NUM_DATA               ( NUM_DATA              )
    ) u_shifter (
        .ACLK                   ( ACLK                  ),
        .ARESETN                ( ARESETN               ),
        .RD_EN                  ( shifter_rd_en         ),
        .DATA_IN                ( rd_buf_data_out       ),
        .CTRL_IN                ( shifter_ctrl_in       ),
        .DATA_OUT               ( data_out_shift        )
    );

    always @(posedge ACLK)
    begin
        if (ARESETN && shifter_rd_en)
            data_out_shift_valid <= 1'b1;
        else
            data_out_shift_valid <= 1'b0;
    end

    // Write to PEs
    assign wdata = data_out_shift;

// ******************************************************************

// ******************************************************************
// CONTROLLER
// ******************************************************************
    read_if_control
    #(
        .CTRL_BUF_ADDR_WIDTH    ( CTRL_BUF_ADDR_WIDTH   ),
        .NUM_DATA               ( NUM_DATA              ),
        .NUM_PE                 ( NUM_PE                )
    ) u_if_controller (
        .ACLK                   ( ACLK                  ),
        .ARESETN                ( ARESETN               ),
        .RD_BUF_EMPTY           ( |rd_buf_empty         ),
        .RD_BUF_POP             ( rd_buf_pop            ),
        .WR_BUF_FULL            ( |wr_buf_full          ),
        .WR_BUF_PUSH            ( wr_buf_push           ),
        .SHIFTER_RD_EN          ( shifter_rd_en         ),
        .start                  ( start                 ),
        .compute_start          ( compute_start         ),
        .EOI                    ( EOI                   ),
        .EOC                    ( EOC                   ),
        .CTRL_PE                ( CTRL_PE               ),
        .SHIFT                  ( shifter_ctrl_in       ),
        .DATA_IO_DIR            ( DATA_IO_DIR           )
    );
// ******************************************************************

// ******************************************************************
// AXI-Master
// ******************************************************************
assign rx_done = |rx_done_inst;
for (gen=0; gen<NUM_AXI; gen=gen+1)
begin : AXI_MASTER
    localparam integer wstrb_width = RD_BUF_DATA_WIDTH/8;
    axi_master 
    #(
        .C_M_AXI_DATA_WIDTH     ( RD_BUF_DATA_WIDTH     ),
        .C_M_AXI_ADDR_WIDTH     ( C_M_AXI_ADDR_WIDTH    ),
        .FIFO_ADDR_WIDTH        ( RD_BUF_ADDR_WIDTH     ),
        .TX_SIZE_WIDTH          ( TX_SIZE_WIDTH         )
    )
    u_axim
    (
        .ACLK                       ( ACLK                      ),
        .ARESETN                    ( ARESETN                   ),

        .M_AXI_AWID                 ( S_AXI_AWID[6*gen+:6]      ),
        .M_AXI_AWADDR               ( S_AXI_AWADDR[32*gen+:32]  ),
        .M_AXI_AWLEN                ( S_AXI_AWLEN[4*gen+:4]     ),
        .M_AXI_AWSIZE               ( S_AXI_AWSIZE[3*gen+:3]    ),
        .M_AXI_AWBURST              ( S_AXI_AWBURST[2*gen+:2]   ),
        .M_AXI_AWLOCK               ( S_AXI_AWLOCK[2*gen+:2]    ),
        .M_AXI_AWCACHE              ( S_AXI_AWCACHE[4*gen+:4]   ),
        .M_AXI_AWPROT               ( S_AXI_AWPROT[3*gen+:3]    ),
        .M_AXI_AWQOS                ( S_AXI_AWQOS[4*gen+:4]     ),
        .M_AXI_AWUSER               ( S_AXI_AWUSER[gen+:1]      ),
        .M_AXI_AWVALID              ( S_AXI_AWVALID[gen+:1]     ),
        .M_AXI_AWREADY              ( S_AXI_AWREADY[gen+:1]     ),
        .M_AXI_WID                  ( S_AXI_WID[6*gen+:6]       ),
        .M_AXI_WDATA                ( S_AXI_WDATA[RD_BUF_DATA_WIDTH*gen+:RD_BUF_DATA_WIDTH]               ),
        .M_AXI_WSTRB                ( S_AXI_WSTRB[wstrb_width*gen+:wstrb_width]               ),
        .M_AXI_WLAST                ( S_AXI_WLAST[gen+:1]       ),
        .M_AXI_WUSER                ( S_AXI_WUSER[gen+:1]       ),
        .M_AXI_WVALID               ( S_AXI_WVALID[gen+:1]      ),
        .M_AXI_WREADY               ( S_AXI_WREADY[gen+:1]      ),
        .M_AXI_BID                  ( S_AXI_BID[6*gen+:6]       ),
        .M_AXI_BRESP                ( S_AXI_BRESP[2*gen+:2]     ),
        .M_AXI_BUSER                ( S_AXI_BUSER[gen+:1]       ),
        .M_AXI_BVALID               ( S_AXI_BVALID[gen+:1]      ),
        .M_AXI_BREADY               ( S_AXI_BREADY[gen+:1]      ),
        .M_AXI_ARID                 ( S_AXI_ARID[6*gen+:6]      ),
        .M_AXI_ARADDR               ( S_AXI_ARADDR[32*gen+:32]  ),
        .M_AXI_ARLEN                ( S_AXI_ARLEN[4*gen+:4]     ),
        .M_AXI_ARSIZE               ( S_AXI_ARSIZE[3*gen+:3]    ),
        .M_AXI_ARBURST              ( S_AXI_ARBURST[2*gen+:2]   ),
        .M_AXI_ARLOCK               ( S_AXI_ARLOCK[2*gen+:2]    ),
        .M_AXI_ARCACHE              ( S_AXI_ARCACHE[4*gen+:4]   ),
        .M_AXI_ARPROT               ( S_AXI_ARPROT[3*gen+:3]    ),
        .M_AXI_ARQOS                ( S_AXI_ARQOS[4*gen+:4]     ),
        .M_AXI_ARUSER               ( S_AXI_ARUSER[gen+:1]      ),
        .M_AXI_ARVALID              ( S_AXI_ARVALID[gen+:1]     ),
        .M_AXI_ARREADY              ( S_AXI_ARREADY[gen+:1]     ),
        .M_AXI_RID                  ( S_AXI_RID[6*gen+:6]       ),
        .M_AXI_RDATA                ( S_AXI_RDATA[RD_BUF_DATA_WIDTH*gen+:RD_BUF_DATA_WIDTH]               ),
        .M_AXI_RRESP                ( S_AXI_RRESP[2*gen+:2]     ),
        .M_AXI_RLAST                ( S_AXI_RLAST[gen+:1]       ),
        .M_AXI_RUSER                ( S_AXI_RUSER[gen+:1]       ),
        .M_AXI_RVALID               ( S_AXI_RVALID[gen+:1]      ),
        .M_AXI_RREADY               ( S_AXI_RREADY[gen+:1]      ),

        .outBuf_empty               ( outBuf_empty              ),
        .outBuf_pop                 ( outBuf_pop                ),
        .data_from_outBuf           ( data_from_outBuf[RD_BUF_DATA_WIDTH*gen+:RD_BUF_DATA_WIDTH]          ),

        .data_to_inBuf              ( data_to_inBuf[RD_BUF_DATA_WIDTH*gen+:RD_BUF_DATA_WIDTH]             ),
        .inBuf_push                 ( inBuf_push[gen+:1]        ),
        .inBuf_full                 ( inBuf_full[gen+:1]        ),

        .rx_req                     ( rx_req                    ),
        .rx_req_size                ( rx_req_size               ),
        .rx_done                    ( rx_done_inst[gen+:1]      )
    );
end
// ******************************************************************

endmodule
