//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2010 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Virtex-6 Integrated Block for PCI Express
// File       : PIO_128_RX_ENGINE.v
// Version    : 2.1
//--
//-- Description: 128 bit Local-Link Receive Unit.
//--
//--------------------------------------------------------------------------------

`timescale 1ns/1ns

`include "PicoDefines.v"

module PIO_128_RX_ENGINE #(
  parameter C_DATA_WIDTH = 128,            // RX/TX interface data width
  parameter TCQ = 1,

  // Do not override parameters below this line
  parameter STRB_WIDTH = C_DATA_WIDTH / 8               // TSTRB width
) (
    input              clk,
    input              rst_n,
    
    input [11:0]        read_log,
    output     [7:0]    read_log_inx,
    output reg [7:0]    last_cpld_tag=8'h0,
    output reg          last_cpld_tag_valid=0,

    input [7:0]         sent_tag,
    input [31:0]        sent_tag_seq,
    input               sent_tag_en,
    
    output reg [127:0]  stream_data,
    output reg [8:0]    stream_inx,
    output reg          stream_valid,
    
    output reg          direct_rx_valid,
    
    input [127:0]       rx_hdr,
    input [127:0]       rx_data,
    //input               rx_valid,
    input               rx_sof,
    input [7:0]         rx_bar_hit,

  /*
                         * Memory Read data handshake with Completion
                         * transmit unit. Transmit unit reponds to
                         * req_compl assertion and responds with compl_done
                         * assertion when a Completion w/ data is transmitted.
                         */

    output              req_compl_o,
    output reg         req_compl_wd_o,

    input              compl_done_i,

    output reg [2:0]   req_tc_o,             // Memory Read TC
    output reg         req_td_o,             // Memory Read TD
    output reg         req_ep_o,             // Memory Read EP
    output reg [1:0]   req_attr_o,           // Memory Read Attribute
    output reg [9:0]   req_len_o,            // Memory Read Length (1DW)
    output reg [15:0]  req_rid_o,            // Memory Read Requestor ID
    output reg [7:0]   req_tag_o,            // Memory Read Tag
    output reg [7:0]   req_be_o,             // Memory Read Byte Enables
    output reg [63:0]  req_addr_o,           // Memory Read Address

/*
                         * Memory interface used to save 1 DW data received
                         * on Memory Write 32 TLP. Data extracted from
                         * inbound TLP is presented to the Endpoint memory
                         * unit.
                         */

    output reg [63:0]  wr_addr_o,           // Memory Write Address
    output reg [7:0]   wr_be_o,             // Memory Write Byte Enable
    output reg [31:0]  wr_data_o,           // Memory Write Data
    output reg         wr_en_o             // Memory Write Enable
);

// these TYPEs are bits [30:24] in the PCIe header.
localparam PIO_128_RX_MEM_RD32_FMT_TYPE = 7'b00_00000;
localparam PIO_128_RX_MEM_WR32_FMT_TYPE = 7'b10_00000;
localparam PIO_128_RX_MEM_RD64_FMT_TYPE = 7'b01_00000;
localparam PIO_128_RX_MEM_WR64_FMT_TYPE = 7'b11_00000;
localparam PIO_128_RX_IO_RD32_FMT_TYPE  = 7'b00_00010;
localparam PIO_128_RX_IO_WR32_FMT_TYPE  = 7'b10_00010;
localparam PIO_128_RX_CPLD_FMT_TYPE     = 7'b10_01010;

localparam PIO_128_RX_RST_STATE         = 7'b0000000;
localparam PIO_128_RX_CPLD_STATE        = 7'b0000010;
//localparam PIO_128_RX_MEM_RD32_DW1DW2     =  7'b0000001;
//localparam PIO_128_RX_MEM_WR32_DW1DW2     =  7'b0000010;
//localparam PIO_128_RX_MEM_RD64_DW1DW2     =  7'b0000100;
//localparam PIO_128_RX_MEM_WR64_DW1DW2     =  7'b0001000;
//localparam PIO_128_RX_WAIT_STATE          =  7'b0010000;
localparam PIO_128_RX_MEM_WR64_DW5      = 7'b0100000;
//localparam PIO_128_RX_IO_WR32_DW1DW2      =  7'b1000000;

    // Local Registers
    
    reg             req_compl; // a pre-register for req_compl_o to ease timing.
    reg [3:0]       req_compl_q;
    assign req_compl_o = req_compl_q[2];
    
    reg [63:0]      wr_addr_p;
    reg             do_wr;

    reg [6:0]          state;
    reg [6:0]          tlp_type;
    
    // the whole stream pipeline is a little wonky (especially naming) since the user-direct and peer stream stuff was bolted on after the fact.
    // it could use a rewrite.
    reg             non_stream_rx, non_stream_rx_q, non_stream_rx_qq, peer_stream_rx, peer_stream_rx_q;
    reg [8:0]       peer_stream_id, peer_stream_id_q;
    
    // history lesson: first there was only start_cpld. then this signal was co-opted by the peer write receiving code.
    //   then, when we implemented reordering, we needed separate signals. so start_true_cpld is set if it's really a cpld.
    //   start_cpld is still used for peer writes.
    reg             start_true_cpld;
    reg             start_cpld, start_cpld_q, start_cpld_qq;
    reg [127:0]     rx_data_q, rx_data_qq, rx_data_q3;
    reg [9:0]       cpld_dw_len, cpld_dw_rem, cpld_dw_len_q;
    // we're adding a pipeline stage to the bram read to improve timing. it'll be absorbed into the bram and won't add logic.
    //   (although the rx_data pipeline stage we have to add isn't free)
    reg [11:0]      read_log_q;
    reg [7:0]       cpld_rem_count; // (128b-word version of...) the "bytes remaining" field in a cpld header. also called "byte count". NOT necessarily the packet length.
    reg [7:0]       cpld_reorder_len, cpld_reorder_len_rem; // this is redundant (we already have cpld_dw_len), but for implementation speed, here it is.
    reg             reorder_din_en;

    reg [127:0]     stream_data_non_cpld_q4, stream_data_non_cpld_q5, stream_data_non_cpld_q6, stream_data_non_cpld_q7, stream_data_non_cpld_q8, stream_data_non_cpld_q9;
    reg [8:0]       stream_inx_non_cpld_q4, stream_inx_non_cpld_q5, stream_inx_non_cpld_q6, stream_inx_non_cpld_q7, stream_inx_non_cpld_q8, stream_inx_non_cpld_q9;
    reg             stream_valid_non_cpld_q4, stream_valid_non_cpld_q5, stream_valid_non_cpld_q6, stream_valid_non_cpld_q7, stream_valid_non_cpld_q8, stream_valid_non_cpld_q9;
    reg [127:0]     cpld_data_reordered_q, cpld_data_reordered_q2;
    reg             cpld_data_reordered_valid_q, cpld_data_reordered_valid_q2;
    wire [7:0]       cpld_read_log_inx = cpld_tag_reordered;
    assign read_log_inx = cpld_tag_reordered;

    wire [127:0]    cpld_data_reordered;
    wire [7:0]      cpld_tag_reordered;
    wire            cpld_data_reordered_valid;
    
    `ifdef XILINX_ULTRASCALE
        wire [127:0]    rx_data_swizzled = rx_data;
    `else
        wire [127:0]    rx_data_swizzled = {rx_data[103:96],
                                            rx_data[111:104],
                                            rx_data[119:112],
                                            rx_data[127:120],
                                            rx_data[71:64],
                                            rx_data[79:72],
                                            rx_data[87:80],
                                            rx_data[95:88],
                                            rx_data[39:32],
                                            rx_data[47:40],
                                            rx_data[55:48],
                                            rx_data[63:56],
                                            rx_data[07:00],
                                            rx_data[15:08],
                                            rx_data[23:16],
                                            rx_data[31:24]};
    `endif //XILINX_ULTRASCALE

  // we now have two pipelines of data coming into the card that's destined for a stream.
  //  1) cpld data that we've requested from the host. this may be reordered (eg on sandy bridge)
  //  2) writes from peers (other fpgas). this will not be reordered.
  // we can't just throw the peer writes into the reorder buffer, so we need to arbitrate between these two pipelines.
  // XXX WE DON'T DO THAT YET. THIS IS JUST A SKETCH!
  always @(posedge clk) begin
    stream_data_non_cpld_q5   <= stream_data_non_cpld_q4;
    stream_data_non_cpld_q6   <= stream_data_non_cpld_q5;
    stream_data_non_cpld_q7   <= stream_data_non_cpld_q6;
    stream_data_non_cpld_q8   <= stream_data_non_cpld_q7;
    stream_data_non_cpld_q9   <= stream_data_non_cpld_q8;
    stream_inx_non_cpld_q5    <= stream_inx_non_cpld_q4;
    stream_inx_non_cpld_q6    <= stream_inx_non_cpld_q5;
    stream_inx_non_cpld_q7    <= stream_inx_non_cpld_q6;
    stream_inx_non_cpld_q8    <= stream_inx_non_cpld_q7;
    stream_inx_non_cpld_q9    <= stream_inx_non_cpld_q8;
    stream_valid_non_cpld_q5  <= stream_valid_non_cpld_q4;
    stream_valid_non_cpld_q6  <= stream_valid_non_cpld_q5;
    stream_valid_non_cpld_q7  <= stream_valid_non_cpld_q6;
    stream_valid_non_cpld_q8  <= stream_valid_non_cpld_q7;
    stream_valid_non_cpld_q9  <= stream_valid_non_cpld_q8;
    //stream_valid  <= stream_valid_non_cpld_q8;
    //stream_data   <= stream_data_non_cpld_q8;
    //stream_inx    <= stream_inx_non_cpld_q8;

    //cpld_read_log_inx  <= cpld_tag_reordered;
    cpld_data_reordered_q   <= cpld_data_reordered;
    cpld_data_reordered_q2  <= cpld_data_reordered_q;
    cpld_data_reordered_valid_q <= cpld_data_reordered_valid;
    cpld_data_reordered_valid_q2<= cpld_data_reordered_valid_q;

    //stream_valid  <= cpld_data_reordered_valid_q2;
    //stream_data   <= cpld_data_reordered_q2;
    //stream_inx    <= read_log[8:0];

    stream_valid    <= cpld_data_reordered_valid_q2 | stream_valid_non_cpld_q8;
    if (cpld_data_reordered_valid_q2) begin
      stream_data   <= cpld_data_reordered_q2;
      stream_inx    <= read_log[8:0];
    end else if (stream_valid_non_cpld_q8) begin
      stream_data   <= stream_data_non_cpld_q8;
      stream_inx    <= stream_inx_non_cpld_q8;
    end
  end

  always @(posedge clk) begin
    if (start_true_cpld) begin
      //$display("setting cpld_reorder_len_rem to 0x%x. cpld_rem_count: 0x%x", cpld_reorder_len, cpld_rem_count);
      cpld_reorder_len_rem  <= cpld_reorder_len;
      reorder_din_en        <= 1;
    end else if (cpld_reorder_len_rem == 8'h1) begin
      reorder_din_en        <= 0;
    end else
      cpld_reorder_len_rem  <= cpld_reorder_len_rem - 1;
  end

  Reorder Reorderer (
    .clk(clk),
    .rst(~rst_n),
    .tag_in(last_cpld_tag),
    .tag_en(start_true_cpld),
    .rem_count(cpld_rem_count),
    .data_in(rx_data_q),
    .data_in_en(reorder_din_en),
    .tag_seq_end_in_en(sent_tag_en),
    .tag_seq_end_in(sent_tag_seq),
    .tag_seq_end_in_tag(sent_tag),
    .data_out(cpld_data_reordered),
    .data_out_en(cpld_data_reordered_valid),
    .tag_out(cpld_tag_reordered)
  );

  always @ ( posedge clk ) begin
    last_cpld_tag_valid  <= #TCQ 0;

    if (!rst_n ) begin
      //TODO most of these don't really need to be reset.
      req_compl     <= #TCQ 0;
      req_compl_q   <= #TCQ 4'h0;
      req_compl_wd_o <= #TCQ 1'b1;
      req_tc_o       <= #TCQ 2'b0;
      req_td_o       <= #TCQ 1'b0;
      req_ep_o       <= #TCQ 1'b0;
      req_attr_o     <= #TCQ 2'b0;
      req_len_o      <= #TCQ 10'b0;
      req_rid_o      <= #TCQ 16'b0;
      req_tag_o      <= #TCQ 8'b0;
      req_be_o       <= #TCQ 8'b0;
      req_addr_o     <= #TCQ 64'b0;
      wr_be_o        <= #TCQ 8'b0;
      wr_addr_o      <= #TCQ 64'b0;
      wr_data_o      <= #TCQ 31'b0;
      wr_en_o        <= #TCQ 1'b0;
      start_cpld     <= #TCQ 0;
      start_true_cpld<= #TCQ 0;
      stream_valid_non_cpld_q4  <= #TCQ 0;
      cpld_dw_rem   <= #TCQ 0;
      //last_cpld_tag <= #TCQ 8'h0;
      do_wr         <= #TCQ 0;
      non_stream_rx <= #TCQ 0;

      state          <= #TCQ PIO_128_RX_RST_STATE;
      tlp_type       <= #TCQ 7'b0;
    end else begin
        wr_en_o         <= #TCQ 1'b0;
        req_compl       <= #TCQ 0;
        req_compl_q     <= #TCQ {req_compl_q[2:0], req_compl};
        start_cpld      <= #TCQ 0;
        start_true_cpld <= #TCQ 0;
        do_wr           <= #TCQ 0;
        
        // CPLD handling
        // the pipelining here is excessive, especially since we've 128b of data. might want to trim it back a stage.
        // this logic must exist outside any specific 'state' since we may receive another packet right behind a cpld, which
        //   would send us into any state.
        // note that packets can overlap such that there's there's old data still in this pipeline when we get a new packet that
        //   could be from a different stream. we have to make sure we don't switch the stream id too soon and mislabel the end of the first packet.
        rx_data_q           <= #TCQ rx_data_swizzled;
        rx_data_qq          <= #TCQ rx_data_q;
        rx_data_q3          <= #TCQ rx_data_qq;
        start_cpld_q        <= #TCQ start_cpld;
        start_cpld_qq       <= #TCQ start_cpld_q;
        non_stream_rx_q     <= #TCQ non_stream_rx;
        non_stream_rx_qq    <= #TCQ non_stream_rx_q;
        peer_stream_rx_q    <= #TCQ peer_stream_rx;
        peer_stream_id_q    <= #TCQ peer_stream_id;
        direct_rx_valid     <= #TCQ non_stream_rx_qq && |cpld_dw_rem;
        stream_valid_non_cpld_q4        <= #TCQ ~non_stream_rx_qq && |cpld_dw_rem;
        stream_data_non_cpld_q4         <= #TCQ rx_data_q3;
        read_log_q          <= #TCQ read_log;
        cpld_dw_len_q       <= #TCQ cpld_dw_len;
        if (start_cpld_qq) begin
            if (peer_stream_rx_q)
                stream_inx_non_cpld_q4  <= #TCQ peer_stream_id_q[8:0];
            else
                stream_inx_non_cpld_q4  <= #TCQ read_log[8:0];
            cpld_dw_rem     <= #TCQ cpld_dw_len_q;
        end else if (|cpld_dw_rem)
            cpld_dw_rem     <= #TCQ cpld_dw_rem - 4; // 4 dw per clock w/ 128b bus
        else
            stream_valid_non_cpld_q4    <= #TCQ 0;
        
        if (do_wr) begin
            wr_addr_o   <= #TCQ wr_addr_p;
            wr_data_o   <= #TCQ rx_data_swizzled[31:0];
            wr_en_o     <= #TCQ 1'b1;
        end
        
      case (state)

        PIO_128_RX_RST_STATE : begin

            state               <= #TCQ PIO_128_RX_RST_STATE;
            req_compl_wd_o      <= #TCQ 1'b1;


          if (rx_sof) begin
              tlp_type          <= #TCQ rx_hdr[31:24];
              peer_stream_rx    <= #TCQ 0;
              
              case (rx_hdr[30:24])
                
                PIO_128_RX_CPLD_FMT_TYPE : begin
                    //TODO we might want to make sure the byte count is something we expect (eg low 2 bits clear).
                    //$display("%0t: RX CPLD. 0x%xB, tag 0x%x", $time, rx_hdr[9:0]*4, rx_hdr[76:72]);
                    cpld_dw_len     <= #TCQ {rx_hdr[9:2], 2'b00}; // trimming the low bits to round down to 128b boundary.
                    cpld_reorder_len<= #TCQ rx_hdr[9:2]; // trimming the low bits to round down to 128b boundary.
                    cpld_rem_count  <= #TCQ rx_hdr[11+32:4+32];
                    // note that we're setting start_TRUE_cpld here, which triggers a different pipeline (the reorder one) from the old start_cpld signal.
                    start_true_cpld <= #TCQ 1;
                    // use the returned tag to look up this data's final destination.
                    // this is now driven by the reordered tag, not the tag straight off the wire.
                    //read_log_inx    <= #TCQ rx_hdr[79:72]; // we're only using the non-extended 5 tag bits, rather than 8. UPDATE: now using all 8
                    last_cpld_tag   <= #TCQ rx_hdr[79:72]; // ditto, for the outside world tracking outstanding reads.
                    // a single read request will usually be fulfilled with multiple completions. we need to make sure we only add the tag back into the
                    //   pool once, rather than every time we see a partial completion. we'll assume that all our read requests are for multiples of
                    //   16B, and we can do a simple equality check of the packet size and the bytes remaining (which includes the current packet).
                    // rx_hdr[9:2] is current packet size in dwords. hx_hdr[11+32:4+32] is remaining byte count. equal for the last completion of each read.
                    if (rx_hdr[9:2] == rx_hdr[11+32:4+32])
                      last_cpld_tag_valid <= #TCQ 1;
                    // we're just going to stay in the RST state while the data in this packet pours in.
                    // it'll get handled by the CPLD logic in this module, rather than complicating this state machine.
                    non_stream_rx   <= #TCQ 0;
                end
                
                PIO_128_RX_MEM_RD64_FMT_TYPE : begin
                  if (rx_hdr[9:0] == 10'b1) begin
                    req_tc_o     <= #TCQ rx_hdr[22:20];
                    req_td_o     <= #TCQ rx_hdr[15];
                    req_ep_o     <= #TCQ rx_hdr[14];
                    req_attr_o   <= #TCQ rx_hdr[13:12];
                    req_len_o    <= #TCQ rx_hdr[9:0];
                    req_rid_o    <= #TCQ rx_hdr[63:48];
                    req_tag_o    <= #TCQ rx_hdr[47:40];
                    req_be_o     <= #TCQ rx_hdr[39:32];
                    
                    //lower qw
                    // Upper 32-bits of 64-bit address not used, but would be captured
                    // in this state if used.  Upper 32 address bits are on
                    //rx_hdr[127:96]
                    req_addr_o      <= #TCQ {32'h0, rx_hdr[95:66], 2'b00};
                    req_compl       <= #TCQ 1'b1;
                    req_compl_wd_o  <= #TCQ 1'b1;
                    state           <= #TCQ PIO_128_RX_RST_STATE;
                  end else begin
                    state           <= #TCQ PIO_128_RX_RST_STATE;
                  end
                end
                
                PIO_128_RX_MEM_WR64_FMT_TYPE : begin
                  if (rx_hdr[9:0] == 10'b1 /* size == 32b */ /* XXX && rx_bar_hit[0]*/) begin
                    wr_be_o         <= #TCQ rx_hdr[39:32];
                    wr_addr_p       <= #TCQ {32'h0 /*TODO: huh? why not from rx_hdr?*/, rx_hdr[95:66], 2'b00};
                    do_wr           <= #TCQ 1;
                    state           <= #TCQ PIO_128_RX_RST_STATE;
                  end else if (rx_bar_hit[2]) begin
                    // we're pick-a-backing on cpld code, which leads to confusing names when we use the cpld
                    //   logic to handle these incoming writes.
                    // TODO: now that we've got reordering, we need to straighten this out, since we don't want to try to reorder the peer writes.
                    
                    non_stream_rx   <= #TCQ 1;
                    cpld_dw_len     <= #TCQ {rx_hdr[9:2], 2'b00}; // trimming the low bits to round down to 128b boundary.
                    start_cpld      <= #TCQ 1;
                    // we're just going to stay in the RST state while the data in this packet pours in.
                    // it'll get handled by the CPLD logic in this module, rather than complicating this state machine.
                  end else if (rx_bar_hit[0] && rx_hdr[1:0] == 2'h0) begin
                    //TODO test this!
                    // catch peer stream traffic. the upper address bits are the stream id minus the 'input' flag bit.
                    //TODO come up with a better check once we figure out why bar_hit isn't working
                    //  right now this will wrongly catch packets on the first bar that are bigger than 32b.
                    non_stream_rx   <= #TCQ 0;
                    peer_stream_rx  <= #TCQ 1;
                    cpld_dw_len     <= #TCQ {rx_hdr[9:2], 2'b00}; // trimming the low bits to round down to 128b boundary.
                    start_cpld      <= #TCQ 1;
                    // each stream has a 4kB window in this bar. so the stream id is the address after trimming off the low 12 bits.
                    // (and after adding on the upper two bits, which are implied, and indicate "incoming stream".)
                    peer_stream_id  <= #TCQ {1'b0 /* not a descriptor stream */, 1'b1 /* an input stream */, rx_hdr[64+12+6:64+12]};
                  end else begin
                    state           <= #TCQ PIO_128_RX_RST_STATE;
                  end
                end
              endcase
          end else // not a start of packet
            state <= #TCQ PIO_128_RX_RST_STATE;
        end //PIO_128_RX_RST_STATE
        
      endcase
    end // if
  end // always


  // synthesis translate_off
  reg  [8*20:1] state_ascii;
  always @(state)
  begin
    if      (state==PIO_128_RX_RST_STATE)         state_ascii <= #TCQ "RX_RST_STATE";
    //else if (state==PIO_128_RX_MEM_RD32_DW1DW2)   state_ascii <= #TCQ "RX_MEM_RD32_DW1DW2";
    //else if (state==PIO_128_RX_MEM_WR32_DW1DW2)   state_ascii <= #TCQ "RX_MEM_WR32_DW1DW2";
    //else if (state==PIO_128_RX_MEM_RD64_DW1DW2)   state_ascii <= #TCQ "RX_MEM_RD64_DW1DW2";
    //else if (state==PIO_128_RX_MEM_WR64_DW1DW2)   state_ascii <= #TCQ "RX_MEM_WR64_DW1DW2";
    else if (state==PIO_128_RX_MEM_WR64_DW5)      state_ascii <= #TCQ "RX_MEM_WR64_DW5";
    //else if (state==PIO_128_RX_WAIT_STATE)        state_ascii <= #TCQ "RX_WAIT_STATE";
    //else if (state==PIO_128_RX_IO_WR32_DW1DW2)    state_ascii <= #TCQ "PIO_128_RX_IO_WR32_DW1DW2";
    else                                          state_ascii <= #TCQ "PIO 128 STATE ERR";

  end
  // synthesis translate_on





endmodule // PIO_128_RX_ENGINE

