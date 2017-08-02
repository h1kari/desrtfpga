`timescale 1ns / 1ps

`include "PicoDefines.v"

module stream_to_fsl(
    // stream control
    input clk,
    input rst,

    // input stream
    input s1i_valid,
    output s1i_rdy,
    input [127:0] s1i_data,
    
    // fsl output stream
    input  fsl_clk,
    output reg fsl_rst = 0,
    output [31:0] fsl_data,
    output fsl_valid,
    
    input [159:0] ring_data,
    input ring_valid,
    
    output reg [31:0] fsl_count = 0,
    output reg fsl_in_full = 0,
    output reg ring_in_full = 0,
    input [31:0] s1i_count
);

reg s1i_valid_0;
reg [159:0] s1i_data_0;
always @(posedge clk) begin
    if(s1i_valid & s1i_rdy) begin
        case(s1i_data[127])
        0: s1i_data_0[63:0]   <= s1i_data[63:0]; // {ct[63:0]}
        1: s1i_data_0[159:64] <= {`RING_DIN, s1i_data[94:0]}; // {12'h0, t[19:0], r[63:0]}
        endcase
    end
    s1i_valid_0 <= s1i_valid & s1i_rdy & s1i_data[127];
    
    //if(s1i_valid_0) $display("stream_to_fsl.s1i_data: %x", s1i_data_0);
end

wire s1i_data_rst = s1i_data_0[159:152] == 8'hff;

`define FSL_RST_DELAY 7
reg [`FSL_RST_DELAY:0] fsl_rst_reg = 0;
reg fsl_rst_ = 0;
always @(posedge clk) begin
    if(s1i_valid_0 & s1i_data_rst) begin
        fsl_rst_     <= 1;
        fsl_rst_reg <= 0;
    end
    if(fsl_rst_) begin
        if(!fsl_rst_reg[`FSL_RST_DELAY])
            fsl_rst_reg <= fsl_rst_reg + 1;
        else begin
            fsl_rst_    <= 0;
            fsl_rst_reg <= 0;
        end
    end
end

reg fsl_rst_0, fsl_rst_1;
always @(posedge fsl_clk) begin
    fsl_rst_0 <= fsl_rst_;
    fsl_rst_1 <= fsl_rst_0;
    fsl_rst   <= fsl_rst_1;
end

reg fsl_fifo_in_rd = 0;
wire [159:0] fsl_fifo_in_data;
wire fsl_fifo_in_full;
wire fsl_fifo_in_empty;
wire fsl_fifo_in_full_actual;
fsl_fifo_in_async fsl_fifo_in (
  .rd_clk(fsl_clk),
  .wr_clk(clk),
  .rst(fsl_rst),
  .din(s1i_data_0[159:0]),
  .wr_en(s1i_valid_0 & !s1i_data_rst),
  .rd_en(fsl_fifo_in_rd),
  .dout(fsl_fifo_in_data),
  .prog_full(fsl_fifo_in_full), // trigger when we're 2 units away from full to allow for pipelining of data input
  .full(fsl_fifo_in_full_actual),
  .empty(fsl_fifo_in_empty)
);
assign s1i_rdy = ~fsl_fifo_in_full;

reg fsl_in_wr_latch = 0;
always @(posedge clk) begin
    if(rst | fsl_rst) begin
        fsl_in_full <= 0;
        fsl_in_wr_latch <= 0;
    end else begin
        if(s1i_valid_0 & !s1i_data_rst) fsl_in_wr_latch <= 1;
        if(fsl_in_wr_latch && fsl_fifo_in_full_actual) fsl_in_full <= 1;
    end
end

/*
ila_1 ila_1 (
    .clk(clk),                     //total: 331
    .probe0({512'h0,
             fsl_in_full,              //1
             s1i_count,                //32
             fsl_fifo_in_rd,           //1
             fsl_fifo_in_empty,        //1
             fsl_fifo_in_full_actual,  //1
             fsl_in_wr_latch,          //1
             fsl_fifo_in_full,         //1
             s1i_data_0,               //160
             s1i_valid_0,              //1
             s1i_data_rst,             //1 
             s1i_rdy,                  //1
             s1i_valid,                //1
             s1i_data,                 //128
             rst,                      //1
             clk})                     //1
);
*/

// use a small fifo to loop ring output back to input
wire ring_empty;
reg ring_rd = 0;
wire ring_full;
wire [159:0] ring_dout;
fsl_ring_sync fsl_ring_sync (
  .clk(fsl_clk),
  .rst(fsl_rst),
  .din(ring_data),
  .wr_en(ring_valid),
  .rd_en(ring_rd),
  .dout(ring_dout),
  .empty(ring_empty),
  .full(ring_full)
);

reg ring_in_wr_latch = 0;
always @(posedge fsl_clk) begin
    if(rst | fsl_rst) begin
        ring_in_full <= 0;
        ring_in_wr_latch <= 0;
    end else begin
        if(ring_valid) ring_in_wr_latch <= 1;
        if(ring_in_wr_latch && ring_full) ring_in_full <= 1;
    end
end

reg [2:0] fsl_fifo_in_state = 0;
reg fsl_fifo_in_valid_reg = 0;
reg [4:0] fsl_fifo_in_count = 0;
reg [159:0] fsl_fifo_in_data_reg = 0;
reg fsl_fifo_in_not_empty = 0;
reg fsl_count_valid = 0;
always @(posedge fsl_clk) begin
    ring_rd <= 0;
    fsl_fifo_in_rd <= 0;

    if(rst | fsl_rst) begin
        fsl_fifo_in_state     <= 1;
        fsl_fifo_in_data_reg  <= 0;
        fsl_fifo_in_valid_reg <= 0;
        fsl_count_valid       <= 0;
        fsl_count             <= 0;
    end else begin
        case(fsl_fifo_in_state)
        0: begin
            if(!ring_empty) begin
                fsl_fifo_in_not_empty <= 1;
                fsl_fifo_in_data_reg  <= ring_dout;
                fsl_fifo_in_valid_reg <= 1;
                fsl_count_valid       <= 0;
                fsl_fifo_in_rd        <= 0;
                ring_rd               <= 1;        
                $display("stream_to_fsl.fsl_in: %x (from ring)", ring_dout);
            end else begin
                fsl_fifo_in_not_empty <= !fsl_fifo_in_empty;
                fsl_fifo_in_data_reg  <= !fsl_fifo_in_empty ? fsl_fifo_in_data : 160'h0;
                fsl_fifo_in_valid_reg <= !fsl_fifo_in_empty;
                fsl_count_valid       <= !fsl_fifo_in_empty;
                fsl_fifo_in_rd        <= !fsl_fifo_in_empty;
                ring_rd               <= 0;
                if(!fsl_fifo_in_empty)
                    $display("stream_to_fsl.fsl_in: %x (from ext)", fsl_fifo_in_data);
            end
        end
        1,2,3,4: begin
            fsl_fifo_in_data_reg  <= {fsl_fifo_in_data_reg[127:0], 32'h0};
        end
        endcase
        
        if(fsl_fifo_in_state == 4) fsl_fifo_in_state <= 0;
        else fsl_fifo_in_state <= fsl_fifo_in_state + 1;
    
        if(fsl_count_valid) fsl_count <= fsl_count + 1;
    end
    
    //if(fsl_valid) $display("stream_to_fsl.fsl_data: %x", fsl_data);
end

assign fsl_data  = fsl_fifo_in_data_reg[159:128];
assign fsl_valid = fsl_fifo_in_valid_reg;

endmodule
