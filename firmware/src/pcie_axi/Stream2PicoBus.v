// Stream2PicoBus.v
// Copyright 2011 Pico Computing, Inc.

// This module implements a PicoBus on two streams:
//   an input stream that carries commands and write data, and
//   an output stream that carries read data.
// Command format:
//   [64]       read flag. 1=read, 0=write.
//   [63:32]    addr in bytes. for 128b PicoBus, bottom four bits are forced to zero.
//   [31:0]     size in bytes

// The read feature is only using 1/3 potential bus throughput, for want of a fifo. That's probably fine.

//TODO it would be really easy to add variable-latency reads. just add a PicoRdAck or PicoDataOutValid signal, and watch it
//  rather than PicoRd_q.

module Stream2PicoBus #(
    parameter           STREAM_ID=1,
    parameter           W=128
    ) (
    input               s_clk,
    input               s_rst,
    
    input               s_out_en,
    input       [8:0]   s_out_id,
    output      [127:0] s_out_data,
    
    input               s_in_valid,
    input [8:0]         s_in_id,
    input [127:0]       s_in_data,
    
    input       [8:0]   s_poll_id,
    output      [31:0]  s_poll_seq,
    output      [127:0] s_poll_next_desc,
    output              s_poll_next_desc_valid,
    
    input       [8:0]   s_next_desc_rd_id,
    input               s_next_desc_rd_en,
    
    output              PicoClk,
    output              PicoRst,
    output      [W-1:0] PicoDataIn,
    output              PicoWr,
    input       [W-1:0] PicoDataOut,
    output      [31:0]  PicoAddr,
    output              PicoRd
    );
    
    wire               i_valid;
    wire              i_rdy;
    wire [127:0]       i_data;
    wire              o_valid;
    wire               o_rdy;
    wire [127:0]      o_data;
    
    wire [31:0]     s126o_desc_poll_seq;
    wire            s126o_desc_poll_next_desc_valid;
    wire [127:0]    s126o_desc_poll_next_desc;
    wire [127:0]    s126o_data_fetch;
    
    PicoStreamOut #(
        .ID(STREAM_ID)
    ) s126o_stream (
        .clk(s_clk),
        .rst(s_rst),
        
        .s_rdy(o_rdy),
        .s_valid(o_valid),
        .s_data(o_data),
        
        .s_out_en(s_out_en),
        .s_out_id(s_out_id[8:0]),
        .s_out_data(s126o_data_fetch[127:0]),
        
        .s_in_valid(s_in_valid),
        .s_in_id(s_in_id[8:0]),
        .s_in_data(s_in_data[127:0]),
        
        .s_poll_id(s_poll_id[8:0]),
        .s_poll_seq(s126o_desc_poll_seq[31:0]),
        .s_poll_next_desc(s126o_desc_poll_next_desc[127:0]),
        .s_poll_next_desc_valid(s126o_desc_poll_next_desc_valid),
        
        .s_next_desc_rd_en(s_next_desc_rd_en),
        .s_next_desc_rd_id(s_next_desc_rd_id[8:0])
    );
    
    wire [31:0]     s126i_desc_poll_seq;
    wire            s126i_desc_poll_next_desc_valid;
    wire [127:0]    s126i_desc_poll_next_desc;
    
    PicoStreamIn #(
        .ID(STREAM_ID)
    ) s126i_stream (
        .clk(s_clk),
        .rst(s_rst),
        
        .s_rdy(i_valid),
        .s_en(i_rdy),
        .s_data(i_data[127:0]),
        
        .s_in_valid(s_in_valid),
        .s_in_id(s_in_id[8:0]),
        .s_in_data(s_in_data[127:0]),
        
        .s_poll_id(s_poll_id[8:0]),
        .s_poll_seq(s126i_desc_poll_seq[31:0]),
        .s_poll_next_desc(s126i_desc_poll_next_desc[127:0]),
        .s_poll_next_desc_valid(s126i_desc_poll_next_desc_valid),
        
        .s_next_desc_rd_en(s_next_desc_rd_en),
        .s_next_desc_rd_id(s_next_desc_rd_id[8:0])
    );
    
    assign s_out_data               = s126o_data_fetch;
    assign s_poll_seq               = s126i_desc_poll_seq | s126o_desc_poll_seq;
    assign s_poll_next_desc         = s126i_desc_poll_next_desc | s126o_desc_poll_next_desc;
    assign s_poll_next_desc_valid   = s126i_desc_poll_next_desc_valid | s126o_desc_poll_next_desc_valid;
    
    StreamToPicoBus #(.WIDTH(W)) s2pb (
        .s_clk              (s_clk),
        .s_rst              (s_rst),

        .si_ready           (i_rdy),
        .si_valid           (i_valid),
        .si_data            (i_data),

        .so_ready           (o_rdy),
        .so_valid           (o_valid),
        .so_data            (o_data),

        .PicoClk            (PicoClk),
        .PicoRst            (PicoRst),
        .PicoWr             (PicoWr),
        .PicoRd             (PicoRd),
        .PicoAddr           (PicoAddr),
        .PicoDataIn         (PicoDataIn),
        .PicoDataOut        (PicoDataOut)
    );
endmodule

