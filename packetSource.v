
module packetSource
  ( CLK, RESET,
    sourceData, sourceDataValid,
    sourceDataSize, sourceDataSizeValid );

   input              CLK;
   input              RESET;
   output reg [7:0]   sourceData = 8'b0;
   output reg         sourceDataValid = 0;
   output reg [7:0]   sourceDataSize = 8'b0;
   output reg         sourceDataSizeValid = 0;
   
   reg [7:0]    messages [0:199];

   // grep '..' packetSource.hex  | wc -l
   localparam [7:0] buffersize = 77;

   initial $readmemh("packetSource.hex", messages, 0, 199);

   reg [7:0]    position = 0;
   reg [7:0]    bodycount = 0;

   wire [7:0]   currentReadValue = messages[position];

   reg [4:0]    state = 0;


   always @(posedge CLK) begin
      if (RESET) begin
         state <= 0;
         position <= 0;
         bodycount <= 0;
         sourceData <= 0;
         sourceDataValid <= 0;
         sourceDataSize <= 0;
         sourceDataSizeValid <= 0;
      end else begin
        
         case (state)

           // starting point
           0: begin
              sourceDataSizeValid <= 0;
              bodycount <= currentReadValue;
              sourceDataSize <= currentReadValue;
              position <= position + 1;
              state <= 1;
           end

           // have packet length in bodycount
           1: begin
              sourceData <= currentReadValue;
              sourceDataValid <= 1;
              position <= position + 1;
              if (bodycount == 1) begin
                 state <= 2;
              end else begin
                 bodycount <= bodycount - 1;
              end
           end

           // bodycount is now 0
           2: begin
              sourceData <= 8'b0;
              sourceDataValid <= 0;
              sourceDataSizeValid <= 1;
              if (position == buffersize)
                state <= 3;
              else
                state <= 0;
           end

           // idle
           3: begin
              sourceData <= 8'b0;
              sourceDataValid <= 0;
              sourceDataSize <= 0;
              sourceDataSizeValid <= 0;
           end

         endcase

      end
   end

endmodule // packetSource
