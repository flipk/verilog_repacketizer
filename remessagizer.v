
// we should be exporting the lost msg stat

module remessagizer
  #( parameter MAX_MSG_SIZE = 200 )
  ( CLK, RESET,
    packet, packetValid,
    message, messageValid );

   input               CLK;
   input               RESET;
   input [7:0]         packet;
   input               packetValid;
   output [7:0]        message;
   output reg          messageValid;

   reg [4:0]           state = 0;

   reg [7:0]           outbuffer [0:MAX_MSG_SIZE-1];
   reg [7:0]           inpos = 0;
   reg [7:0]           outpos = 0;

   assign message = messageValid ? outbuffer[outpos] : 0;

   reg [7:0]           packetlen = 0;
   reg [7:0]           totallen = 0;
   reg [7:0]           totallen_saved = 0;
   reg [7:0]           piecelen = 0;
   reg [7:0]           pieceno = 0;
   reg [7:0]           expected_pieceno = 0;
   reg [7:0]           seqno = 0;
   reg [7:0]           expected_seqno = 0;

   reg [15:0]          lost_msg_stat = 0;

   assign bufferRemaining = MAX_MSG_SIZE - inpos;

   wire [7:0]          packetOut;
   wire                packetEmpty;
   reg                 packetOutEnable = 0;

   fifo
     #( .DATA_WIDTH(8), .FIFO_POWER(8) )
   dataFifo
     ( .reset(RESET), .clk_in(CLK), .clk_out(CLK),
       .data_in(packet), .enable_in(packetValid), .full_in(),
       .data_out(packetOut), .enable_out(packetOutEnable),
       .empty_out(packetEmpty) );

   reg                 sizeInEnable = 0;
   wire [7:0]          sizeOut;
   wire                sizeEmpty;
   reg                 sizeOutEnable = 0;

   reg                 packetValidDelay1 = 0;
   reg [7:0]           packetSizeCounter = 0;

   fifo
     #( .DATA_WIDTH(8), .FIFO_POWER(4) )
   sizeFifo
     ( .reset(RESET), .clk_in(CLK), .clk_out(CLK),
       .data_in(packetSizeCounter), .enable_in(sizeInEnable), .full_in(),
       .data_out(sizeOut), .enable_out(sizeOutEnable),
       .empty_out(sizeEmpty) );

   always @(posedge CLK) begin
      if (RESET) begin
         packetValidDelay1 <= 0;
         packetSizeCounter <= 0;
      end else begin
         packetValidDelay1 <= packetValid;
         if (packetValid) begin
            packetSizeCounter <= packetSizeCounter + 1;
         end
         if ({packetValid,packetValidDelay1} == 2'b10) begin
            // rising edge of packetValid
            packetSizeCounter <= 1;
         end
         if ({packetValid,packetValidDelay1} == 2'b01) begin
            // falling edge of packetValid
            sizeInEnable <= 1;
         end else begin
            sizeInEnable <= 0;
         end
      end
   end

   always @(posedge CLK) begin
      if (RESET) begin
         messageValid <= 0;
         inpos <= 0;
         outpos <= 0;
         packetOutEnable <= 0;
         sizeOutEnable <= 0;
      end else begin
         case (state)

           // idle
           0: begin
              if (sizeEmpty == 0) begin
                 sizeOutEnable <= 1;
                 state <= 1;
              end
           end

           // waiting for size
           1: begin
              packetlen <= sizeOut;
              sizeOutEnable <= 0;
              packetOutEnable <= 1;
              state <= 2;
           end

           // get dest
           2: begin
              // dont care about dest
              state <= 3;
              packetlen <= packetlen - 1;
           end

           // get src
           3: begin
              // dont care about src
              state <= 4;
              packetlen <= packetlen - 1;
           end

           // get len
           4: begin
              // dont care about len, really.
              state <= 5;
              packetlen <= packetlen - 1;
           end

           // get csum
           5: begin
              // dont care about csum, not validating it.
              state <= 6;
              packetlen <= packetlen - 1;
           end

           // now real data is arriving: piece header: totallen
           6: begin
              totallen_saved <= packetOut;
              state <= 7;
              packetlen <= packetlen - 1;
           end

           // piecelen.
           7: begin
              piecelen <= packetOut;
              state <= 8;
              packetlen <= packetlen - 1;
           end

           // pieceno
           8: begin
              pieceno <= packetOut;
              state <= 9;
              packetlen <= packetlen - 1;
           end

           // seqno
           9: begin
              // don't overwrite totallen if this is a nonzero
              // piece : we're using totallen to count down the
              // remainder of the message.
              if (pieceno == 0)
                totallen <= totallen_saved;
              seqno <= packetOut;
              packetlen <= packetlen - 1;
              if (packetOut == expected_seqno) begin
                 // good and normal.
                 state <= 11;
              end else begin
                 lost_msg_stat <= lost_msg_stat + 1;
                 if (pieceno == 0) begin
                    // okay to continue since it's first piece.
                    // but make sure inpos is reset.
                    inpos <= 0;
                    state <= 11;
                 end else begin
                    // we missed something, discard until a piece
                    // 0 is seen.
                    state <= 10;
                 end
              end
           end

           // discard piece
           10: begin
              piecelen <= piecelen - 1;
              packetlen <= packetlen - 1;
              if (piecelen == 1) begin
                 // done discarding piece, get next piece.
                 // and don't incr expected_pieceno, to force
                 // it to fail state 9's check
                 state <= 6;
              end
              if (packetlen == 1) begin
                 // actually, we ran out of packet, so
                 // go wait for the next packet instead.
                 state <= 0;
                 packetOutEnable <= 0;
              end
           end
           
           // piece contents
           11: begin
              packetlen <= packetlen - 1;
              totallen <= totallen - 1;
              piecelen <= piecelen - 1;
              outbuffer[inpos] <= packetOut;
              inpos <= inpos + 1;
              // xxx should check packetlen here,
              // in case a corrupt packet causes us to
              // run out of packet before we run out of piece.
              if (piecelen == 1) begin
                 if (totallen == 1) begin
                    // message complete: deliver
                    expected_pieceno <= 0;
                    packetOutEnable <= 0;
                    messageValid <= 1;
                    state <= 12;
                 end else begin
                    // incomplete message.
                    expected_pieceno <= expected_pieceno + 1;
                    expected_seqno <= expected_seqno + 1;
                    state <= 0;
                    packetOutEnable <= 0;
                 end
              end
           end

           // sending message to application
           12 : begin
              outpos <= outpos + 1;
              if (outpos == (inpos-1)) begin
                 messageValid <= 0;
                 outpos <= 0;
                 inpos <= 0;
                 if (packetlen == 0) begin
                    // this packet is complete.
                    expected_seqno <= expected_seqno + 1;
                    state <= 0;
                 end else begin
                    // this was just a piece in a packet,
                    // the packet is not done. go to the next piece.
                    packetOutEnable <= 1;
                    state <= 6;
                 end
              end
           end

         endcase // case (state)
      end
   end

endmodule // remessagizer
