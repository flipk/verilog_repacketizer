
module clkResetSource
  ( CLK, RESET );

   output reg CLK = 0;
   output reg RESET = 1;

   always begin
      #5;
      CLK = 1;
      #5;
      CLK = 0;
   end

   initial begin
      wait (CLK == 1);
      wait (CLK == 0);
      wait (CLK == 1);
      wait (CLK == 0);
      RESET = 0;
   end

endmodule // clkResetSource
