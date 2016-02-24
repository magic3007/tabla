`timescale 1ns/1ps
//-----------------------------------------------------------
//Simple Log2 calculation function
//-----------------------------------------------------------
`define C_LOG_2(n) (\
(n) <= (1<<0) ? 0 : (n) <= (1<<1) ? 1 :\
(n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
(n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
(n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
(n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
(n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
(n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
(n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
(n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
(n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
(n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
(n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
(n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
(n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
(n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
(n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)
//-----------------------------------------------------------

module axi_master #
  (
// ******************************************************************
// Parameters
// ******************************************************************
   parameter         C_M_AXI_PROTOCOL                   = "AXI3",
   parameter integer C_M_AXI_THREAD_ID_WIDTH            = 6,
   parameter integer C_M_AXI_ADDR_WIDTH                 = 32,
   parameter integer C_M_AXI_DATA_WIDTH                 = 64,
   parameter integer C_M_AXI_AWUSER_WIDTH               = 1,
   parameter integer C_M_AXI_ARUSER_WIDTH               = 1,
   parameter integer C_M_AXI_WUSER_WIDTH                = 1,
   parameter integer C_M_AXI_RUSER_WIDTH                = 1,
   parameter integer C_M_AXI_BUSER_WIDTH                = 1,
   
   /* Disabling these parameters will remove any throttling.
    The resulting ERROR flag will not be useful */ 
   parameter integer C_M_AXI_SUPPORTS_WRITE             = 1,
   parameter integer C_M_AXI_SUPPORTS_READ              = 1,
   
   /* Max count of written but not yet read bursts.
    If the interconnect/slave is able to accept enough
    addresses and the read channels are stalled, the
    master will issue this many commands ahead of 
    write responses */
   parameter integer C_INTERCONNECT_M_AXI_WRITE_ISSUING = 16,
             
   // Base address of targeted slave
   //Changing read and write addresses
   parameter         C_M_AXI_READ_TARGET        = 32'hFFFF0000,
   parameter         C_M_AXI_WRITE_TARGET       = 32'hFFFF8000,
   
   
   // Number of address bits to test before wrapping   
   parameter integer C_OFFSET_WIDTH             = 11,
   
   /* Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
    Non-2^n lengths will eventually cause bursts across 4K
    address boundaries.*/
   parameter integer C_M_AXI_RD_BURST_LEN          = 16,
   parameter integer C_M_AXI_WR_BURST_LEN          = 4,
   
   parameter         RX_SIZE                    = C_M_AXI_DATA_WIDTH*C_M_AXI_RD_BURST_LEN*16,
   parameter         FIFO_ADDR_WIDTH            = 8
   )
   (
// ******************************************************************
// IO
// ******************************************************************
    // System Signals
    input  wire                                 ACLK,
    input  wire                                 ARESETN,
    
    // Master Interface Write Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   M_AXI_AWID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]        M_AXI_AWADDR,
    output wire [4-1:0]                         M_AXI_AWLEN,
    output wire [3-1:0]                         M_AXI_AWSIZE,
    output wire [2-1:0]                         M_AXI_AWBURST,
    output wire [2-1:0]                         M_AXI_AWLOCK,
    output wire [4-1:0]                         M_AXI_AWCACHE,
    output wire [3-1:0]                         M_AXI_AWPROT,
    output wire [4-1:0]                         M_AXI_AWQOS,
    output wire [C_M_AXI_AWUSER_WIDTH-1:0]      M_AXI_AWUSER,
    output wire                                 M_AXI_AWVALID,
    input  wire                                 M_AXI_AWREADY,
    
    // Master Interface Write Data
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   M_AXI_WID,
    output wire [C_M_AXI_DATA_WIDTH-1:0]        M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0]      M_AXI_WSTRB,
    output wire                                 M_AXI_WLAST,
    output wire [C_M_AXI_WUSER_WIDTH-1:0]       M_AXI_WUSER,
    output wire                                 M_AXI_WVALID,
    input  wire                                 M_AXI_WREADY,
    
    // Master Interface Write Response
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   M_AXI_BID,
    input  wire [2-1:0]                         M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0]       M_AXI_BUSER,
    input  wire                                 M_AXI_BVALID,
    output wire                                 M_AXI_BREADY,
    
    // Master Interface Read Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   M_AXI_ARID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]        M_AXI_ARADDR,
    output wire [4-1:0]                         M_AXI_ARLEN,
    output wire [3-1:0]                         M_AXI_ARSIZE,
    output wire [2-1:0]                         M_AXI_ARBURST,
    output wire [2-1:0]                         M_AXI_ARLOCK,
    output wire [4-1:0]                         M_AXI_ARCACHE,
    output wire [3-1:0]                         M_AXI_ARPROT,
    // AXI3 output wire [4-1:0]          M_AXI_ARREGION,
    output wire [4-1:0]                         M_AXI_ARQOS,
    output wire [C_M_AXI_ARUSER_WIDTH-1:0]      M_AXI_ARUSER,
    output wire                                 M_AXI_ARVALID,
    input  wire                                 M_AXI_ARREADY,
    
    // Master Interface Read Data 
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   M_AXI_RID,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]        M_AXI_RDATA,
    input  wire [2-1:0]                         M_AXI_RRESP,
    input  wire                                 M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0]       M_AXI_RUSER,
    input  wire                                 M_AXI_RVALID,
    output wire                                 M_AXI_RREADY,

    // NPU Design
    // WRITE from BRAM to DDR
    input  wire                                 outBuf_empty,
    output wire                                 outBuf_pop,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]        data_from_outBuf,
    input  wire [FIFO_ADDR_WIDTH:0]             outBuf_count,

    // READ from DDR to BRAM
    output wire [C_M_AXI_DATA_WIDTH-1:0]        data_to_inBuf,
    output wire                                 inBuf_push,
    input  wire                                 inBuf_full,
    input  wire [FIFO_ADDR_WIDTH:0]             inBuf_count,

    // TXN REQ
    input  wire                                 tx_req,
    output reg                                  tx_done
    ); 

// ******************************************************************
// Internal variables - Regs, Wires and LocalParams
// ******************************************************************
   // NPU Interface
    wire                                        rnext;

   // A fancy terminal counter, using extra bits to reduce decode logic
   localparam integer                  C_WLEN_COUNT_WIDTH = `C_LOG_2(C_M_AXI_WR_BURST_LEN-2)+2;
   reg [C_WLEN_COUNT_WIDTH-1:0]                 wlen_count; 
   
   // Local address counters
   reg [C_OFFSET_WIDTH-1:0]                     araddr_offset = 'b0;
   reg [C_OFFSET_WIDTH-1:0]                     awaddr_offset = 'b0;

   // Example throttling counters
   reg [`C_LOG_2(C_INTERCONNECT_M_AXI_WRITE_ISSUING)-1:0]      unread_writes;
   reg [`C_LOG_2(C_INTERCONNECT_M_AXI_WRITE_ISSUING)-1:0]      aw_issue_count;
   reg [`C_LOG_2(C_INTERCONNECT_M_AXI_WRITE_ISSUING)-1:0]      w_issue_count;

   // Example user application signals
   reg                                          read_mismatch;
   reg                                          error_reg;
   reg [C_M_AXI_DATA_WIDTH :0]                  wdata; //optimized for example design
  
   // Interface response error flags
   wire                                         write_resp_error;
   wire                                         read_resp_error; 

   // AXI4 temp signals
   reg                                          awvalid;
   wire                                         wlast;
   reg                                          wvalid;
   reg                                          bready;
   reg                                          arvalid; 
   reg                                          rready;   
   
   wire                                         wnext;
   wire                                         arnext;
   



   always @ (posedge ACLK)
   begin
       if (ARESETN==0 || ar_req)
           tx_done <= 0;
       else if (wlast)
           tx_done <= 1'b1;
   end
   
/////////////////
//I/O Connections
/////////////////
//////////////////// 
//Write Address (AW)
////////////////////

// Single threaded   
assign M_AXI_AWID = 'b0;   

// The AXI address is a concatenation of the target base address + active offset range
assign M_AXI_AWADDR = {C_M_AXI_WRITE_TARGET[C_M_AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH],awaddr_offset};

//Burst LENgth is number of transaction beats, minus 1
assign M_AXI_AWLEN = C_M_AXI_WR_BURST_LEN - 1;

// Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
assign M_AXI_AWSIZE = `C_LOG_2(C_M_AXI_DATA_WIDTH/8);

// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_AWBURST = 2'b01;
assign M_AXI_AWLOCK = 2'b00;

// Not Allocated, Modifiable and Bufferable
assign M_AXI_AWCACHE = 4'b0011;
assign M_AXI_AWPROT = 3'h0;
assign M_AXI_AWQOS = 4'h0;

//Set User[0] to 1 to allow Zynq coherent ACP transactions   
assign M_AXI_AWUSER = 'b1;
assign M_AXI_AWVALID = awvalid;

///////////////
//Write Data(W)
///////////////
//assign M_AXI_WDATA = wdata;

//All bursts are complete and aligned in this example
assign M_AXI_WID = 'b0;
assign M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH/8){1'b1}};
assign M_AXI_WLAST = wlast;
assign M_AXI_WUSER = 'b0;
assign M_AXI_WVALID = wvalid;

////////////////////
//Write Response (B)
////////////////////
assign M_AXI_BREADY = bready;

///////////////////   
//Read Address (AR)
///////////////////
assign M_AXI_ARID = 'b0;   
assign M_AXI_ARADDR = {C_M_AXI_READ_TARGET[C_M_AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH],araddr_offset};

//Burst LENgth is number of transaction beats, minus 1
assign M_AXI_ARLEN = C_M_AXI_RD_BURST_LEN - 1;

// Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
assign M_AXI_ARSIZE = `C_LOG_2(C_M_AXI_DATA_WIDTH/8);

// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_ARBURST = 2'b01;
assign M_AXI_ARLOCK = 2'b00;
   
// Not Allocated, Modifiable and Bufferable
//assign M_AXI_ARCACHE = 4'b0011;
assign M_AXI_ARCACHE = 4'b1111;
assign M_AXI_ARPROT = 3'h0;
assign M_AXI_ARQOS = 4'h0;

//Set User[0] to 1 to allow Zynq coherent ACP transactions     
assign M_AXI_ARUSER = 'b1;
assign M_AXI_ARVALID = arvalid;

////////////////////////////
//Read and Read Response (R)
////////////////////////////
assign M_AXI_RREADY = rready;

////////////////////
//Example design I/O
////////////////////
//assign ERROR = error_reg;
//
////////////////////////////////////////////////
//Reset logic, workaround for AXI_BRAM CR#582705
////////////////////////////////////////////////  
reg aresetn_r  = 1'b0;
reg aresetn_r1 = 1'b0;
reg aresetn_r2 = 1'b0;
reg aresetn_r3 = 1'b0;
reg aresetn_r4 = 1'b0;

always @(posedge ACLK) 
begin
   aresetn_r    <= ARESETN;
   aresetn_r1   <= aresetn_r;
   aresetn_r2   <= aresetn_r1;
   aresetn_r3   <= aresetn_r2;
   aresetn_r4   <= aresetn_r3;
end

///////////////////////
//Write Address Channel
///////////////////////
/*
 The purpose of the write address channel is to request the address and 
 command information for the entire transaction.  It is a single beat
 of data for each burst.
 
 The AXI4 Write address channel in this example will continue to initiate
 write commands as fast as it is allowed by the slave/interconnect.
 
 The address will be incremented on each accepted address transaction,
 until wrapping on the C_OFFSET_WIDTH boundary with awaddr_offset.
 */
always @(posedge ACLK)
  begin
     if (aresetn_r4 == 0 )
       //if (ARESETN == 0)
       awvalid <= 1'b0; 
     else if (C_M_AXI_SUPPORTS_WRITE && !awvalid && (outBuf_count >= C_M_AXI_WR_BURST_LEN-1))
     //else if (C_M_AXI_SUPPORTS_WRITE && !awvalid && !outBuf_empty)
     begin
       awvalid <= 1'b1;
     end
     else if (M_AXI_AWREADY && awvalid)
     begin
       awvalid <= 1'b0; 
     end
     else
       awvalid <= awvalid;    
  end
   
// Next address after AWREADY indicates previous address acceptance
always @(posedge ACLK)
begin
     if (ARESETN == 0)
       awaddr_offset <= 'b0;
     else if (M_AXI_AWREADY && awvalid)
       awaddr_offset <= awaddr_offset + C_M_AXI_WR_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
     else
       awaddr_offset <= awaddr_offset;
end
   
////////////////////
//Write Data Channel
////////////////////
/* 
 The write data will continually try to push write data across the interface.

 The amount of data accepted will depend on the AXI slave and the AXI
 Interconnect settings, such as if there are FIFOs enabled in interconnect. 
 
 Note that there is no explicit timing relationship to the write address channel.
 The write channel has its own throttling flag, separate from the AW channel.
  
 Synchronization between the channels must be determined by the user.
 
 The simpliest but lowest performance would be to only issue one address write
 and write data burst at a time.
  
 In this example they are kept in sync by using the same address increment
 and burst sizes. Then the AW and W channels have their transactions measured
 with threshold counters as part of the user logic, to make sure neither 
 channel gets too far ahead of each other. 
 */

// Forward movement occurs when the channel is valid and ready
assign wnext = M_AXI_WREADY & wvalid;

// WVALID logic, similar to the AWVALID always block above
always @(posedge ACLK)
  begin
     if (ARESETN == 0)
       wvalid <= 1'b0; 
     else if (C_M_AXI_SUPPORTS_WRITE && wvalid==0 && (outBuf_count >= C_M_AXI_WR_BURST_LEN-1))
       wvalid <= 1'b1;
     else if (wnext && wlast)
       wvalid <= 1'b0; 
     else
       wvalid <= wvalid;    
  end

//WLAST generation on the MSB of a counter underflow
assign wlast = wlen_count[C_WLEN_COUNT_WIDTH-1];

/* Burst length counter. Uses extra counter register bit to indicate terminal
 count to reduce decode logic */    
always @(posedge ACLK)
begin
     if (ARESETN == 0 || (wnext && wlen_count[C_WLEN_COUNT_WIDTH-1]))
        wlen_count <= C_M_AXI_WR_BURST_LEN - 2;
     else if (wnext)
        wlen_count <= wlen_count - 1;
     else
        wlen_count <= wlen_count;
end

////////////////////////////
//Write Response (B) Channel
////////////////////////////
/* 
 The write response channel provides feedback that the write has committed
 to memory. BREADY will occur when all of the data and the write address
 has arrived and been accepted by the slave.
 
 The write issuance (number of outstanding write addresses) is started by 
 the Address Write transfer, and is completed by a BREADY/BRESP.
 
 While negating BREADY will eventually throttle the AWREADY signal, 
 it is best not to throttle the whole data channel this way.
 
 The BRESP bit [1] is used indicate any errors from the interconnect or
 slave for the entire write burst. This example will capture the error 
 into the ERROR output. 
 */

//Always accept write responses
always @(posedge ACLK)
  begin
     if (ARESETN == 0)
       bready <= 1'b0;
      else
       bready <= C_M_AXI_SUPPORTS_WRITE;
 end

//Flag any write response errors   
//assign write_resp_error = bready & M_AXI_BVALID & M_AXI_BRESP[1];

//-----------------------------------------------//
//  READ - BEGIN
//-----------------------------------------------//
/////////////////////////
//Generate RX Burst Count
/////////////////////////

reg tx_req_d;
wire ar_done;
always @ (posedge ACLK)
begin
    if (ARESETN)
        tx_req_d <= tx_req;
    else
        tx_req_d <= 0;
end

reg ar_req;
always @ (posedge ACLK)
begin
    if (ARESETN == 0) begin
        ar_req <= 0;
    end else begin
        if (!tx_req_d && tx_req)
            ar_req <= 1'b1;
        else if (ar_done)
            ar_req <= 1'b0;
    end
end

//////////////////
//Generate TX Done
//////////////////
/*
* Generate TX Done signal based on arvalid
*
* TODO
* Generate TX Done when all bursts are finished
* need a counter to count number of bursts
*/
assign rnext    = ARESETN & M_AXI_RVALID  & M_AXI_RREADY;
assign arnext   = ARESETN & M_AXI_ARVALID & M_AXI_ARREADY;
assign ar_done  = arnext;

//////////////////////   
//Read Address Channel
//////////////////////
always @(posedge ACLK) 
begin
    if (ARESETN == 0)
    begin
        arvalid <= 1'b0;
        araddr_offset  <= 'b0;
    end
    else if (arvalid && M_AXI_ARREADY)
    begin
        arvalid <= 1'b0;
        araddr_offset <= araddr_offset + C_M_AXI_RD_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
    end
    else if (C_M_AXI_SUPPORTS_READ && ar_req)
    begin
        arvalid <= 1'b1;
        araddr_offset <= araddr_offset;
    end
    else
    begin
        arvalid <= arvalid;
        araddr_offset <= araddr_offset;
    end
end

//////////////////////////////////   
//Read Data (and Response) Channel
//////////////////////////////////
always @(posedge ACLK)
begin
    if (ARESETN == 0)
        rready <= 1'b0;
    else
        rready <= C_M_AXI_SUPPORTS_READ && !inBuf_full;
end

//-----------------------------------------------//
//  READ - END
//-----------------------------------------------//

//-----------------------------------------------//
//  FIFO CONTROL
//-----------------------------------------------//
//always @ (posedge ACLK)
//begin
    //if (!ARESETN)
        //outBuf_pop <= 0;
    //else
        //outBuf_pop <= wnext;
//end
assign outBuf_pop    = wnext;
assign inBuf_push    = rnext;
assign data_to_inBuf = M_AXI_RDATA;
assign M_AXI_WDATA   = data_from_outBuf;
//-----------------------------------------------//
//  FIFO CONTROL - END
//-----------------------------------------------//

endmodule
