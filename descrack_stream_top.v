`timescale 1ns / 1ps
`include "PicoDefines.v"

module descrack_stream_top (
    // stream control
    input clk,
    input rst,
    
    // extra clk
    input extra_clk,
    //input stop,
    
    // stream 1 in
    input s1i_valid,
    output s1i_rdy,
    input [127:0] s1i_data,
    
    // stream 1 out
    output s1o_valid,
    input s1o_rdy,
    output [127:0] s1o_data,

    // picobus for debugging
    input  PicoClk,
    input  PicoRst,
    input  [31:0]               PicoAddr,
    input  [`PICOBUS_WIDTH-1:0] PicoDataIn,
    output reg [`PICOBUS_WIDTH-1:0] PicoDataOut = 0,
    input  PicoRd,
    input  PicoWr
);

wire stop = 0;

wire stop_clock;
wire des_clk, fsl_clk;
mmcm mmcm (
    .clk_in1(extra_clk),
    .clk_out1(des_clk),
    .clk_out2(fsl_clk),
    .reset(rst)
);

wire [`REGIONS:0] fsl_rst;
wire [31:0] fsl_data [`REGIONS:0];
wire [`REGIONS:0] fsl_valid;

`define MAX_REGIONS 29
`define MAX_REGIONS_LOG2 5
`define RAMP_LOG2 18 //2<<18 = 29 * 262144 * 10ns = 76.02176 ms
reg [`MAX_REGIONS-1:0] ramp_ce = 0;
reg [`MAX_REGIONS-1:0] clken = 0;
reg [`RAMP_LOG2+`MAX_REGIONS_LOG2:0] ramp_counter = 0;
reg fsl_rst_latch = 1;
integer j;
always @(posedge fsl_clk) begin
    if(stop_clock || fsl_rst_latch || stop) begin
        ramp_counter <= 25'h0;
        ramp_ce      <= {`REGIONS{1'b0}};
    end else begin
        if(!ramp_counter[`RAMP_LOG2+`MAX_REGIONS_LOG2])
            ramp_counter[`RAMP_LOG2+`MAX_REGIONS_LOG2:0] <= {1'b0, ramp_counter[`RAMP_LOG2+`MAX_REGIONS_LOG2-1:0]} + 1;
        
        case(ramp_counter[`RAMP_LOG2+`MAX_REGIONS_LOG2:`RAMP_LOG2])
        6'd00: ramp_ce[0]  <= 1;
        6'd01: ramp_ce[1]  <= 1;
        6'd02: ramp_ce[2]  <= 1;
        6'd03: ramp_ce[3]  <= 1;
        6'd04: ramp_ce[4]  <= 1;
        6'd05: ramp_ce[5]  <= 1;
        6'd06: ramp_ce[6]  <= 1;
        6'd07: ramp_ce[7]  <= 1;
        6'd08: ramp_ce[8]  <= 1;
        6'd09: ramp_ce[9]  <= 1;
        6'd10: ramp_ce[10] <= 1;
        6'd11: ramp_ce[11] <= 1;
        6'd12: ramp_ce[12] <= 1;
        6'd13: ramp_ce[13] <= 1;
        6'd14: ramp_ce[14] <= 1;
        6'd15: ramp_ce[15] <= 1;
        6'd16: ramp_ce[16] <= 1;
        6'd17: ramp_ce[17] <= 1;
        6'd18: ramp_ce[18] <= 1;
        6'd19: ramp_ce[19] <= 1;
        6'd20: ramp_ce[20] <= 1;
        6'd21: ramp_ce[21] <= 1;
        6'd22: ramp_ce[22] <= 1;
        6'd23: ramp_ce[23] <= 1;
        6'd24: ramp_ce[24] <= 1;
        6'd25: ramp_ce[25] <= 1;
        6'd26: ramp_ce[26] <= 1;
        6'd27: ramp_ce[27] <= 1;
        6'd28: ramp_ce[28] <= 1;
        endcase
    end
    
    for(j = 0; j < `MAX_REGIONS; j = j + 1)
        clken[j] <= !stop_clock & ramp_ce[j];
end

reg fsl_rst_0 = 0;
always @(posedge fsl_clk) begin
    // on power up and when fsl_rst lets disable the clock
    if(rst || fsl_rst[0])
        fsl_rst_latch <= 1;
    // on negative edge of rst, then bring clocks up
    // this is to keep clocks disabled on power-up until we issue an fsl_rst
    else if(!fsl_rst[0] && fsl_rst_0)
        fsl_rst_latch <= 0;
    
    fsl_rst_0 <= fsl_rst[0];
end

wire [159:0] ring_data;
wire ring_valid;
wire [31:0] fsl_count;
wire [22:0] stream_to_fsl_DEBUG;
wire fsl_in_full, ring_in_full;
reg [31:0] s1i_count;
stream_to_fsl stream_to_fsl (
    .clk(clk),
    .rst(rst),
    .s1i_valid(s1i_valid),
    .s1i_rdy(s1i_rdy),
    .s1i_data(s1i_data),
    .fsl_clk(fsl_clk),
    .fsl_rst(fsl_rst[0]),
    .fsl_data(fsl_data[0]),
    .fsl_valid(fsl_valid[0]),
    .ring_data(ring_data),
    .ring_valid(ring_valid),
    .fsl_count(fsl_count),
    .fsl_in_full(fsl_in_full),
    .ring_in_full(ring_in_full),
    .s1i_count(s1i_count)
);

always @(posedge clk) begin
    if(rst) s1i_count <= 0;
    else if(s1i_valid & s1i_rdy) s1i_count <= s1i_count + 1;
end

wire [255:0] dbg [`REGIONS-1:0];

genvar i;
generate for (i = 0; i < `REGIONS; i = i + 1) begin : des_stream_regions
    descrack_stream_region #(
        .REGION(i)
    ) descrack_stream_region (
        .clk(clk),
        .rst(rst),
        .des_clk(des_clk),
        .clken(clken[i]),
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

wire full_latch, stop_clock_latch;
fsl_to_stream fsl_to_stream (
    .clk(clk),
    .rst(rst),
    .fsl_clk(fsl_clk),
    .fsl_rst(fsl_rst[`REGIONS]),
    .fsl_data(fsl_data[`REGIONS]),
    .fsl_valid(fsl_valid[`REGIONS]),
    .s1o_valid(s1o_valid),
    .s1o_rdy(s1o_rdy),
    .s1o_data(s1o_data),
    .stop_clock(stop_clock),
    .ring_data(ring_data),
    .ring_valid(ring_valid),
    .full_latch(full_latch),
    .stop_clock_latch(stop_clock_latch)
);

reg [31:0] s1o_count;
always @(posedge clk) begin
    if(rst) s1o_count <= 0;
    else if(s1o_valid & s1o_rdy) s1o_count <= s1o_count + 1;
end

always @(posedge PicoClk) begin
    PicoDataOut <= 0;
    if(!PicoRst && PicoRd) begin
        case(PicoAddr)
        0: PicoDataOut <= {stop_clock_latch, full_latch, ring_in_full, fsl_in_full, fsl_count, s1o_count, s1i_count};
        endcase
    end
end

wire [255:0] DEBUG;

assign DEBUG[0] = s1i_valid;
assign DEBUG[1] = s1i_rdy;
assign DEBUG[65:2] = s1i_data[63:0];
assign DEBUG[66] = s1i_data[127];
assign DEBUG[67] = s1o_valid;
assign DEBUG[68] = s1o_rdy;
assign DEBUG[132:69] = s1o_data[63:0];
assign DEBUG[133] = fsl_rst[0];
assign DEBUG[165:134] = fsl_data[0];
assign DEBUG[166] = fsl_valid[0];
assign DEBUG[198:167] = ring_data[31:0];
assign DEBUG[199] = ring_valid;
assign DEBUG[200] = fsl_rst[`REGIONS];
assign DEBUG[232:201] = fsl_data[`REGIONS];
assign DEBUG[233] = fsl_valid[`REGIONS];
assign DEBUG[255:234] = 0;

/*
ila_1 ila_1 (
    .clk(des_clk),
    .probe0({DEBUG, dbg[0]})
);
*/

endmodule
