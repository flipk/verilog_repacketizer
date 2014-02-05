`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company:        
//
// Create Date:    
// Design Name:    
// Module Name:    
// Project Name:   
// Target Device:  
// 
// Description: 
//
////////////////////////////////////////////////////////////////////////////////
module fifo
  #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_POWER = 4,
    parameter FIFO_SIZE = (1 << FIFO_POWER)
    )
   ( reset,
     clk_in, data_in, enable_in, full_in,
     clk_out, data_out, enable_out, empty_out
     );

   input                  reset;
   input                  clk_in;
   input [DATA_WIDTH-1:0] data_in;
   input                  enable_in;
   output reg             full_in;
   input                  clk_out;
   output [DATA_WIDTH-1:0] data_out;
   input                   enable_out;
   output reg              empty_out;

   reg [DATA_WIDTH-1:0]    buffer[0:FIFO_SIZE-1];
   wire [FIFO_POWER-1:0]   in_pointer;
   wire [FIFO_POWER-1:0]   in_pointer_plus_one;
   wire                    in_pointer_count_enable;
   wire [FIFO_POWER-1:0]   out_pointer;
   wire [FIFO_POWER-1:0]   out_pointer_plus_one;
   wire                    out_pointer_count_enable;
   
   GrayCounter
     #( .COUNTER_WIDTH(FIFO_POWER) )
   in_pointer_counter
     ( .GrayCount_out(in_pointer),
       .GrayCountPlusOne_out(in_pointer_plus_one),
       .Enable_in(in_pointer_count_enable),
       .Clear_in(reset),
       .Clk(clk_in) );

   GrayCounter
     #( .COUNTER_WIDTH(FIFO_POWER) )
   out_pointer_counter
     ( .GrayCount_out(out_pointer),
       .GrayCountPlusOne_out(out_pointer_plus_one),
       .Enable_in(out_pointer_count_enable),
       .Clear_in(reset),
       .Clk(clk_out) );

   assign in_pointer_count_enable = enable_in;

   always @(posedge clk_in) begin
      if (reset) begin
         full_in <= 0;
      end else begin
         full_in <= ( in_pointer_plus_one == out_pointer );
         if (enable_in) begin
            buffer[in_pointer] <= data_in;
         end else begin
         end
      end // else: !if(reset)
   end // always @ (posedge clk_in)

   assign data_out = empty_out ? 0 : buffer[out_pointer];
   assign out_pointer_count_enable = enable_out;

   always @(posedge clk_out) begin
      if (reset) begin
         empty_out <= 1;
      end else begin
         if (enable_out) begin
            empty_out <= (in_pointer == out_pointer_plus_one);
         end else begin
            empty_out <= (in_pointer == out_pointer);
         end
      end // else: !if(reset)
   end // always @ (posedge clk_out)

endmodule
