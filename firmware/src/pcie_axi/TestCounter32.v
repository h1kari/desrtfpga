// TestCounter32.v
// Copyright 2006 Pico Computing, Inc.
// 32b PicoBus version of the test counter, for use with the newer AXI-based firmware.

`include "PicoDefines.v"

module TestCounter32 (
    input               PicoClk,
    input               PicoRst,
    input      [31:0]   PicoAddr,
    input      [31:0]   PicoDataIn,
    output reg [31:0]   PicoDataOut,
    input               PicoRd,
    input               PicoWr
 );

reg [31:0] Counter;

wire CounterWrite     = (PicoAddr[31:20] == 12'h101) & PicoWr;		                             //request to write to device
wire CounterRead      = (PicoAddr[31:20] == 12'h101) & PicoRd;		                             //request to read from device
wire FreeRunningWrite = (PicoAddr[31:0] == 32'h100000A0) & PicoWr; //request to set FreeRunning register

// When this register is set, we'll let the counter count on every clock cycle. ('Free running' mode.)
reg FreeRunning;

always @(posedge PicoClk) begin
   if (PicoRst) begin
      Counter <= 32'h0;
   end
   else if (CounterRead | FreeRunning)
      Counter <= Counter + 1;
   else if (CounterWrite)
      Counter <= Counter + PicoDataIn[31:0];
end

always @(posedge PicoClk) begin
    if (PicoRst)
        FreeRunning <= 0;
    else if (FreeRunningWrite)
        FreeRunning <= PicoDataIn[0];
end

always @(posedge PicoClk) begin
    if  (CounterRead)   PicoDataOut <= Counter[31:0];
    else                PicoDataOut <= 32'h0;
end

endmodule

