`timescale 1ns / 1ps

`include "PicoDefines.v"

module fsl_to_stream(
    // stream control
    input clk,
    input rst,
    
    // fsl input stream
    input fsl_clk,
    input fsl_rst,
    input [31:0] fsl_data,
    input fsl_valid,
    
    // output stream
    output s1o_valid,
    input  s1o_rdy,
    output [127:0] s1o_data,
    
    // ring loopback output
    output [159:0] ring_data,
    output reg ring_valid = 0,

    output stop_clock,
    
    output reg full_latch = 0,
    output reg stop_clock_latch = 0
);

wire prog_full;
reg [159:0] fsl_fifo_out_data = 0;
reg [127:0] fsl_fifo_out_data_0 = 0;
reg fsl_fifo_out_wr = 0, fsl_fifo_out_wr_0 = 0;
wire fsl_fifo_out_empty;
wire fsl_fifo_out_full;
fsl_fifo_async_out fsl_fifo_out (
    .wr_clk(fsl_clk),
    .rd_clk(clk),
    .rst(fsl_rst),
    .din(fsl_fifo_out_data_0),
    .wr_en(fsl_fifo_out_wr_0), // just write single 128-bit value
    .dout(s1o_data),
    .rd_en(!fsl_fifo_out_empty & s1o_rdy),
    .empty(fsl_fifo_out_empty),
    .full(fsl_fifo_out_full),
    .prog_full(prog_full)
);
assign s1o_valid = !fsl_fifo_out_empty & s1o_rdy;


reg wr_latch = 0;
//reg full_latch = 0;
reg [4:0] fsl_fifo_out_count = 0;
always @(posedge fsl_clk) begin
    if(fsl_rst) begin
        fsl_fifo_out_count <= 1;
        fsl_fifo_out_wr <= 0;
        wr_latch <= 0;
        full_latch <= 0;
        ring_valid <= 0;
    end else begin
        if(fsl_valid) begin
            if(fsl_fifo_out_count[4] & full_latch)
                fsl_fifo_out_data <= {1'b0, fsl_fifo_out_data[126:0], fsl_data[31:0]};
            else
                fsl_fifo_out_data <= {fsl_fifo_out_data[127:0], fsl_data[31:0]};
            fsl_fifo_out_count <= {fsl_fifo_out_count[3:0], fsl_fifo_out_count[4]};
            if(fsl_fifo_out_count[4]) begin
                fsl_fifo_out_wr <= fsl_fifo_out_data[127] == `RING_DOUT;
                ring_valid      <= fsl_fifo_out_data[127] == `RING_DIN;
                //fsl_fifo_out_data_0 <= {1'b1, 31'h0, fsl_fifo_out_data[127:32]};
            end else begin
                ring_valid      <= 0;
                fsl_fifo_out_wr <= 0;
            end
            //$display("fsl_to_stream.fsl_data: %x", fsl_data); 
        end else begin
            ring_valid <= 0;
            fsl_fifo_out_wr <= 0;
        end
       
        if(fsl_fifo_out_wr) begin
            fsl_fifo_out_data_0 <= fsl_fifo_out_data[127:0];
            wr_latch <= 1;
            //$display("fsl_to_stream.fifo_din: %x", fsl_fifo_out_data_0[63:0]);
        end
        
        if(fsl_fifo_out_wr_0) begin
            //$display("fsl_to_stream.fifo_din: %x", fsl_fifo_out_data_0[63:0]);
        end
           
        if(fsl_fifo_out_full & wr_latch)
            full_latch <= 1;
    end
    
    fsl_fifo_out_wr_0 <= fsl_fifo_out_wr;

    if(ring_valid) begin
        //$display("fsl_to_stream.ring_data: %x", ring_data);
    end
end

always @(posedge clk) begin
    //if(s1o_valid) $display("fsl_to_stream.s1o_data: %x", s1o_data);
end

assign stop_clock = prog_full & wr_latch;
assign ring_data = fsl_fifo_out_data;

always @(posedge fsl_clk) begin
    if(fsl_rst | rst) stop_clock_latch <= 0;
    else if(stop_clock) stop_clock_latch <= 1;
end

endmodule
