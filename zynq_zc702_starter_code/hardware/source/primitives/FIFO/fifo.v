`timescale 1ns/1ps
module fifo (
	clk,
	reset,

	push,
	data_in,

	pop,
	data_out,

	empty,
	full,
    fifo_count
);    
 
// ******************************************************************
// Parameters
// ******************************************************************
    parameter   DATA_WIDTH          = 64;
    parameter   INIT                = "init.mif";
    parameter   ADDR_WIDTH          = 8;
    parameter   RAM_DEPTH           = (1 << ADDR_WIDTH);
    parameter   INITIALIZE_FIFO     = "no";
    parameter   TYPE                = "BLOCK";
// ******************************************************************
// Port Declarations
// ******************************************************************
    input                           clk;
    input                           reset;
    input                           push;                   //Push
    input                           pop;                    //Pop
    input   [DATA_WIDTH-1:0]        data_in;                //Data In
    output  [DATA_WIDTH-1:0]        data_out;               //Data Out
    output                          empty;                  //Empty Out
    output                          full;                   //Full Out
    output  [ADDR_WIDTH:0]          fifo_count;             //Counter
// ******************************************************************
// Internal variables
// ******************************************************************
    reg                             empty;                  //Status_Empty
    reg                             full;                   //Status_Full
    reg     [ADDR_WIDTH-1:0]        wr_pointer;             //Write Pointer
    reg     [ADDR_WIDTH-1:0]        rd_pointer;             //Read Pointer
    reg     [ADDR_WIDTH:0]          fifo_count;             //Counter
    reg     [DATA_WIDTH-1:0]        data_out;               //Output
	(* ram_style = TYPE *)
    reg     [DATA_WIDTH-1:0]        mem[0:RAM_DEPTH-1];     //Memory
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
    initial begin
      if (INITIALIZE_FIFO == "yes") begin
        $readmemh(INIT, mem, 0, RAM_DEPTH-1);
      end
    end

    always @ (fifo_count)
    begin : FIFO_STATUS
    	empty   = (fifo_count == 0);
    	full    = (fifo_count == RAM_DEPTH);
    end
    
    always @ (posedge clk)
    begin : FIFO_COUNTER
    	if (reset)
    		fifo_count <= 0;
    	
    	else if (push && !pop && !full)
    		fifo_count <= fifo_count + 1;
    		
    	else if (pop && !push && !empty)
    		fifo_count <= fifo_count - 1;
    end
    
    always @ (posedge clk)
    begin : WRITE_PTR
    	if (reset) begin
       		wr_pointer <= 0;
    	end 
    	else if (push && !full) begin
    		wr_pointer <= wr_pointer + 1;
    	end
    end
    
    always @ (posedge clk)
    begin : READ_PTR
    	if (reset) begin
    		rd_pointer <= 0;
    	end
    	else if (pop && !empty) begin
    		rd_pointer <= rd_pointer + 1;
    	end
    end
    
    always @ (posedge clk)
    begin : WRITE
        if (push & !full) begin
    		mem[wr_pointer] <= data_in;
        end
    end
    
    always @ (posedge clk)
    begin : READ
        if (reset) begin
	    	data_out <= 0;
        end
        if (pop && !empty) begin
    		data_out <= mem[rd_pointer];
        end
        else if (empty) begin
    		data_out <= data_out;
        end
    end

endmodule
