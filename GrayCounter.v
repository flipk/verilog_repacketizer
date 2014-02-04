//==========================================
// Function : Code Gray counter.
// Coder    : Alex Claros F.
// Date     : 15/May/2005.
//=======================================

`timescale 1ns/1ps

module GrayCounter
  #(parameter   COUNTER_WIDTH = 4)
   (output reg  [COUNTER_WIDTH-1:0]    GrayCount_out,
    output reg  [COUNTER_WIDTH-1:0]    GrayCountPlusOne_out,
    input wire Enable_in,
    input wire Clear_in,
    input wire Clk);

   reg [COUNTER_WIDTH-1:0] BinaryCount;
   wire [COUNTER_WIDTH-1:0] BinaryCountPlusOne;

   assign BinaryCountPlusOne = (BinaryCount + 1);

   always @ (posedge Clk)
     if (Clear_in) begin
        BinaryCount   <= {COUNTER_WIDTH{1'b 0}} + 1;
        GrayCount_out <= {COUNTER_WIDTH{1'b 0}};
        GrayCountPlusOne_out <= {COUNTER_WIDTH{1'b 0}} + 1;
     end else if (Enable_in) begin
        BinaryCount   <= BinaryCountPlusOne;
        GrayCount_out <= {BinaryCount[COUNTER_WIDTH-1],
                          BinaryCount[COUNTER_WIDTH-2:0] ^
                          BinaryCount[COUNTER_WIDTH-1:1]};
        GrayCountPlusOne_out <= {BinaryCountPlusOne[COUNTER_WIDTH-1],
                                 BinaryCountPlusOne[COUNTER_WIDTH-2:0] ^
                                 BinaryCountPlusOne[COUNTER_WIDTH-1:1]};
     end
   
endmodule
