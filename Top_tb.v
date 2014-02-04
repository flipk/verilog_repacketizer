`timescale 1ns / 1ps

module Top_tb;

   wire CLK;
   wire RESET;

   clkResetSource clkResetSource
     ( .CLK(CLK), .RESET(RESET) );

   wire [7:0] sourceData;
   wire       sourceDataValid;
   wire [7:0] sourceDataSize;
   wire       sourceDataSizeValid;

   packetSource  packetSource
     ( .CLK(CLK), .RESET(RESET),
       .sourceData     (sourceData),
       .sourceDataValid(sourceDataValid),
       .sourceDataSize     (sourceDataSize),
       .sourceDataSizeValid(sourceDataSizeValid) );

   wire [7:0] dataFifoData;
   wire       dataFifoDataEnable;

   fifo
     #( .DATA_WIDTH(8),
        .FIFO_POWER(8) )
   sourceDataFifo
     ( .reset(RESET),
       .clk_in(CLK), .data_in(sourceData),
       .enable_in(sourceDataValid),
       .clk_out(CLK), .data_out(dataFifoData),
       .enable_out(dataFifoDataEnable), .empty_out() );

   wire [7:0] sizeFifoData;
   wire       sizeFifoDataEnable;
   wire       sizeFifoDataEmpty;

   fifo
     #( .DATA_WIDTH(8),
        .FIFO_POWER(4) )
   sourceDataSizeFifo
     ( .reset(RESET),
       .clk_in(CLK), .data_in(sourceDataSize),
       .enable_in(sourceDataSizeValid),
       .clk_out(CLK), .data_out(sizeFifoData),
       .enable_out(sizeFifoDataEnable), .empty_out(sizeFifoDataEmpty) );

   wire [7:0] packetout;
   wire       packetoutValid;

   repacketizer repacketizer
     ( .CLK(CLK), .RESET(RESET),
       .dataFifoData(dataFifoData),
       .dataFifoDataEnable(dataFifoDataEnable),
       .sizeFifoData(sizeFifoData),
       .sizeFifoDataEnable(sizeFifoDataEnable),
       .sizeFifoDataEmpty(sizeFifoDataEmpty),
       .packetout(packetout),
       .packetoutValid(packetoutValid) );

endmodule // Top_tb
