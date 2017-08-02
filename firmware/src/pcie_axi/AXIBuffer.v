// AXIBuffer.v
// Copyright 2011, Pico Computing, Inc.

// This module absorbs not-ready cycles from the AXI core as well as our own RX logic so that the two don't mess each other up.
// Once Xilinx fixes their bugs, this will probably be unnecessary.


`include "PicoDefines.v"

module AXIBuffer (
    input           clk,
    input           rst,

    // AXI-S
    input  [127:0]  s_axis_rx_tdata,
    //input  [15:0]   s_axis_rx_tstrb,
    input           s_axis_rx_tlast,
    input           s_axis_rx_tvalid,
    output reg      s_axis_rx_tready,
    input    [21:0] s_axis_rx_tuser,

    // AXI-M
    output  [127:0] m_axis_rx_tdata,
    //output  [15:0]  m_axis_rx_tstrb,
    output          m_axis_rx_tlast,
    output          m_axis_rx_tvalid,
    input           m_axis_rx_tready,
    output  [21:0]  m_axis_rx_tuser
    );
    
    wire empty;
    
    wire [15:0] dop;
    
    wire wr = s_axis_rx_tvalid && s_axis_rx_tready;
    wire rd = m_axis_rx_tready && ~empty;
    
    assign m_axis_rx_tvalid = ~empty;
    
    // note that this leaves tons of empty space in the fifo, but that's not going to slow anything down.
    always @(posedge clk)
        s_axis_rx_tready    <= ~(|cnt[9:7]);//prog_full;
    
    assign m_axis_rx_tlast = dop[3];
    assign m_axis_rx_tuser[21] = dop[2];
    assign m_axis_rx_tuser[14:13] = dop[1:0];
    assign m_axis_rx_tuser[12:0] = {s_axis_rx_tuser[12:10], dop[11:4] /* bar hit */, s_axis_rx_tuser[1:0]};
    assign m_axis_rx_tuser[20:15] = s_axis_rx_tuser[20:15];
    
    // building our own "full" signal for the fifo provides better timing.
    // it takes several cycles for writes to propagate to the fifo's output. don't advertise them too soon.
    //   (this is why we use a delayed copy of wr)
    reg [5:0] wr_q;
    reg [9:0] cnt;
    always @(posedge clk) begin
        if (rst) begin
            cnt     <= 10'h0;
            wr_q    <= 6'h0;
        end else begin
            wr_q    <= {wr_q[4:0], wr};
            
            if (rd && ~wr_q[5] && (cnt != 10'h0))
                cnt <= cnt - 1;
            else if (wr_q[5] && ~rd)
                cnt <= cnt + 1;
        end
    end
    
    assign empty = ~(|cnt);
    
    //TODO make sure prog_full is set far enough back from the end.
    fifo_512x128 fifo (
        .clk(clk),
        .rst(rst),
        .din(s_axis_rx_tdata[127:0]),
        .dinp({4'h0, s_axis_rx_tuser[9:2], s_axis_rx_tlast, s_axis_rx_tuser[21], s_axis_rx_tuser[14:13]}),
        .wr_en(wr),
        .rd_en(rd),
        .dout(m_axis_rx_tdata[127:0]),
        .doutp(dop[15:0]),
        //.empty(empty),
        .prog_full(prog_full)
    );

endmodule

