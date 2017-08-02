`timescale 1ns / 1ps
`include "PicoDefines.v"

module descrack_stream_core #(
    parameter CORE = 0
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

wire vec_clk;
wire [159:0] vec_dout;
wire vec_rd;
wire vec_empty;
wire [159:0] vec_din;
wire vec_wr;
wire vec_full;

assign vec_clk = des_clk;

reg clken_0, clken_1, clken_2, clken_3;
always @(posedge des_clk) begin
    clken_0 <= clken;
    clken_1 <= clken_0;
    clken_2 <= clken_1;
    clken_3 <= clken_2;
end

reg fsl_rst;
reg [31:0] fsl_data;
reg fsl_valid;
always @(posedge fsl_clk) begin
    fsl_rst   <= fsl_rst_i;
    fsl_data  <= fsl_data_i;
    fsl_valid <= fsl_valid_i;
end

wire full_latch;
fsl_to_bus #(
    .CORE(CORE)
) fsl_to_bus (
    .fsl_clk(fsl_clk),
    .fsl_rst_i(fsl_rst),
    .fsl_data_i(fsl_data),
    .fsl_valid_i(fsl_valid),
    .fsl_rst_o(fsl_rst_o),
    .fsl_data_o(fsl_data_o),
    .fsl_valid_o(fsl_valid_o),
    .vec_clk(vec_clk),
    .vec_dout(vec_dout),
    .vec_rd(vec_rd),
    .vec_empty(vec_empty),
    .vec_din(vec_din),
    .vec_wr(vec_wr),
    .vec_full(vec_full),
    .des_rst(des_rst),
    .full_latch(full_latch)
);

reg des_rst_0, des_rst_1;
always @(posedge des_clk) begin
    des_rst_0 <= fsl_rst_i;
    des_rst_1 <= des_rst_0;
end

descrack descrack (
    .clk(des_clk),
    .clken(clken_3),
    .rst(des_rst_1),
    .in_ct(vec_dout[63:0]),
    .in_r(vec_dout[127:64]),
    .in_t(vec_dout[147:128]),
    .in_id(vec_dout[159:148]),
    .in_rd(vec_rd),
    .in_empty(vec_empty),
    .out_k(vec_din[55:0]),
    .out_t(vec_din[83:64]),
    .out_id(vec_din[95:84]),
    .out_wr(vec_wr)
);

assign vec_din[63:56] = 0;
assign vec_din[103:96] = CORE;
assign vec_din[159:104] = 0;

assign DEBUG[0] = clken_1;
assign DEBUG[1] = des_rst_1;
assign DEBUG[149:2] = vec_dout[147:0];
assign DEBUG[150] = vec_rd;
assign DEBUG[151] = vec_empty;
assign DEBUG[207:152] = vec_din[55:0];
assign DEBUG[227:208] = vec_din[83:64];
assign DEBUG[228] = vec_wr;
assign DEBUG[229] = fsl_rst_i;
assign DEBUG[245:230] = fsl_data_i[15:0];
assign DEBUG[246] = fsl_valid_i;
assign DEBUG[255:247] = 0;

endmodule
