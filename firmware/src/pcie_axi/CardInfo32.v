// CardInfo32.v
// Copyright 2007, Pico Computing, Inc.

`timescale 1ns / 1ps

`include "PicoDefines.v"

module CardInfo32 (
   input                PicoClk,
   input                PicoRst,
   input      [31:0]    PicoAddr,
   input      [31:0]    PicoDataIn,
   output reg [31:0]    PicoDataOut,
   input                PicoRd,
   input                PicoWr,
   
   input      [7:0]     UserPBWidth
);

// the PICO_CAP_PICOBUS32 flag used to be static, but when we build this
//   module as part of a netlist, we don't know what the value will be,
//   so we need to take out the static def and substitute the PicoBus32 signal
wire [31:0] CapWithStaticPB32 = {`IMAGE_CAPABILITIES};
wire [31:0] Cap = CapWithStaticPB32[31:0];

// system width hardcoded for now.
// really, it's kinda silly to report the system picobus width on the bus itself. chicken/egg!
wire [7:0] SysPBWidth = 32;

// we want the card model number accessible from the system picobus
wire    [15:0]  ModelNumber = `PICO_MODEL_NUM;

//high order 12 bits can be a unique value for this bit file, next 4 are status bits, last 16 are 'magic num'
//The 4 status bits are 0, 0, DcmsLocks, and flash_status (always zero in this code).
wire [31:0] Status = {`BITFILE_SIGNATURE, 2'b0, 1'b0, 1'b0, `PICO_MAGIC_NUM};

wire [31:0] Version;
assign Version[31:24] = `VERSION_MAJOR;
assign Version[23:16] = `VERSION_MINOR;
assign Version[15:8]  = `VERSION_RELEASE;
assign Version[7:0]   = `VERSION_COUNTER;

always @(posedge PicoClk) begin
    if (PicoRd & (PicoAddr[31:0] == `STATUS_ADDRESS))
        PicoDataOut[31:0] <= Status[31:0];
    else if (PicoRd & (PicoAddr[31:0] == `IMAGE_CAPABILITIES_ADDRESS))
        PicoDataOut[31:0] <= Cap[31:0];
    else if (PicoRd & (PicoAddr[31:0] == `VERSION_ADDRESS))    
        PicoDataOut[31:0] <= Version[31:0];
    else if (PicoRd & (PicoAddr[31:0] == `PICOBUS_INFO_ADDRESS))
        PicoDataOut[31:0] <= {16'h0, UserPBWidth[7:0], SysPBWidth[7:0]};
    else if (PicoRd & (PicoAddr[31:0] == `CARD_MODEL_ADDRESS))
        PicoDataOut[31:0] <= {16'h0, ModelNumber};
    else
        PicoDataOut[31:0] <= 32'h0;
end

endmodule

