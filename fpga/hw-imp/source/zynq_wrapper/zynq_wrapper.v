`timescale 1ns/1ps
module zynq_wrapper #(
    parameter integer READ_ADDR_BASE_0  = 32'h00000000,
    parameter integer WRITE_ADDR_BASE_0 = 32'h02000000,
    parameter integer TYPE              = "PU",
    parameter integer PERF_CNTR_WIDTH   = 10,
    parameter integer AXIM_DATA_WIDTH   = 64,
    parameter integer AXIM_ADDR_WIDTH   = 32,
    parameter integer AXIS_DATA_WIDTH   = 32,
    parameter integer AXIS_ADDR_WIDTH   = 32,
    parameter integer RD_BUF_ADDR_WIDTH = 8,
    parameter integer NUM_AXI           = 1,
    parameter integer DATA_WIDTH        = 16,
    parameter integer NUM_DATA          = AXIM_DATA_WIDTH*NUM_AXI/DATA_WIDTH,
    parameter integer NUM_PE            = 64,
    parameter integer VERBOSITY         = 2,
    parameter integer NAMESPACE_WIDTH   = 2,
    parameter integer TX_SIZE_WIDTH     = 7,
    parameter integer TEST_NUM_READS    = 5
// ******************************************************************
)
(
    inout wire [14:0]   DDR_addr,
    inout wire [2:0]    DDR_ba,
    inout wire          DDR_cas_n,
    inout wire          DDR_ck_n,
    inout wire          DDR_ck_p,
    inout wire          DDR_cke,
    inout wire          DDR_cs_n,
    inout wire [3:0]    DDR_dm,
    inout wire [31:0]   DDR_dq,
    inout wire [3:0]    DDR_dqs_n,
    inout wire [3:0]    DDR_dqs_p,
    inout wire          DDR_odt,
    inout wire          DDR_ras_n,
    inout wire          DDR_reset_n,
    inout wire          DDR_we_n,
    inout wire          FIXED_IO_ddr_vrn,
    inout wire          FIXED_IO_ddr_vrp,
    inout wire [53:0]   FIXED_IO_mio,
    inout wire          FIXED_IO_ps_clk,
    inout wire          FIXED_IO_ps_porb,
    inout wire          FIXED_IO_ps_srstb
    );

    wire                ACLK;
    wire                ARESETN;

    wire [31:0]         M_AXI_GP0_awaddr;
    wire [2:0]          M_AXI_GP0_awprot;
    wire                M_AXI_GP0_awready;
    wire                M_AXI_GP0_awvalid;
    wire [31:0]         M_AXI_GP0_wdata;
    wire [3:0]          M_AXI_GP0_wstrb;
    wire                M_AXI_GP0_wvalid;
    wire                M_AXI_GP0_wready;
    wire [1:0]          M_AXI_GP0_bresp;
    wire                M_AXI_GP0_bvalid;
    wire                M_AXI_GP0_bready;
    wire [31:0]         M_AXI_GP0_araddr;
    wire [2:0]          M_AXI_GP0_arprot;
    wire                M_AXI_GP0_arvalid;
    wire                M_AXI_GP0_arready;
    wire [31:0]         M_AXI_GP0_rdata;
    wire [1:0]          M_AXI_GP0_rresp;
    wire                M_AXI_GP0_rvalid;
    wire                M_AXI_GP0_rready;

    wire [31:0]         S_AXI_HP0_araddr;
    wire [1:0]          S_AXI_HP0_arburst;
    wire [3:0]          S_AXI_HP0_arcache;
    wire [5:0]          S_AXI_HP0_arid;
    wire [3:0]          S_AXI_HP0_arlen;
    wire [1:0]          S_AXI_HP0_arlock;
    wire [2:0]          S_AXI_HP0_arprot;
    wire [3:0]          S_AXI_HP0_arqos;
    wire                S_AXI_HP0_arready;
    wire [2:0]          S_AXI_HP0_arsize;
    wire                S_AXI_HP0_arvalid;
    wire [31:0]         S_AXI_HP0_awaddr;
    wire [1:0]          S_AXI_HP0_awburst;
    wire [3:0]          S_AXI_HP0_awcache;
    wire [5:0]          S_AXI_HP0_awid;
    wire [3:0]          S_AXI_HP0_awlen;
    wire [1:0]          S_AXI_HP0_awlock;
    wire [2:0]          S_AXI_HP0_awprot;
    wire [3:0]          S_AXI_HP0_awqos;
    wire                S_AXI_HP0_awready;
    wire [2:0]          S_AXI_HP0_awsize;
    wire                S_AXI_HP0_awvalid;
    wire [5:0]          S_AXI_HP0_bid;
    wire                S_AXI_HP0_bready;
    wire [1:0]          S_AXI_HP0_bresp;
    wire                S_AXI_HP0_bvalid;
    wire [63:0]         S_AXI_HP0_rdata;
    wire [5:0]          S_AXI_HP0_rid;
    wire                S_AXI_HP0_rlast;
    wire                S_AXI_HP0_rready;
    wire [1:0]          S_AXI_HP0_rresp;
    wire                S_AXI_HP0_rvalid;
    wire [63:0]         S_AXI_HP0_wdata;
    wire [5:0]          S_AXI_HP0_wid;
    wire                S_AXI_HP0_wlast;
    wire                S_AXI_HP0_wready;
    wire [7:0]          S_AXI_HP0_wstrb;
    wire                S_AXI_HP0_wvalid;

    localparam integer  C_S_AXI_DATA_WIDTH    = 32;
    localparam integer  C_S_AXI_ADDR_WIDTH    = 32;
    localparam integer  C_M_AXI_DATA_WIDTH    = 64;
    localparam integer  C_M_AXI_ADDR_WIDTH    = 32;

  zynq zynq_i (
    .DDR_addr               ( DDR_addr            ),
    .DDR_ba                 ( DDR_ba              ),
    .DDR_cas_n              ( DDR_cas_n           ),
    .DDR_ck_n               ( DDR_ck_n            ),
    .DDR_ck_p               ( DDR_ck_p            ),
    .DDR_cke                ( DDR_cke             ),
    .DDR_cs_n               ( DDR_cs_n            ),
    .DDR_dm                 ( DDR_dm              ),
    .DDR_dq                 ( DDR_dq              ),
    .DDR_dqs_n              ( DDR_dqs_n           ),
    .DDR_dqs_p              ( DDR_dqs_p           ),
    .DDR_odt                ( DDR_odt             ),
    .DDR_ras_n              ( DDR_ras_n           ),
    .DDR_reset_n            ( DDR_reset_n         ),
    .DDR_we_n               ( DDR_we_n            ),

    .FIXED_IO_ddr_vrn       ( FIXED_IO_ddr_vrn    ),
    .FIXED_IO_ddr_vrp       ( FIXED_IO_ddr_vrp    ),
    .FIXED_IO_mio           ( FIXED_IO_mio        ),
    .FIXED_IO_ps_clk        ( FIXED_IO_ps_clk     ),
    .FIXED_IO_ps_porb       ( FIXED_IO_ps_porb    ),
    .FIXED_IO_ps_srstb      ( FIXED_IO_ps_srstb   ),

    .FCLK_CLK0              ( ACLK           ),
    .FCLK_RESET0_N          ( ARESETN       ),

    .M_AXI_GP0_awaddr       ( M_AXI_GP0_awaddr    ),
    .M_AXI_GP0_awprot       ( M_AXI_GP0_awprot    ),
    .M_AXI_GP0_awready      ( M_AXI_GP0_awready   ),
    .M_AXI_GP0_awvalid      ( M_AXI_GP0_awvalid   ),
    .M_AXI_GP0_araddr       ( M_AXI_GP0_araddr    ),
    .M_AXI_GP0_arprot       ( M_AXI_GP0_arprot    ),
    .M_AXI_GP0_arready      ( M_AXI_GP0_arready   ),
    .M_AXI_GP0_arvalid      ( M_AXI_GP0_arvalid   ),
    .M_AXI_GP0_bready       ( M_AXI_GP0_bready    ),
    .M_AXI_GP0_bresp        ( M_AXI_GP0_bresp     ),
    .M_AXI_GP0_bvalid       ( M_AXI_GP0_bvalid    ),
    .M_AXI_GP0_rdata        ( M_AXI_GP0_rdata     ),
    .M_AXI_GP0_rready       ( M_AXI_GP0_rready    ),
    .M_AXI_GP0_rresp        ( M_AXI_GP0_rresp     ),
    .M_AXI_GP0_rvalid       ( M_AXI_GP0_rvalid    ),
    .M_AXI_GP0_wdata        ( M_AXI_GP0_wdata     ),
    .M_AXI_GP0_wready       ( M_AXI_GP0_wready    ),
    .M_AXI_GP0_wstrb        ( M_AXI_GP0_wstrb     ),
    .M_AXI_GP0_wvalid       ( M_AXI_GP0_wvalid    ),

    .S_AXI_HP0_araddr       ( S_AXI_HP0_araddr    ),
    .S_AXI_HP0_arburst      ( S_AXI_HP0_arburst   ),
    .S_AXI_HP0_arcache      ( S_AXI_HP0_arcache   ),
    .S_AXI_HP0_arid         ( S_AXI_HP0_arid      ),
    .S_AXI_HP0_arlen        ( S_AXI_HP0_arlen     ),
    .S_AXI_HP0_arlock       ( S_AXI_HP0_arlock    ),
    .S_AXI_HP0_arprot       ( S_AXI_HP0_arprot    ),
    .S_AXI_HP0_arqos        ( S_AXI_HP0_arqos     ),
    .S_AXI_HP0_arready      ( S_AXI_HP0_arready   ),
    .S_AXI_HP0_arsize       ( S_AXI_HP0_arsize    ),
    .S_AXI_HP0_arvalid      ( S_AXI_HP0_arvalid   ),
    .S_AXI_HP0_awaddr       ( S_AXI_HP0_awaddr    ),
    .S_AXI_HP0_awburst      ( S_AXI_HP0_awburst   ),
    .S_AXI_HP0_awcache      ( S_AXI_HP0_awcache   ),
    .S_AXI_HP0_awid         ( S_AXI_HP0_awid      ),
    .S_AXI_HP0_awlen        ( S_AXI_HP0_awlen     ),
    .S_AXI_HP0_awlock       ( S_AXI_HP0_awlock    ),
    .S_AXI_HP0_awprot       ( S_AXI_HP0_awprot    ),
    .S_AXI_HP0_awqos        ( S_AXI_HP0_awqos     ),
    .S_AXI_HP0_awready      ( S_AXI_HP0_awready   ),
    .S_AXI_HP0_awsize       ( S_AXI_HP0_awsize    ),
    .S_AXI_HP0_awvalid      ( S_AXI_HP0_awvalid   ),
    .S_AXI_HP0_bid          ( S_AXI_HP0_bid       ),
    .S_AXI_HP0_bready       ( S_AXI_HP0_bready    ),
    .S_AXI_HP0_bresp        ( S_AXI_HP0_bresp     ),
    .S_AXI_HP0_bvalid       ( S_AXI_HP0_bvalid    ),
    .S_AXI_HP0_rdata        ( S_AXI_HP0_rdata     ),
    .S_AXI_HP0_rid          ( S_AXI_HP0_rid       ),
    .S_AXI_HP0_rlast        ( S_AXI_HP0_rlast     ),
    .S_AXI_HP0_rready       ( S_AXI_HP0_rready    ),
    .S_AXI_HP0_rresp        ( S_AXI_HP0_rresp     ),
    .S_AXI_HP0_rvalid       ( S_AXI_HP0_rvalid    ),
    .S_AXI_HP0_wdata        ( S_AXI_HP0_wdata     ),
    .S_AXI_HP0_wid          ( S_AXI_HP0_wid       ),
    .S_AXI_HP0_wlast        ( S_AXI_HP0_wlast     ),
    .S_AXI_HP0_wready       ( S_AXI_HP0_wready    ),
    .S_AXI_HP0_wstrb        ( S_AXI_HP0_wstrb     ),
    .S_AXI_HP0_wvalid       ( S_AXI_HP0_wvalid    )
    );

// ******************************************************************
// Tabla
// ******************************************************************
tabla_wrapper #(

    .AXIS_DATA_WIDTH        ( AXIS_DATA_WIDTH       ),
    .AXIS_ADDR_WIDTH        ( AXIS_ADDR_WIDTH       ),
    .DATA_WIDTH             ( DATA_WIDTH            ),
    .AXIM_DATA_WIDTH        ( AXIM_DATA_WIDTH       ),
    .RD_BUF_ADDR_WIDTH      ( RD_BUF_ADDR_WIDTH     ),
    .NUM_PE                 ( NUM_PE                ),
    .NUM_AXI                ( NUM_AXI               ),
    .TX_SIZE_WIDTH          ( TX_SIZE_WIDTH         )

) u_tabla_wrapper (

    .ACLK                   ( ACLK                  ), //input
    .ARESETN                ( ARESETN               ), //input

    .S_AXI_ARADDR           ( S_AXI_HP0_araddr      ), //output
    .S_AXI_ARBURST          ( S_AXI_HP0_arburst     ), //output
    .S_AXI_ARCACHE          ( S_AXI_HP0_arcache     ), //output
    .S_AXI_ARID             ( S_AXI_HP0_arid        ), //output
    .S_AXI_ARLEN            ( S_AXI_HP0_arlen       ), //output
    .S_AXI_ARLOCK           ( S_AXI_HP0_arlock      ), //output
    .S_AXI_ARPROT           ( S_AXI_HP0_arprot      ), //output
    .S_AXI_ARQOS            ( S_AXI_HP0_arqos       ), //output
    .S_AXI_ARUSER           (                       ), //output
    .S_AXI_ARREADY          ( S_AXI_HP0_arready     ), //input
    .S_AXI_ARSIZE           ( S_AXI_HP0_arsize      ), //output
    .S_AXI_ARVALID          ( S_AXI_HP0_arvalid     ), //output
    .S_AXI_AWADDR           ( S_AXI_HP0_awaddr      ), //output
    .S_AXI_AWBURST          ( S_AXI_HP0_awburst     ), //output
    .S_AXI_AWCACHE          ( S_AXI_HP0_awcache     ), //output
    .S_AXI_AWID             ( S_AXI_HP0_awid        ), //output
    .S_AXI_AWLEN            ( S_AXI_HP0_awlen       ), //output
    .S_AXI_AWLOCK           ( S_AXI_HP0_awlock      ), //output
    .S_AXI_AWPROT           ( S_AXI_HP0_awprot      ), //output
    .S_AXI_AWQOS            ( S_AXI_HP0_awqos       ), //output
    .S_AXI_AWUSER           (                       ), //output
    .S_AXI_AWREADY          ( S_AXI_HP0_awready     ), //input
    .S_AXI_AWSIZE           ( S_AXI_HP0_awsize      ), //output
    .S_AXI_AWVALID          ( S_AXI_HP0_awvalid     ), //output
    .S_AXI_BID              ( S_AXI_HP0_bid         ), //input
    .S_AXI_BUSER            (                       ), //input
    .S_AXI_BREADY           ( S_AXI_HP0_bready      ), //output
    .S_AXI_BRESP            ( S_AXI_HP0_bresp       ), //input
    .S_AXI_BVALID           ( S_AXI_HP0_bvalid      ), //input
    .S_AXI_RDATA            ( S_AXI_HP0_rdata       ), //input
    .S_AXI_RID              ( S_AXI_HP0_rid         ), //input
    .S_AXI_RUSER            (                       ), //input
    .S_AXI_RLAST            ( S_AXI_HP0_rlast       ), //input
    .S_AXI_RREADY           ( S_AXI_HP0_rready      ), //output
    .S_AXI_RRESP            ( S_AXI_HP0_rresp       ), //input
    .S_AXI_RVALID           ( S_AXI_HP0_rvalid      ), //input
    .S_AXI_WDATA            ( S_AXI_HP0_wdata       ), //output
    .S_AXI_WID              ( S_AXI_HP0_wid         ), //output
    .S_AXI_WUSER            (                       ), //output
    .S_AXI_WLAST            ( S_AXI_HP0_wlast       ), //output
    .S_AXI_WREADY           ( S_AXI_HP0_wready      ), //input
    .S_AXI_WSTRB            ( S_AXI_HP0_wstrb       ), //output
    .S_AXI_WVALID           ( S_AXI_HP0_wvalid      ), //output

    .M_AXI_GP0_AWADDR       ( M_AXI_GP0_awaddr      ), //input 
    .M_AXI_GP0_AWPROT       ( M_AXI_GP0_awprot      ), //input 
    .M_AXI_GP0_AWREADY      ( M_AXI_GP0_awready     ), //output 
    .M_AXI_GP0_AWVALID      ( M_AXI_GP0_awvalid     ), //input
    .M_AXI_GP0_WDATA        ( M_AXI_GP0_wdata       ), //input 
    .M_AXI_GP0_WSTRB        ( M_AXI_GP0_wstrb       ), //input 
    .M_AXI_GP0_WVALID       ( M_AXI_GP0_wvalid      ), //input 
    .M_AXI_GP0_WREADY       ( M_AXI_GP0_wready      ), //output
    .M_AXI_GP0_BRESP        ( M_AXI_GP0_bresp       ), //output
    .M_AXI_GP0_BVALID       ( M_AXI_GP0_bvalid      ), //output
    .M_AXI_GP0_BREADY       ( M_AXI_GP0_bready      ), //input 
    .M_AXI_GP0_ARADDR       ( M_AXI_GP0_araddr      ), //input 
    .M_AXI_GP0_ARPROT       ( M_AXI_GP0_arprot      ), //input 
    .M_AXI_GP0_ARVALID      ( M_AXI_GP0_arvalid     ), //input 
    .M_AXI_GP0_ARREADY      ( M_AXI_GP0_arready     ), //output
    .M_AXI_GP0_RDATA        ( M_AXI_GP0_rdata       ), //output
    .M_AXI_GP0_RRESP        ( M_AXI_GP0_rresp       ), //output
    .M_AXI_GP0_RVALID       ( M_AXI_GP0_rvalid      ), //output
    .M_AXI_GP0_RREADY       ( M_AXI_GP0_rready      )  //input 

);
// ******************************************************************

endmodule
