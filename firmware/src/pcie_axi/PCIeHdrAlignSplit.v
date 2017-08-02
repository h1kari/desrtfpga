// PCIeHdrAlignSplit.v
// Copyright 2011 Pico Computing, Inc.

// This takes the PCIe AXI RX interface and shuffles it around to ensure that all packets start
//   at bit 0. (rather than the native AXI interface which may start a packet at 0 or 64).
//   This practically cuts the RX state machine in half.
// This logic sits between Xilinx's AXI PCIe core and the RX state machine.
// TODO: this doesn't set <valid>. you don't need it. look at <sof> and trust the data will be gapless.
// Note that this uses separate busses for the header and data so that we don't have to pause anything when we get
//   back-to-back packets that all need to be realigned. If we didn't have the separate busses, we'd need to pause the AXI
//   core for a cycle while we shifted each unaligned header over to start at the beginning of the next word.


`include "PicoDefines.v"

module PCIeHdrAlignSplit (
    input           clk,
    input           rst_n,

    // AXI-S
    input  [127:0]  m_axis_rx_tdata,
    input  [15:0]   m_axis_rx_tstrb,
    input           m_axis_rx_tlast,
    input           m_axis_rx_tvalid,
    output reg      m_axis_rx_tready,
    input  [21:0]   m_axis_rx_tuser,
    
    output reg [127:0]  hdr,
    output reg [127:0]  data,
    output              sof,
    output [7:0]        bar_hit
    );
    
    localparam TCQ = 1;
    localparam ALIGN_3 = 2'b00;
    localparam ALIGN_4 = 2'b01;
    localparam ALIGN_5 = 2'b10;
    localparam ALIGN_6 = 2'b11;
    
    reg [1:0]   align_q, align_qq;
    reg         valid_q, valid_qq, valid_qqq;
    reg         sof_q, sof_qq;
    reg [7:0]   bar_hit_q, bar_hit_qq, ha_bar_hit;
    reg [127:0] tdata_q, tdata_qq, tdata_qqq;
    wire        eof = m_axis_rx_tuser[21];
    wire [127:0] tdata = m_axis_rx_tdata;
    
    // assign the outputs
    assign sof      = sof_qq;
    assign bar_hit  = bar_hit_qq;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            
        end else begin
            m_axis_rx_tready    <= 1;
            
            sof_q       <= m_axis_rx_tvalid && m_axis_rx_tuser[14];
            sof_qq      <= sof_q;
            align_qq    <= align_q;
            valid_q     <= m_axis_rx_tvalid;
            valid_qq    <= valid_q;
            valid_qqq   <= valid_qq;
            bar_hit_q   <= m_axis_rx_tuser[9:2];
            bar_hit_qq  <= bar_hit_q;
            
            tdata_q     <= m_axis_rx_tdata;
            tdata_qq    <= tdata_q;
            tdata_qqq   <= tdata_qq;
            
            if (m_axis_rx_tvalid && m_axis_rx_tuser[14]) begin
                if (!m_axis_rx_tuser[13] && !m_axis_rx_tdata[29]) // right-aligned 32b hdr
                    align_q <= ALIGN_3;
                else if (!m_axis_rx_tuser[13] && m_axis_rx_tdata[29]) // right-aligned 64b hdr
                    align_q <= ALIGN_4;
                else if (m_axis_rx_tuser[13] && !m_axis_rx_tdata[29+64]) // mid-aligned 32b hdr
                    align_q <= ALIGN_5;
                else                                                    // mid-aligned 64b hdr
                    align_q <= ALIGN_6;
            end
            
            // load the header, and force it to 64b format (except for CPLDs, which must be 32b).
            if (sof_q) begin
                if      (align_q == ALIGN_3)    hdr <= {32'h0, tdata_q[95:30], ((tdata_q[30:24] == 7'b01001010)?1'b0:1'b1), tdata_q[28:0]};
                else if (align_q == ALIGN_4)    hdr <= tdata_q;
                else if (align_q == ALIGN_5)    hdr <= {32'h0, tdata[31:0], tdata_q[127:30+64], ((tdata_q[30+64:24+64] == 7'b01001010)?1'b0:1'b1), tdata_q[28+64:0+64]};
                else if (align_q == ALIGN_6)    hdr <= {tdata[63:0], tdata_q[127:64]};
            end
            
            if      (align_qq == ALIGN_3)   data <= {tdata_q[95:0], tdata_qq[127:96]};
            else if (align_qq == ALIGN_4)   data <= tdata_q;
            else if (align_qq == ALIGN_5)   data <= {tdata[31:0], tdata_q[127:32]};
            else if (align_qq == ALIGN_6)   data <= {tdata[63:0], tdata_q[127:64]};
        end
    end
    
endmodule

