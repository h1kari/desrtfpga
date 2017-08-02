`timescale 1ns / 1ps
`include "PicoDefines.v"

module descrack_stream_region #(
    parameter REGION = 0
) (
    input clk,
    input rst,
    input des_clk,
    input clken,
    input fsl_clk,
    input fsl_rst_i,
    input [31:0] fsl_data_i,
    input fsl_valid_i,
    output fsl_rst_o,
    output [31:0] fsl_data_o,
    output fsl_valid_o,
    output [255:0] DEBUG
);

wire [`CORES:0] fsl_rst;
wire [31:0] fsl_data [`CORES:0];
wire [`CORES:0] fsl_valid;
wire [255:0] dbg [`CORES-1:0];

assign fsl_rst[0] = fsl_rst_i;
assign fsl_data[0] = fsl_data_i;
assign fsl_valid[0] = fsl_valid_i;

genvar i;
generate for (i = 0; i < `CORES; i = i + 1) begin : des_stream_cores
    descrack_stream_core #(
        .CORE((REGION*`CORES)+i)
    ) descrack_stream_core (
        .clk(clk),
        .rst(rst),
        .des_clk(des_clk),
        .clken(clken),
        .fsl_clk(fsl_clk),
        .fsl_rst_i(fsl_rst[i]),
        .fsl_data_i(fsl_data[i]),
        .fsl_valid_i(fsl_valid[i]),
        .fsl_rst_o(fsl_rst[i+1]),
        .fsl_data_o(fsl_data[i+1]),
        .fsl_valid_o(fsl_valid[i+1]),
        .DEBUG(dbg[i])
    );
end endgenerate

assign fsl_rst_o = fsl_rst[`CORES];
assign fsl_data_o = fsl_data[`CORES];
assign fsl_valid_o = fsl_valid[`CORES];

assign DEBUG = dbg[0];

endmodule
