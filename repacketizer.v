
module repacketizer
  #( parameter MAXPACKET = 16,
     parameter DEST_PORT_NUMBER = 8'hdd,
     parameter SRC_PORT_NUMBER = 8'hee,
     parameter NAGLE_COUNTER = 16'hf0 )
  ( CLK, RESET,
    dataFifoData, dataFifoDataEnable,
    sizeFifoData, sizeFifoDataEnable, sizeFifoDataEmpty,
    packetout, packetoutValid );

   input             CLK;
   input             RESET;
   input [7:0]       dataFifoData;
   output reg        dataFifoDataEnable = 0;
   input [7:0]       sizeFifoData;
   output reg        sizeFifoDataEnable = 0;
   input             sizeFifoDataEmpty;

   output reg [7:0]  packetout;
   output reg        packetoutValid;

   reg [4:0]         state = 0;
   reg [7:0]         packetremaining = 0;
   wire [7:0]        remainingSpace;

   // packet layout (4 byte header, 16 bytes of payload):
   //    dest src len csum   <piece bytes>
   //  layout:
   //    totlen thislen piece# seq#

   reg [7:0]         pkthdr_dest;
   reg [7:0]         pkthdr_src;
   reg [7:0]         pkthdr_len;
   reg [7:0]         pkthdr_csum;
   reg [7:0]         packetbuild [0:MAXPACKET-1];
   reg [4:0]         inpos = 0;
   reg [4:0]         outpos = 0;
   reg [7:0]         totlen = 0;
   reg [7:0]         thislen = 0;
   reg [4:0]         pieceno = 0;
   reg [7:0]         seqno = 0;
   reg [16:0]        nagle = 0;

   assign remainingSpace = MAXPACKET - inpos;

   always @(posedge CLK) begin
      if (RESET) begin
         dataFifoDataEnable <= 0;
         sizeFifoDataEnable <= 0;
         state <= 0;
         packetremaining <= 0;
         thislen <= 0;
         pkthdr_dest <= DEST_PORT_NUMBER;
         pkthdr_src  <= SRC_PORT_NUMBER;
         pkthdr_csum <= 8'b0;
         seqno <= 8'b0;
         packetout <= 8'b0;
         packetoutValid <= 0;
         nagle <= 0;
      end else begin
         case (state)

           // size fifo is empty
           0: begin
              if (sizeFifoDataEmpty == 0) begin
                 sizeFifoDataEnable <= 1;
                 state <= 1;
              end
              if (inpos != 0) begin
                 nagle <= nagle + 1;
                 if (nagle == NAGLE_COUNTER) begin
                    // might as well send it.
                    packetoutValid <= 1;
                    // start with dest
                    packetout <= pkthdr_dest;
                    state <= 8;
                 end
              end
           end

           // fetching size from size fifo
           1: begin
              sizeFifoDataEnable <= 0;
              packetremaining <= sizeFifoData;
              totlen <= sizeFifoData;
              pieceno <= 0;
              state <= 2;
              nagle <= 0;
           end

           // check size and start generating a header.
           2: begin
              if (remainingSpace <= (packetremaining + 4)) begin
                 thislen <= remainingSpace - 4;
              end else begin
                 thislen <= packetremaining;
              end
              // send totlen
              packetbuild[inpos] <= totlen;
              pkthdr_csum <= pkthdr_csum + totlen;
              inpos <= inpos + 1;
              state <= 3;
           end

           // enqueue thislen
           3: begin
              packetbuild[inpos] <= thislen;
              pkthdr_csum <= pkthdr_csum + thislen;
              inpos <= inpos + 1;
              state <= 4;
           end

           // enqueue pieceno
           4: begin
              packetbuild[inpos] <= pieceno;
              pkthdr_csum <= pkthdr_csum + pieceno;
              pieceno <= pieceno + 1;
              inpos <= inpos + 1;
              state <= 5;
           end

           // enqueue seqno
           5: begin
              packetbuild[inpos] <= seqno;
              pkthdr_csum <= pkthdr_csum + seqno;
              inpos <= inpos + 1;
              state <= 6;
              dataFifoDataEnable <= 1;
           end

           // now start adding data
           6: begin
              packetbuild[inpos] <= dataFifoData;
              pkthdr_csum <= pkthdr_csum + dataFifoData;
              inpos <= inpos + 1;
              thislen <= thislen - 1;
              packetremaining <= packetremaining - 1;
              if (thislen == 1) begin
                 dataFifoDataEnable <= 0;
                 state <= 7;
              end
           end

           // piece is added, now what?
           7: begin
              if (remainingSpace <= 4) begin
                 // might as well send it.
                 packetoutValid <= 1;
                 // start with dest
                 packetout <= pkthdr_dest;
                 state <= 8;
              end else begin
                 // collect some more before sending
                 state <= 0;
              end
           end

           // send src
           8: begin
              packetout <= pkthdr_src;
              state <= 9;
           end

           // send pkt len
           9: begin
              packetout <= inpos;
              state <= 10;
           end

           // send csum
           10: begin
              packetout <= pkthdr_csum;
              pkthdr_csum <= 0;
              outpos <= 0;
              state <= 11;
           end

           // send packet
           11: begin
              packetout <= packetbuild[outpos];
              outpos <= outpos + 1;
              if (outpos == inpos) begin
                 packetoutValid <= 0;
                 inpos <= 0;
                 seqno <= seqno + 1;
                 if (packetremaining == 0) begin
                    state <= 0;
                 end else begin
                    state <= 2;
                 end
              end
           end

         endcase
      end
   end

endmodule // repacketizer
