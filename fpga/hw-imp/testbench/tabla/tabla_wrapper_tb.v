`timescale 1ns/1ps
`define SIMULATION 1
module tabla_wrapper_tb;
// ******************************************************************
// PARAMETERS
// ******************************************************************
    parameter integer PERF_CNTR_WIDTH   = 10;
    parameter integer AXIM_DATA_WIDTH   = 64;
    parameter integer AXIM_ADDR_WIDTH   = 32;
    parameter integer AXIS_DATA_WIDTH   = 8;
    parameter integer AXIS_ADDR_WIDTH   = 32;
    parameter integer RD_BUF_ADDR_WIDTH = 8;
    parameter integer NUM_AXI           = 1;
    parameter integer DATA_WIDTH        = 4;
    parameter integer NUM_DATA          = AXIM_DATA_WIDTH*NUM_AXI/DATA_WIDTH;
    parameter integer NUM_PE            = 64;
    parameter integer VERBOSITY         = 2;
    parameter integer NAMESPACE_WIDTH   = 2;
    parameter integer TX_SIZE_WIDTH     = 7;
    parameter integer TEST_NUM_READS    = 5;
    parameter integer TOTAL_MEM_INST    = 19;
// ******************************************************************

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
    localparam integer CTRL_BUF_DATA_WIDTH  = CTRL_PE_WIDTH + 
                                              SHIFTER_CTRL_WIDTH +
                                              OP_CODE_WIDTH;
    localparam integer PE_ID_WIDTH          = `C_LOG_2 (NUM_PE/NUM_DATA);
// ******************************************************************

// ******************************************************************
// Wires and Regs
// ******************************************************************
    reg                             ACLK;
    reg                             ARESETN;

    wire [32*NUM_AXI-1:0]           S_AXI_ARADDR;
    wire [2*NUM_AXI-1:0]            S_AXI_ARBURST;
    wire [4*NUM_AXI-1:0]            S_AXI_ARCACHE;
    wire [6*NUM_AXI-1:0]            S_AXI_ARID;
    wire [4*NUM_AXI-1:0]            S_AXI_ARLEN;
    wire [2*NUM_AXI-1:0]            S_AXI_ARLOCK;
    wire [3*NUM_AXI-1:0]            S_AXI_ARPROT;
    wire [4*NUM_AXI-1:0]            S_AXI_ARQOS;
    wire [1*NUM_AXI-1:0]            S_AXI_ARUSER;
    wire [NUM_AXI-1:0]              S_AXI_ARREADY;
    wire [3*NUM_AXI-1:0]            S_AXI_ARSIZE;
    wire [NUM_AXI-1:0]              S_AXI_ARVALID;
    wire [32*NUM_AXI-1:0]           S_AXI_AWADDR;
    wire [2*NUM_AXI-1:0]            S_AXI_AWBURST;
    wire [4*NUM_AXI-1:0]            S_AXI_AWCACHE;
    wire [6*NUM_AXI-1:0]            S_AXI_AWID;
    wire [4*NUM_AXI-1:0]            S_AXI_AWLEN;
    wire [2*NUM_AXI-1:0]            S_AXI_AWLOCK;
    wire [3*NUM_AXI-1:0]            S_AXI_AWPROT;
    wire [4*NUM_AXI-1:0]            S_AXI_AWQOS;
    wire [1*NUM_AXI-1:0]            S_AXI_AWUSER;
    wire [NUM_AXI-1:0]              S_AXI_AWREADY;
    wire [3*NUM_AXI-1:0]            S_AXI_AWSIZE;
    wire [NUM_AXI-1:0]              S_AXI_AWVALID;
    wire [6*NUM_AXI-1:0]            S_AXI_BID;
    wire [1*NUM_AXI-1:0]            S_AXI_BUSER;
    wire [NUM_AXI-1:0]              S_AXI_BREADY;
    wire [2*NUM_AXI-1:0]            S_AXI_BRESP;
    wire [NUM_AXI-1:0]              S_AXI_BVALID;
    wire [RD_IF_DATA_WIDTH-1:0]     S_AXI_RDATA;
    wire [6*NUM_AXI-1:0]            S_AXI_RID;
    wire [1*NUM_AXI-1:0]            S_AXI_RUSER;
    wire [NUM_AXI-1:0]              S_AXI_RLAST;
    wire [NUM_AXI-1:0]              S_AXI_RREADY;
    wire [2*NUM_AXI-1:0]            S_AXI_RRESP;
    wire [NUM_AXI-1:0]              S_AXI_RVALID;
    wire [RD_IF_DATA_WIDTH-1:0]     S_AXI_WDATA;
    wire [6*NUM_AXI-1:0]            S_AXI_WID;
    wire [1*NUM_AXI-1:0]            S_AXI_WUSER;
    wire [NUM_AXI-1:0]              S_AXI_WLAST;
    wire [NUM_AXI-1:0]              S_AXI_WREADY;
    wire [WSTRB_WIDTH-1:0]          S_AXI_WSTRB;
    wire [NUM_AXI-1:0]              S_AXI_WVALID;

    // NPU Design
    // WRITE from BRAM to DDR
    wire                            outBuf_empty;
    wire                            outBuf_pop;
    wire [RD_BUF_DATA_WIDTH-1:0]    data_from_outBuf;

    // READ from DDR to BRAM
    wire [RD_BUF_DATA_WIDTH-1:0]    data_to_inBuf;
    wire                            inBuf_push;
    wire                            inBuf_full;

    wire                            rx_req;
    wire [TX_SIZE_WIDTH-1:0]        rx_req_size;
    wire                            rx_done;

    wire [AXIS_ADDR_WIDTH-1:0]      M_AXI_GP0_AWADDR;
    wire [2:0]                      M_AXI_GP0_AWPROT;
    wire                            M_AXI_GP0_AWREADY;
    wire                            M_AXI_GP0_AWVALID;
    wire [AXIS_DATA_WIDTH-1:0]      M_AXI_GP0_WDATA;
    wire [AXIS_DATA_WIDTH/8-1:0]    M_AXI_GP0_WSTRB;
    wire                            M_AXI_GP0_WVALID;
    wire                            M_AXI_GP0_WREADY;
    wire [1:0]                      M_AXI_GP0_BRESP;
    wire                            M_AXI_GP0_BVALID;
    wire                            M_AXI_GP0_BREADY;
    wire [AXIS_ADDR_WIDTH-1:0]      M_AXI_GP0_ARADDR;
    wire [2:0]                      M_AXI_GP0_ARPROT;
    wire                            M_AXI_GP0_ARVALID;
    wire                            M_AXI_GP0_ARREADY;
    wire [AXIS_DATA_WIDTH-1:0]      M_AXI_GP0_RDATA;
    wire [1:0]                      M_AXI_GP0_RRESP;
    wire                            M_AXI_GP0_RVALID;
    wire                            M_AXI_GP0_RREADY;
// ******************************************************************

// ******************************************************************
// AXI Slave driver
// ******************************************************************
assign rx_req = tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.rx_req;
axi_slave_tb_driver
#(
    .PERF_CNTR_WIDTH            ( PERF_CNTR_WIDTH       ),
    .AXIS_DATA_WIDTH            ( AXIS_DATA_WIDTH       ),
    .AXIS_ADDR_WIDTH            ( AXIS_ADDR_WIDTH       ),
    .VERBOSITY                  ( VERBOSITY             )
) u_axis_driver (
    .tx_req                     ( rx_req                ), //input 
    .tx_done                    (                       ), //output 
    .rd_done                    (                       ), //output 
    .wr_done                    (                       ), //output 
    .processing_done            (                       ), //output 
    .total_cycles               (                       ), //output 
    .rd_cycles                  (                       ), //output 
    .pr_cycles                  (                       ), //output 
    .wr_cycles                  (                       ), //output 
    .S_AXI_ACLK                 ( ACLK                  ), //output 
    .S_AXI_ARESETN              ( ARESETN               ), //output 
    .S_AXI_AWADDR               ( M_AXI_GP0_AWADDR      ), //output 
    .S_AXI_AWPROT               ( M_AXI_GP0_AWPROT      ), //output 
    .S_AXI_AWVALID              ( M_AXI_GP0_AWVALID     ), //output 
    .S_AXI_AWREADY              ( M_AXI_GP0_AWREADY     ), //input 
    .S_AXI_WDATA                ( M_AXI_GP0_WDATA       ), //output 
    .S_AXI_WSTRB                ( M_AXI_GP0_WSTRB       ), //output 
    .S_AXI_WVALID               ( M_AXI_GP0_WVALID      ), //output 
    .S_AXI_WREADY               ( M_AXI_GP0_WREADY      ), //input 
    .S_AXI_BRESP                ( M_AXI_GP0_BRESP       ), //input 
    .S_AXI_BVALID               ( M_AXI_GP0_BVALID      ), //input 
    .S_AXI_BREADY               ( M_AXI_GP0_BREADY      ), //output 
    .S_AXI_ARADDR               ( M_AXI_GP0_ARADDR      ), //output 
    .S_AXI_ARPROT               ( M_AXI_GP0_ARPROT      ), //output 
    .S_AXI_ARVALID              ( M_AXI_GP0_ARVALID     ), //output 
    .S_AXI_ARREADY              ( M_AXI_GP0_ARREADY     ), //input 
    .S_AXI_RDATA                ( M_AXI_GP0_RDATA       ), //input 
    .S_AXI_RRESP                ( M_AXI_GP0_RRESP       ), //input 
    .S_AXI_RVALID               ( M_AXI_GP0_RVALID      ), //input 
    .S_AXI_RREADY               ( M_AXI_GP0_RREADY      )  //output 
);
// ******************************************************************

// ******************************************************************
// AXI Master driver
// ******************************************************************
axi_master_tb_driver
#(
    .C_M_AXI_DATA_WIDTH     ( RD_BUF_DATA_WIDTH     ),
    .TX_SIZE_WIDTH          ( TX_SIZE_WIDTH         ),
    .DATA_WIDTH             ( DATA_WIDTH            )
) u_axim_driver (
    .ACLK                   ( ACLK                  ),
    .ARESETN                ( ARESETN               ),
    .M_AXI_AWID             ( S_AXI_AWID            ),
    .M_AXI_AWADDR           ( S_AXI_AWADDR          ),
    .M_AXI_AWLEN            ( S_AXI_AWLEN           ),
    .M_AXI_AWSIZE           ( S_AXI_AWSIZE          ),
    .M_AXI_AWBURST          ( S_AXI_AWBURST         ),
    .M_AXI_AWLOCK           ( S_AXI_AWLOCK          ),
    .M_AXI_AWCACHE          ( S_AXI_AWCACHE         ),
    .M_AXI_AWPROT           ( S_AXI_AWPROT          ),
    .M_AXI_AWQOS            ( S_AXI_AWQOS           ),
    .M_AXI_AWUSER           ( S_AXI_AWUSER          ),
    .M_AXI_AWVALID          ( S_AXI_AWVALID         ),
    .M_AXI_AWREADY          ( S_AXI_AWREADY         ),
    .M_AXI_WID              ( S_AXI_WID             ),
    .M_AXI_WDATA            ( S_AXI_WDATA           ),
    .M_AXI_WSTRB            ( S_AXI_WSTRB           ),
    .M_AXI_WLAST            ( S_AXI_WLAST           ),
    .M_AXI_WUSER            ( S_AXI_WUSER           ),
    .M_AXI_WVALID           ( S_AXI_WVALID          ),
    .M_AXI_WREADY           ( S_AXI_WREADY          ),
    .M_AXI_BID              ( S_AXI_BID             ),
    .M_AXI_BRESP            ( S_AXI_BRESP           ),
    .M_AXI_BUSER            ( S_AXI_BUSER           ),
    .M_AXI_BVALID           ( S_AXI_BVALID          ),
    .M_AXI_BREADY           ( S_AXI_BREADY          ),
    .M_AXI_ARID             ( S_AXI_ARID            ),
    .M_AXI_ARADDR           ( S_AXI_ARADDR          ),
    .M_AXI_ARLEN            ( S_AXI_ARLEN           ),
    .M_AXI_ARSIZE           ( S_AXI_ARSIZE          ),
    .M_AXI_ARBURST          ( S_AXI_ARBURST         ),
    .M_AXI_ARLOCK           ( S_AXI_ARLOCK          ),
    .M_AXI_ARCACHE          ( S_AXI_ARCACHE         ),
    .M_AXI_ARPROT           ( S_AXI_ARPROT          ),
    .M_AXI_ARQOS            ( S_AXI_ARQOS           ),
    .M_AXI_ARUSER           ( S_AXI_ARUSER          ),
    .M_AXI_ARVALID          ( S_AXI_ARVALID         ),
    .M_AXI_ARREADY          ( S_AXI_ARREADY         ),
    .M_AXI_RID              ( S_AXI_RID             ),
    .M_AXI_RDATA            ( S_AXI_RDATA           ),
    .M_AXI_RRESP            ( S_AXI_RRESP           ),
    .M_AXI_RLAST            ( S_AXI_RLAST           ),
    .M_AXI_RUSER            ( S_AXI_RUSER           ),
    .M_AXI_RVALID           ( S_AXI_RVALID          ),
    .M_AXI_RREADY           ( S_AXI_RREADY          ),

    .outBuf_empty           ( outBuf_empty          ),
    .outBuf_pop             ( outBuf_pop            ),
    .data_from_outBuf       ( data_from_outBuf      ),
    .data_to_inBuf          ( data_to_inBuf         ),
    .inBuf_push             ( inBuf_push            ),
    .inBuf_full             ( inBuf_full            ),

    .rx_req                 (                       ),
    .rx_req_size            (                       ),
    .rx_done                (                       )
);
// ******************************************************************

// ******************************************************************
// Read Interface
// ******************************************************************
tabla_wrapper #(
    .AXIS_DATA_WIDTH        ( AXIS_DATA_WIDTH       ),
    .AXIS_ADDR_WIDTH        ( AXIS_ADDR_WIDTH       ),
    .DATA_WIDTH             ( DATA_WIDTH            ),
    .AXIM_DATA_WIDTH        ( AXIM_DATA_WIDTH       ),
    .RD_BUF_ADDR_WIDTH      ( RD_BUF_ADDR_WIDTH     ),
    .NUM_DATA               ( NUM_DATA              ),
    .NUM_PE                 ( NUM_PE                ),
    .NUM_AXI                ( NUM_AXI               ),
    .TX_SIZE_WIDTH          ( TX_SIZE_WIDTH         )
) u_tabla_wrapper (
    .ACLK                   ( ACLK                  ), //input
    .ARESETN                ( ARESETN               ), //input

    .S_AXI_ARADDR           ( S_AXI_ARADDR          ), //output
    .S_AXI_ARBURST          ( S_AXI_ARBURST         ), //output
    .S_AXI_ARCACHE          ( S_AXI_ARCACHE         ), //output
    .S_AXI_ARID             ( S_AXI_ARID            ), //output
    .S_AXI_ARLEN            ( S_AXI_ARLEN           ), //output
    .S_AXI_ARLOCK           ( S_AXI_ARLOCK          ), //output
    .S_AXI_ARPROT           ( S_AXI_ARPROT          ), //output
    .S_AXI_ARQOS            ( S_AXI_ARQOS           ), //output
    .S_AXI_ARUSER           ( S_AXI_ARUSER          ), //output
    .S_AXI_ARREADY          ( S_AXI_ARREADY         ), //input
    .S_AXI_ARSIZE           ( S_AXI_ARSIZE          ), //output
    .S_AXI_ARVALID          ( S_AXI_ARVALID         ), //output
    .S_AXI_AWADDR           ( S_AXI_AWADDR          ), //output
    .S_AXI_AWBURST          ( S_AXI_AWBURST         ), //output
    .S_AXI_AWCACHE          ( S_AXI_AWCACHE         ), //output
    .S_AXI_AWID             ( S_AXI_AWID            ), //output
    .S_AXI_AWLEN            ( S_AXI_AWLEN           ), //output
    .S_AXI_AWLOCK           ( S_AXI_AWLOCK          ), //output
    .S_AXI_AWPROT           ( S_AXI_AWPROT          ), //output
    .S_AXI_AWQOS            ( S_AXI_AWQOS           ), //output
    .S_AXI_AWUSER           ( S_AXI_AWUSER          ), //output
    .S_AXI_AWREADY          ( S_AXI_AWREADY         ), //input
    .S_AXI_AWSIZE           ( S_AXI_AWSIZE          ), //output
    .S_AXI_AWVALID          ( S_AXI_AWVALID         ), //output
    .S_AXI_BID              ( S_AXI_BID             ), //input
    .S_AXI_BUSER            ( S_AXI_BUSER           ), //input
    .S_AXI_BREADY           ( S_AXI_BREADY          ), //output
    .S_AXI_BRESP            ( S_AXI_BRESP           ), //input
    .S_AXI_BVALID           ( S_AXI_BVALID          ), //input
    .S_AXI_RDATA            ( S_AXI_RDATA           ), //input
    .S_AXI_RID              ( S_AXI_RID             ), //input
    .S_AXI_RUSER            ( S_AXI_RUSER           ), //input
    .S_AXI_RLAST            ( S_AXI_RLAST           ), //input
    .S_AXI_RREADY           ( S_AXI_RREADY          ), //output
    .S_AXI_RRESP            ( S_AXI_RRESP           ), //input
    .S_AXI_RVALID           ( S_AXI_RVALID          ), //input
    .S_AXI_WDATA            ( S_AXI_WDATA           ), //output
    .S_AXI_WID              ( S_AXI_WID             ), //output
    .S_AXI_WUSER            ( S_AXI_WUSER           ), //output
    .S_AXI_WLAST            ( S_AXI_WLAST           ), //output
    .S_AXI_WREADY           ( S_AXI_WREADY          ), //input
    .S_AXI_WSTRB            ( S_AXI_WSTRB           ), //output
    .S_AXI_WVALID           ( S_AXI_WVALID          ), //output

    .M_AXI_GP0_AWADDR       ( M_AXI_GP0_AWADDR      ), //input 
    .M_AXI_GP0_AWPROT       ( M_AXI_GP0_AWPROT      ), //input 
    .M_AXI_GP0_AWREADY      ( M_AXI_GP0_AWREADY     ), //output 
    .M_AXI_GP0_AWVALID      ( M_AXI_GP0_AWVALID     ), //input
    .M_AXI_GP0_WDATA        ( M_AXI_GP0_WDATA       ), //input 
    .M_AXI_GP0_WSTRB        ( M_AXI_GP0_WSTRB       ), //input 
    .M_AXI_GP0_WVALID       ( M_AXI_GP0_WVALID      ), //input 
    .M_AXI_GP0_WREADY       ( M_AXI_GP0_WREADY      ), //output
    .M_AXI_GP0_BRESP        ( M_AXI_GP0_BRESP       ), //output
    .M_AXI_GP0_BVALID       ( M_AXI_GP0_BVALID      ), //output
    .M_AXI_GP0_BREADY       ( M_AXI_GP0_BREADY      ), //input 
    .M_AXI_GP0_ARADDR       ( M_AXI_GP0_ARADDR      ), //input 
    .M_AXI_GP0_ARPROT       ( M_AXI_GP0_ARPROT      ), //input 
    .M_AXI_GP0_ARVALID      ( M_AXI_GP0_ARVALID     ), //input 
    .M_AXI_GP0_ARREADY      ( M_AXI_GP0_ARREADY     ), //output
    .M_AXI_GP0_RDATA        ( M_AXI_GP0_RDATA       ), //output
    .M_AXI_GP0_RRESP        ( M_AXI_GP0_RRESP       ), //output
    .M_AXI_GP0_RVALID       ( M_AXI_GP0_RVALID      ), //output
    .M_AXI_GP0_RREADY       ( M_AXI_GP0_RREADY      )  //input 
);
// ******************************************************************

// ******************************************************************
// TestBench
// ******************************************************************
initial
begin
    $dumpfile("hw-imp/bin/waveform/tabla_wrapper.vcd");
    $dumpvars(0,tabla_wrapper_tb);
end

initial 
begin
    $display ("CTRL_BUF_WIDTH = %d", CTRL_BUF_DATA_WIDTH);
    $display("%c[1;34m",27);
    $display("***************************************");
    $display ("Testing Tabla");
    $display("***************************************");
    $display("%c[0m",27);

    // Mem instructions
    //rand_instruction;
    //add_instruction;
    print_mem_instructions;
    ACLK = 0;
    ARESETN = 1;
    @(negedge ACLK);
    ARESETN = 0;
    @(negedge ACLK);
    ARESETN = 1;

    u_axis_driver.start_tabla;
    //u_axis_driver.test_main;

    wait(u_tabla_wrapper.EOC);

    repeat (5) begin
        @(negedge ACLK);
    end

    u_axis_driver.test_pass;
end

initial begin
    #1000
    u_axis_driver.fail_flag = 1;
end

always #1 ACLK = ~ACLK;

always @(posedge ACLK)
begin
    if (tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.u_if_controller.ctrl_buf_read_en)
    begin
        $display ("Read Mem Instruction : ");
        @(negedge ACLK);
        print_mem_instruction_detail (tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.u_if_controller.ctrl_buf_data_out);
    end
end

// ******************************************************************

//--------------------------------------------------------------------------------------
task automatic rand_instruction;
    reg  [CTRL_PE_WIDTH-1:0]        ctrl_pe;
    reg  [OP_CODE_WIDTH-1:0]        ctrl_op_code;
    reg  [SHIFTER_CTRL_WIDTH-1:0]   ctrl_shifter;
    reg  [CTRL_BUF_DATA_WIDTH-1:0]  ctrl_buf_data_in;
    integer n;
    begin
        for (n=0; n<1000; n=n+1)
        begin
            if (n > 0)
            begin
                ctrl_pe       = {$random, $random};
                ctrl_op_code  = {$random, $random};
                ctrl_shifter  = {$random, $random};
            end
            else begin
                ctrl_pe       = {$random, $random};
                ctrl_op_code  = 0;
                ctrl_shifter  = {$random, $random};
            end
            ctrl_buf_data_in = {ctrl_pe, ctrl_op_code, ctrl_shifter};
            tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.u_if_controller.u_ctrl_buf.mem[n] = ctrl_buf_data_in;
        end
    end
endtask
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
task automatic add_instruction;
    reg  [CTRL_PE_WIDTH-1:0]        ctrl_pe;
    reg  [OP_CODE_WIDTH-1:0]        ctrl_op_code;
    reg  [SHIFTER_CTRL_WIDTH-1:0]   ctrl_shifter;
    reg  [CTRL_BUF_DATA_WIDTH-1:0]  ctrl_buf_data_in;

    reg  [PE_ID_WIDTH-1:0]          pe_id;
    reg                             valid;
    reg                             valid_prev;
    reg  [NAMESPACE_WIDTH-1:0]      namespace_id;

    integer n;
    begin

        valid_prev = 0;

    $display ("PE ID Width = %d", PE_ID_WIDTH);
    $display ("CTRL_PE_WIDTH = %d", NUM_DATA*(PE_ID_WIDTH+1)+NAMESPACE_WIDTH);

        for (n=0; n<100; n=n+1)
        begin
            pe_id = 0;
            valid = 0;
            namespace_id = 1;
            ctrl_shifter  = 0;
            //if (n%(TEST_NUM_READS+2)>0 && n%(TEST_NUM_READS+2) < TEST_NUM_READS+1) valid = 1;
            case (n%(TEST_NUM_READS+2)) 
                0: begin
                    ctrl_op_code  = 0;
                    valid = 0;
                end
                TEST_NUM_READS: begin
                    ctrl_op_code  = 1;
                    valid = 0;
                end
                TEST_NUM_READS+1: begin
                    ctrl_op_code  = 2;
                    valid = 0;
                end
                default: begin
                    ctrl_op_code  = 1;
                    valid = 1;
                end
            endcase
            ctrl_pe = {{NUM_DATA{pe_id, valid_prev}}, namespace_id};
            valid_prev = valid;
            ctrl_buf_data_in = {ctrl_pe, ctrl_op_code, ctrl_shifter};
            tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.u_if_controller.u_ctrl_buf.mem[n] = ctrl_buf_data_in;
            //$display ("CTRL_PE = %h", ctrl_buf_data_in);
        end
    end
endtask
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
task automatic print_partition;
    begin
        $display("*************************************************");
    end
endtask
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
task automatic print_mem_instructions;

    reg  [CTRL_BUF_DATA_WIDTH-1:0]  ctrl_buf_data;

    integer n;
    begin

        print_partition;
        $display ("Mem Instructions are as follows");

        for (n=0; n<TOTAL_MEM_INST; n=n+1)
        begin
            ctrl_buf_data = tabla_wrapper_tb.u_tabla_wrapper.u_mem_if.u_if_controller.u_ctrl_buf.mem[n];
            if (ctrl_buf_data[0] !== 1'bx) 
            begin
                $display ("Index = %h, Data = %h", n, ctrl_buf_data);
                print_mem_instruction_detail(ctrl_buf_data);
                $display;
            end
        end
        $display ("Mem Instructions END");
        print_partition;
    end
endtask
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
task automatic print_mem_instruction_detail;

    input [CTRL_BUF_DATA_WIDTH-1:0] ctrl_buf_data;

    reg   [CTRL_PE_WIDTH-1:0]       ctrl_pe;
    reg   [OP_CODE_WIDTH-1:0]       ctrl_op_code;
    reg   [SHIFTER_CTRL_WIDTH-1:0]  ctrl_shifter;

    reg   [PE_ID_WIDTH-1:0]         pe_id;
    reg                             valid;
    reg                             valid_prev;
    reg   [NAMESPACE_WIDTH-1:0]     namespace_id;

    integer n;

    begin
        {ctrl_pe, ctrl_op_code, ctrl_shifter} = ctrl_buf_data;
        //$display ("PE_CTRL:");
        //for (n=NUM_DATA-1; n>-1; n=n-1)
        //begin
        //    //$write ("PE_CTRL = %h, %h, %h\n", ctrl_pe, ctrl_op_code, ctrl_shifter);
        //    {pe_id, valid} = ctrl_pe[(n)*(PE_ID_WIDTH+1)+NAMESPACE_WIDTH+:PE_ID_WIDTH+1];
        //    $display ("PE_INDEX = %d, PE_ID = %h, Valid = %b", NUM_DATA-n, pe_id, valid);
        //    //$display("CTRL_PE = %h", ctrl_pe);
        //end
        //$display;
        print_op_code(ctrl_op_code);
        $display ("Shift amount = %d", ctrl_shifter);
        $display;
    end
endtask
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
task automatic print_op_code;

    input  [OP_CODE_WIDTH-1:0]        ctrl_op_code;
    begin
        case (ctrl_op_code)
            0: begin
                $display ("Read Instruction");
            end
            1: begin
                $display ("Shift Instruction");
            end
            2: begin
                $display ("Wait Instruction");
            end
            3: begin
                $display ("Write Instruction");
            end
        endcase
    end
endtask
//--------------------------------------------------------------------------------------


endmodule
