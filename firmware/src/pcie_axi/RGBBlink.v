//-----------------------------------------------------------------------------
//
// Module name: RGBBlink
// Author: Jeremy Chritz
//
// Copyright 2015 Micron Technology, Inc.
//-----------------------------------------------------------------------------
// This modules changes the color of a RGB LED by 
// incrementing a counter and assigning different 
// bits to the different colors.
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module RGBBlink # (
    parameter LED_NUM       = 1
) (
    input                   extra_clk,
    output [LED_NUM-1:0 ]   led_r,
    output [LED_NUM-1:0 ]   led_g,
    output [LED_NUM-1:0 ]   led_b
);

genvar i;
reg [31:0] cnt;
always @(posedge extra_clk) cnt <= cnt + 1'b1;

generate
    for (i=0; i< LED_NUM; i=i+1) begin: LED_GEN
        assign led_r[i] = cnt[29];
        assign led_g[i] = cnt[30];
        assign led_b[i] = cnt[31];
    end
endgenerate

endmodule
