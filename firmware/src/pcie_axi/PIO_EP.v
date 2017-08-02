//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2010 Xilinx, Inc. All rights reserved.

// Modifications Copyright 2011, Pico Computing, Inc.

`timescale 1ns/1ns

`include "PicoDefines.v"

module PIO_EP #(
    parameter C_DATA_WIDTH = 128,            // RX/TX interface data width

    // Do not override parameters below this line
    parameter STRB_WIDTH = C_DATA_WIDTH / 8               // TSTRB width
    ) (

    input                         clk,
    input                         rst_n,

    // AXIS TX
    input                         s_axis_tx_tready,
    output  [C_DATA_WIDTH-1:0]    s_axis_tx_tdata,
    output  [STRB_WIDTH-1:0]      s_axis_tx_tstrb,
    output                        s_axis_tx_tlast,
    output                        s_axis_tx_tvalid,
    output                        tx_src_dsc,

    //AXIS RX
    input   [C_DATA_WIDTH-1:0]    m_axis_rx_tdata,
    input   [STRB_WIDTH-1:0]      m_axis_rx_tstrb,
    input                         m_axis_rx_tlast,
    input                         m_axis_rx_tvalid,
    output                        m_axis_rx_tready,
    input   [21:0]                m_axis_rx_tuser,

    output                        req_compl_o,
    output                        compl_done_o,
    
    output reg                    cfg_interrupt,
    input                         cfg_interrupt_rdy,

    input   [15:0]                cfg_completer_id,
    input                         cfg_bus_mstr_enable,
    input   [15:0]                cfg_dcommand,
  
    // user-direct writes
    input [127:0]       user_pci_wr_q_data,
    input               user_pci_wr_q_valid,
    output              user_pci_wr_q_en,

    input [127:0]       user_pci_wr_data_q_data,
    input               user_pci_wr_data_q_valid,
    output              user_pci_wr_data_q_en,
    
    output              direct_rx_valid,
    
    // stream signals we're taking to the toplevel for the user
    output              s_clk,
    output              s_rst,
    
    output reg          s_out_en,
    output reg   [8:0]  s_out_id,
    input      [127:0]  s_out_data,
    
    output              s_in_valid,
    output       [8:0]  s_in_id,
    output     [127:0]  s_in_data,
    
    output       [8:0]  s_poll_id,
    input       [31:0]  s_poll_seq,
    input      [127:0]  s_poll_next_desc,
    input               s_poll_next_desc_valid,
    
    output reg   [8:0]  s_next_desc_rd_id,
    output reg          s_next_desc_rd_en
);

localparam verbose = 0;

    // Local wires
    
    reg             send_irq;

    wire  [63:0]      rd_addr;
    wire  [3:0]       rd_be;
    wire  [31:0]      rd_data;

    wire  [63:0]    wr_addr_raw;
    wire  [7:0]     wr_be;
    wire  [31:0]    wr_data_raw;
    wire            wr_en_raw;
    reg   [63:0]    wr_addr;
    reg   [31:0]    wr_data;
    reg             wr_en;

    wire              req_compl;
    wire              req_compl_wd;
    wire              compl_done;

    wire  [2:0]       req_tc;
    wire              req_td;
    wire              req_ep;
    wire  [1:0]       req_attr;
    wire  [9:0]       req_len;
    wire  [15:0]      req_rid;
    wire  [7:0]       req_tag;
    wire  [7:0]       req_be;
    wire  [63:0]      req_addr;
    
    reg             stream_machine_en=1'b0;
    
    reg [31:0]      host_sd_table_a[511:0], host_sd_table_b[511:0], host_sd_table_c[511:0], host_sd_table_d[511:0];
    reg [31:0]      host_sd_table_wr_data;
    reg [3:0]       host_sd_table_wr_en;
    reg [8:0]       host_sd_table_wr_inx;
    
    reg [127:0]     stream_desc_table[511:0];
    reg [31:0]      tx_seq_table[511:0], tx_seq_pre, tx_seq, seq, seq_pre;
    reg [31:0]      rem_seq_table[511:0], rem_seq_pre, rem_seq;
    reg [127:0]     sd, stream_desc_pre, sd_wr_desc;
    reg [8:0]       stream_desc_inx, stream_desc_inx_q, stream_desc_inx_qq, sd_inx, sd_wr_inx;
    wire [8:0]      stream_inx_mask = 10'hf;
    reg [127:0]     next_desc_pre, next_desc;
    reg             sd_wr_en;
    
    reg [127:0]     istream_desc_table[511:0];
    reg [31:0]      iseq_cache_table[511:0], iseq_cache_table_wr_data;
    reg [31:0]      itx_seq_cache_table[511:0], itx_seq_cache_table_wr_data;
    reg [31:0]      irem_seq_cache_table[511:0], irem_seq_cache_table_wr_data;
    reg [19:0]      len_cache_table[511:0], len_cache_table_wr_data;
    reg [127:0]     isd_cache_table[511:0], isd_cache_table_wr_data;
    reg [8:0]       iseq_cache_table_wr_inx;
    reg             iseq_cache_table_wr_en;
    reg [31:0]      itx_seq_table[511:0], itx_seq_p5, itx_seq_p4, itx_seq_p3, itx_seq_pp, itx_seq_pre, itx_seq, iseq_p3, iseq, iseq_pp, iseq_pre, itx_seq_table_wr_data;
    reg [8:0]       itx_seq_table_wr_inx;
    reg             itx_seq_table_wr_en;
    reg [31:0]      irem_seq_table[511:0], irem_seq_p5, irem_seq_p4, irem_seq_p3, irem_seq_pp, irem_seq_pre, irem_seq, irem_seq_table_wr_data = 0, irem_seq_table_wr_data_p = 0;
    reg [8:0]       irem_seq_table_wr_inx_p = 0, irem_seq_table_wr_inx = 0;
    reg             irem_seq_table_wr_en_p = 0, irem_seq_table_wr_en = 0, rem_seq_wr_en;
    reg [127:0]     isd, isd_p, istream_desc_p3, istream_desc_pp, isd_wr_desc, istream_host_desc_p4, istream_host_desc_p3, istream_host_desc_pp;
    reg [8:0]       istream_table_inx=9'h0, istream_desc_inx_p9, istream_desc_inx_p8, istream_desc_inx_p7, istream_desc_inx_p6, istream_desc_inx_p5, istream_desc_inx_p4, istream_desc_inx_p3, istream_desc_inx_pp, isd_inx_p, isd_inx, isd_wr_inx;
    reg [8:0]       istream_table_inx_q, istream_table_inx_qq;
    reg [8:0]       istream_inx_mask = 9'h3f;
    reg [127:0]     inext_desc_p3, inext_desc_pp, inext_desc_pre, inext_desc;
    reg             isd_wr_en;
    reg             inext_desc_valid_p3, inext_desc_valid_pp, inext_desc_valid_pre, inext_desc_valid;
    
    reg [31:0]      seq_push_addr_table_lo[511:0];
    reg [15:0]      seq_push_addr_table_hi[511:0];
    reg [47:0]      seq_push_addr_pp, seq_push_addr_p, seq_push_addr;
    reg [8:0]       seq_push_addr_wr_inx;
    reg [1:0]       seq_push_addr_wr_en;
    reg [31:0]      seq_push_addr_wr_data;
    
    // we cache the last seq we sent to our peer, so that we don't send updates too often. the size of this table could
    //   be trimmed down a lot, but I think it already fits in a single bram.
    reg [17:0]      last_rpt_seq_peer_table[511:0], last_rpt_seq_peer_p3, last_rpt_seq_peer_pp, last_rpt_seq_peer_p, last_rpt_seq_peer, last_rpt_seq_peer_wr_data;
    reg             last_rpt_seq_peer_wr_en;
    reg [8:0]       last_rpt_seq_peer_wr_inx;
    
    reg             do_fetch, do_rollover, do_rd, do_wr, do_rpt_seq, do_rpt_seq_peer;
    
    reg [127:0]     iwr_q_in;
    reg             iwr_q_in_rdy, iwr_q_q;
    wire            iwr_q_almost_full, iwr_q_deq, iwr_q_empty;
    wire [127:0]    iwr_q_out;
    
    reg [127:0]     iwr_wr_q_in;
    reg             iwr_wr_q_in_rdy, iwr_wr_q_q, iwr_wr_q_deq;
    wire            iwr_wr_q_almost_full, iwr_wr_q_empty;
    wire [127:0]    iwr_wr_q_out;
    
    reg [127:0]     iwr_wr_postdata_q_in;
    reg             iwr_wr_postdata_q_in_rdy, iwr_wr_postdata_q_q;
    wire            iwr_wr_postdata_q_almost_full, iwr_wr_postdata_q_deq, iwr_wr_postdata_q_empty;
    wire [127:0]    iwr_wr_postdata_q_out;
    
    wire [127:0]    wr_data_q_in;
    reg             wr_data_q_in_rdy, wr_data_q_q;
    wire            wr_data_q_almost_full, wr_data_q_deq, wr_data_q_empty;
    wire [127:0]    wr_data_q_out;
    
    reg [63:0]      wr_addr_q, rd_addr_q;
    reg [31:0]      wr_data_q;
    reg [31:0]      rd_data_reg, rd_misc_reg, rd_misc_reg_q;
    reg             wr_en_q;
    
    reg [31:11]     addr_window;
    
    wire [7:0]      last_tx_cpld_tag, cpld_outstanding;
    reg [7:0]       max_cpld_outstanding;
    reg             tx_rd_req_ok;
    
    reg [11:0]  read_log [255:0];
    wire [11:0] read_log_wr_data;
    reg [11:0]  read_log_rd_data, read_log_rd_data_q;
    wire [7:0]  read_log_rd_inx, read_log_wr_inx;
    wire        read_log_wr_en;
    wire [7:0]  next_rd_tag;
    reg  [7:0]  next_rd_tag_q;
    wire        next_rd_tag_en, rd_tag_fifo_almost_empty, rd_tag_fifo_full;
    wire        last_cpld_tag_valid;
    wire [7:0]  last_cpld_tag;
    reg  [7:0]  rd_tag_fifo_din, rd_tag_fifo_init_din;
    reg         rd_tag_fifo_wr_en=0, rd_tag_fifo_init_en=0, rd_tag_fifo_init_done=0, rd_tag_fifo_rst_done=0;
    
    reg [8:0]   istream_inx_map_table[511:0];
    reg [8:0]   istream_inx_map_table_wr_inx, istream_inx_map_table_wr_data;
    reg         istream_inx_map_table_wr_en;
    assign s_poll_id = istream_desc_inx_p5;
    
    reg [127:0] s_out_data_q;
    reg         s_out_en_q, s_out_en_pre;
    reg [8:0]   s_out_id_pre;
    
    // ease the timing and remove the inversion on rst_n.
    // the signal we'll use will be assigned to the wire rst_q. (which will be assigned to s_rst.)
    reg rst_q1, rst_q2, rst_q3;
    wire rst_q = rst_q3;
    always @(posedge clk) begin
        rst_q1 <= ~rst_n;
        rst_q2 <= rst_q1;
        rst_q3 <= rst_q2;
    end
    
    // send out interrupt requests
    always @(posedge clk) begin
        if (cfg_interrupt_rdy)
            cfg_interrupt <= 0;
        else if (send_irq)
            cfg_interrupt <= 1;
    end
    
    assign s_clk = clk;
    assign s_rst = rst_q;
    
    always @(posedge clk) begin
        if (read_log_wr_en)
            read_log[read_log_wr_inx] <= read_log_wr_data;
        read_log_rd_data    <= read_log[read_log_rd_inx];
        read_log_rd_data_q  <= read_log_rd_data;
    end


    wire   tag_init_done ;

    TagFIFO tag_fifo_i (
      .clk               (clk)   ,
      .rst               (rst_q) ,
      // fifo input
      .tag_in            (last_cpld_tag)            ,         // last_cpld_tag
      .tag_in_valid      (last_cpld_tag_valid)      ,         // last_cpld_tag_valid 
      // fifo output
      .tag_out           (next_rd_tag)              ,
      .tag_out_valid     (),
      // flow control
      .tag_out_rdy       (next_rd_tag_en)           ,         // read signal
      .tag_almost_empty  (rd_tag_fifo_almost_empty) ,
      .tag_init_done     (tag_init_done)                 // register output
    );

    reg rem_seq_fifo_wr_en = 0;
    reg [32+8:0] rem_seq_fifo_din = 0;
    wire rem_seq_fifo_rd_en;
    wire [71:0] rem_seq_fifo_dout;
    wire rem_seq_fifo_empty;

    coregen_fifo_32x128 rem_seq_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(rem_seq_fifo_din),
        .wr_en(rem_seq_fifo_wr_en),
        .rd_en(rem_seq_fifo_rd_en),
        .dout(rem_seq_fifo_dout),
        .empty(rem_seq_fifo_empty)
    );
    assign rem_seq_fifo_rd_en = (istream_desc_inx_p8 != rem_seq_fifo_dout[32+8:32]) & ~rem_seq_fifo_empty;

//    /*FIFO_SYNC_MACRO #(
//        .DEVICE("VIRTEX6"),
//        .ALMOST_EMPTY_OFFSET(9'h010),
//        .ALMOST_FULL_OFFSET(9'h080),
//        .DATA_WIDTH(8),
//        .DO_REG(0),
//        .FIFO_SIZE("18Kb")
//    ) rd_tag_fifo (
//        .CLK(clk),
//        .RST(rst_q),
//        .WREN(rd_tag_fifo_wr_en),
//        .DI(rd_tag_fifo_din),
//        .RDEN(next_rd_tag_en),
//        .DO(next_rd_tag),
//        //.EMPTY(),
//        //.FULL()
//        .ALMOSTEMPTY(rd_tag_fifo_almost_empty),//1-bitoutputalmostempty
//        //.ALMOSTFULL(ALMOSTFULL)//1,-bitoutputalmostfull
//        //.RDCOUNT(RDCOUNT),
//        //.RDERR(RDERR),
//        //.WRCOUNT(WRCOUNT),
//        //.WRERR(WRERR),
//    );*/
//    wire [31:0] rd_tag_fifo_do;
//    assign next_rd_tag = rd_tag_fifo_do[7:0];
//    FIFO18E1 #(
//        .ALMOST_EMPTY_OFFSET(9'h010),
//        .ALMOST_FULL_OFFSET(9'h080),
//        .DATA_WIDTH(9),
//        .DO_REG(1), // Enable output register (0 or 1) Must be 1 if EN_SYN = "FALSE"
//        //.EN_ECC_READ("FALSE"), // Enable ECC decoder, "TRUE" or "FALSE"
//        //.EN_ECC_WRITE("FALSE"), // Enable ECC encoder, "TRUE" or "FALSE"
//        .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE") or Synchronous ("TRUE")
//        .FIFO_MODE("FIFO18"), // Sets mode to FIFO36 or FIFO36_72
//        .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
//    ) rd_tag_fifo (
//        .RDCLK(clk),
//        .WRCLK(clk),
//        .RST(rst_q),
//        .WREN(rd_tag_fifo_wr_en),
//        .DI({24'h0, rd_tag_fifo_din}),
//        .RDEN(next_rd_tag_en),
//        .DO(rd_tag_fifo_do),
//        //.EMPTY(),
//        .FULL(rd_tag_fifo_full),
//        .ALMOSTEMPTY(rd_tag_fifo_almost_empty)//1-bitoutputalmostempty
//        //.ALMOSTFULL(ALMOSTFULL)//1,-bitoutputalmostfull
//        //.RDCOUNT(RDCOUNT),
//        //.RDERR(RDERR),
//        //.WRCOUNT(WRCOUNT),
//        //.WRERR(WRERR),
//    );
    
    //assign cpld_outstanding = last_tx_cpld_tag-last_rx_cpld_tag;
    always @(posedge clk) begin
        // we have to use the tags rather than simply count the requests and cplds, since we don't know how many
        //   cplds the completer will use to fill a request.
        // beware the latency in this signal. it takes at least a few cycles for us to know the tx engine sent a new
        //   request, and it can make requests back to back, so leave enough slack in the read_log to absorb the few
        //   cycles it takes for us to stop to tx engine.
        //tx_rd_req_ok    <= cpld_outstanding <= max_cpld_outstanding;
        // this is the new, fifo-based way of doing this
        tx_rd_req_ok    <= ~rd_tag_fifo_almost_empty;

//        rd_tag_fifo_wr_en   <= last_cpld_tag_valid | rd_tag_fifo_init_en;
//        rd_tag_fifo_din     <= last_cpld_tag | rd_tag_fifo_init_din;

        next_rd_tag_q       <= next_rd_tag ;
    end
    
    fifo_512x128 iwr_q_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(iwr_q_in),
        .wr_en(iwr_q_q),
        .rd_en(iwr_q_deq),
        .dout(iwr_q_out),
        .empty_direct(iwr_q_empty),
        .prog_full(iwr_q_almost_full)
    );
    always @(posedge clk) begin
        iwr_q_in_rdy <= ~iwr_q_almost_full;
    end
    
    // write commands before we've gathered their data from the stream.
    fifo_512x128 iwr_wr_q_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(iwr_wr_q_in),
        .wr_en(iwr_wr_q_q),
        .rd_en(iwr_wr_q_deq),
        .dout(iwr_wr_q_out),
        .empty(iwr_wr_q_empty),
        .prog_full(iwr_wr_q_almost_full)
    );
    always @(posedge clk) begin
        iwr_wr_q_in_rdy <= ~iwr_wr_q_almost_full;
    end
    
    // write commands after we've gathered their data from the stream.
    fifo_512x128 iwr_wr_postdata_q_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(iwr_wr_postdata_q_in),
        .wr_en(iwr_wr_postdata_q_q),
        .rd_en(iwr_wr_postdata_q_deq),
        .dout(iwr_wr_postdata_q_out),
        .empty(iwr_wr_postdata_q_empty),
        .prog_full(iwr_wr_postdata_q_almost_full)
    );
    always @(posedge clk) begin
        iwr_wr_postdata_q_in_rdy <= ~iwr_wr_postdata_q_almost_full;
    end
    
    // the actual data to be written.
    // we need to make sure almost_full goes true early enough for the biggest possible packet,
    //   or we'll chop off its tail.
    fifo_512x128 #(.ALMOST_FULL_OFFSET(13'h100)) wr_data_q_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(wr_data_q_in),
        .wr_en(wr_data_q_q),
        .rd_en(wr_data_q_deq),
        .dout(wr_data_q_out),
        .empty(wr_data_q_empty),
        .prog_full(wr_data_q_almost_full)
    );
    always @(posedge clk) begin
        wr_data_q_in_rdy <= ~wr_data_q_almost_full;
    end
    
    // machinery to gather the data for the queued writes.
    // after the data's gathered, we'll move the write command from the iwr_wr_q queue to the iwr_wr_postdata_q.
    reg [19:0]      stream_reader_len;
    assign wr_data_q_in[127:0] = s_out_data_q[127:0];
    localparam STREAM_READER_RST    = 2'b01;
    localparam STREAM_READER_READ   = 2'b10;
    reg [1:0] stream_reader_state;
    reg iwr_wr_q_deq_q;
    always @(posedge clk) begin
        wr_data_q_q         <= s_out_en_q; // there's a one-cycle lag between s_out_en and the data coming back valid. we're adding another pipeline stage
        s_out_en_q          <= s_out_en;
        s_out_data_q        <= s_out_data[127:0];
        s_out_en            <= s_out_en_pre;
        s_out_id            <= s_out_id_pre;
        
        if (rst_q) begin
            s_out_en_pre        <= 0;
            stream_reader_state <= STREAM_READER_RST;
        end else begin
            iwr_wr_q_deq        <= 0;
            iwr_wr_q_deq_q      <= iwr_wr_q_deq;
            iwr_wr_postdata_q_q <= 0;
            
            case (stream_reader_state)
                STREAM_READER_RST : begin
                    // tighten up by not needing cycle for iwr_wr_q_deq to take effect.
                    if (~iwr_wr_q_deq && ~iwr_wr_q_deq_q && ~iwr_wr_q_empty && ~iwr_wr_postdata_q_almost_full && ~wr_data_q_almost_full) begin
                        s_out_en_pre    <= 1;
                        s_out_id_pre    <= iwr_wr_q_out[104:96];
                        stream_reader_len   <= iwr_wr_q_out[19:0];
                        stream_reader_state <= STREAM_READER_READ;
                        if (verbose) $display("%0t: stream reader starting on 0x%x_0x%x_0x%x_0x%x", $time, iwr_wr_q_out[127:96], iwr_wr_q_out[95:64], iwr_wr_q_out[63:32], iwr_wr_q_out[31:0]);
                    end
                end
                
                STREAM_READER_READ : begin
                    if (stream_reader_len == 20'h10) begin
                        s_out_en_pre            <= 0;
                        iwr_wr_q_deq            <= 1;
                        //TODO unless we allow variable latency acks from the streams for data delivery, we should be able to
                        //  forward this write command as soon as the first piece of data arrives, rather than waiting for all of it.
                        //  for a 4kB write, this is 256 cycles, or a whole microsecond!!
                        iwr_wr_postdata_q_q     <= 1;
                        iwr_wr_postdata_q_in    <= iwr_wr_q_out;
                        stream_reader_state     <= STREAM_READER_RST; // this could be tightened up to pull off the next command if available and stay in this state.
                    end else begin
                        stream_reader_len       <= stream_reader_len - 20'h10;
                    end
                end
            endcase
        end
    end
    
    // stream orchestrator
    localparam ISTREAM_STATE_CLEAR  = 2'b01;
    localparam ISTREAM_STATE_RUN    = 2'b10;
    reg [1:0]   istream_state       = ISTREAM_STATE_CLEAR;
    //          addr wrap size is isd[85:0]
    wire        isd_rpt_seq_p       = isd_p[86];
    wire        isd_rd_p            = isd_p[87];
    wire        isd_rollover_p      = isd_p[88];
    //          irq is isd[89]
    wire        isd_rpt_seq_peer_p  = isd_p[90];
    wire [19:0] isd_len_p           = isd_p[19:0];
    wire [19:0] isd_len             = isd[19:0], isd_len_minus = isd_len-burst_size;
    wire        isd_rpt_seq         = isd[86];
    wire        isd_irq             = isd[89];
    reg [31:0]      isd_seq_diff_local_p, isd_seq_diff_local_pp;
    reg [31:0]      isd_seq_diff_remote_p, isd_seq_diff_remote_pp;
    reg [31:0]      isd_seq_diff_max_p;
    reg [31:0]      seq_diff_local_p, seq_diff_local, seq_diff_remote_p, seq_diff_remote;
    reg [31:0]      burst_size;
    // isd_addr_mask specifies which bits come from isd_addr+1, and which are just copied from isd_addr with no addition.
    // for example, a value of 12 (0xc) means the bottom 12 bits count.
    wire [47:0] isd_addr_mask = (isd[85:80] == 6'hc) ? {{36{1'b0}},{12{1'b1}}} : {48{1'b1}};
    wire [47:0] isd_addr = isd[47+32:0+32], isd_addr_plus_unmask = isd_addr+burst_size;
    wire [47:0] isd_addr_plus = (isd_addr & ~isd_addr_mask) | (isd_addr_plus_unmask & isd_addr_mask);
    // we don't want to generate a bunch of tiny write packets that'll burn header credits, so wait
    //   till we have a good sized chunk (or are at the end of the descriptor).
    // we exempt "rollover" descriptors since they're generally used for things that want this.
    wire        min_wr_burst_ok_p = (isd_rollover_p || (isd_seq_diff_max_p >= 32'h1000) || (isd_seq_diff_max_p[19:0] >= isd_len_p[19:0]));
    wire        min_rd_burst_ok_p = (isd_rollover_p || (isd_seq_diff_max_p >= 32'h1000) || (isd_seq_diff_max_p[19:0] >= isd_len_p[19:0]));
    //TODO make sure this doesn't hang peer-to-peer. probably need to add another flag bit to the descriptor.
    
    always @(posedge clk) begin
        
        isd_wr_en   <= 0;
        if (isd_wr_en)
            istream_desc_table[isd_wr_inx]    <= isd_wr_desc;
        
        itx_seq_table_wr_en <= 0;
        if (itx_seq_table_wr_en)
            itx_seq_table[itx_seq_table_wr_inx] <= itx_seq_table_wr_data;
        
        rem_seq_fifo_wr_en <= 0;
        irem_seq_table_wr_en_p <= 0;
        irem_seq_table_wr_en <= 0;
        if (irem_seq_table_wr_en)
            irem_seq_table[irem_seq_table_wr_inx]   <= irem_seq_table_wr_data;
        
        host_sd_table_wr_en[3:0] <= 4'h0;
        if (host_sd_table_wr_en[0]) host_sd_table_a[host_sd_table_wr_inx] <= host_sd_table_wr_data;
        if (host_sd_table_wr_en[1]) host_sd_table_b[host_sd_table_wr_inx] <= host_sd_table_wr_data;
        if (host_sd_table_wr_en[2]) host_sd_table_c[host_sd_table_wr_inx] <= host_sd_table_wr_data;
        if (host_sd_table_wr_en[3]) host_sd_table_d[host_sd_table_wr_inx] <= host_sd_table_wr_data;
        
        seq_push_addr_wr_en <= 2'b0;
        if (seq_push_addr_wr_en[0]) seq_push_addr_table_lo[seq_push_addr_wr_inx]    <= seq_push_addr_wr_data[31:0];
        if (seq_push_addr_wr_en[1]) seq_push_addr_table_hi[seq_push_addr_wr_inx]    <= seq_push_addr_wr_data[15:0];
        
        last_rpt_seq_peer_wr_en <= 0;
        if (last_rpt_seq_peer_wr_en)
            last_rpt_seq_peer_table[last_rpt_seq_peer_wr_inx]   <= last_rpt_seq_peer_wr_data;
        
        istream_inx_map_table_wr_en    <= 0;
        if (istream_inx_map_table_wr_en)
            istream_inx_map_table[istream_inx_map_table_wr_inx]   <= istream_inx_map_table_wr_data;
        
        // cache sequence number, etc for host readback.
        iseq_cache_table_wr_en      <= 1;
        iseq_cache_table_wr_inx     <= isd_inx[8:0];
        iseq_cache_table_wr_data    <= iseq;
        itx_seq_cache_table_wr_data <= itx_seq;
        irem_seq_cache_table_wr_data<= irem_seq;
        len_cache_table_wr_data     <= isd_len[19:0];
        isd_cache_table_wr_data     <= isd[127:0];
        if (iseq_cache_table_wr_en) begin
            iseq_cache_table[iseq_cache_table_wr_inx]       <= iseq_cache_table_wr_data;
            itx_seq_cache_table[iseq_cache_table_wr_inx]    <= itx_seq_cache_table_wr_data;
            len_cache_table[iseq_cache_table_wr_inx]        <= len_cache_table_wr_data;
            isd_cache_table[iseq_cache_table_wr_inx]        <= isd_cache_table_wr_data;
            irem_seq_cache_table[iseq_cache_table_wr_inx]   <= irem_seq_cache_table_wr_data;
        end
        
        iwr_q_q             <= 0;
        iwr_wr_q_q          <= 0;
        s_next_desc_rd_en   <= 0;
        
        isd_seq_diff_local_pp   <= iseq_p3 - itx_seq_p3;
        isd_seq_diff_remote_pp  <= irem_seq_p3 - itx_seq_p3;
        isd_seq_diff_local_p    <= isd_seq_diff_local_pp;
        isd_seq_diff_remote_p   <= isd_seq_diff_remote_pp;
        
        isd_seq_diff_max_p <= ((~isd_seq_diff_local_pp[31] && ~isd_seq_diff_remote_pp[31] && isd_seq_diff_local_pp < isd_seq_diff_remote_pp)
            || (~isd_seq_diff_local_pp[31] && isd_seq_diff_remote_pp[31])) ? isd_seq_diff_local_pp :
                ((~isd_seq_diff_remote_pp[31]) ? isd_seq_diff_remote_pp : 32'h0);
        
        if (isd_seq_diff_max_p < {12'h0, isd_len_p[19:0]})
            burst_size  <= isd_seq_diff_max_p;
        else
            burst_size  <= isd_len_p;
        
        seq_diff_local      <= isd_seq_diff_local_p;
        seq_diff_remote     <= isd_seq_diff_remote_p;
        
        // these statements could be rewritten to use the precise length values we now have. (seq_diff regs)
        do_fetch        <= ((isd_len_p == 20'h0) && ~isd_rollover_p && ~isd_rpt_seq_p && inext_desc_valid_pre /*(inext_desc[19:0] != 20'h0)*/);
        do_rd           <=  isd_rd_p && (iwr_q_in_rdy    /* off by a cycle */ && (isd_len_p != 20'h0) && (itx_seq_pre != iseq_pre) && (itx_seq_pre != irem_seq_pre)) && min_rd_burst_ok_p;
        do_wr           <= ~isd_rd_p && (iwr_wr_q_in_rdy /* off by a cycle */ && (isd_len_p != 20'h0) && (itx_seq_pre != iseq_pre) && (itx_seq_pre != irem_seq_pre)) && min_wr_burst_ok_p;
        do_rpt_seq      <= (isd_len_p == 20'h0) && isd_rpt_seq_p;
        do_rpt_seq_peer <= isd_rpt_seq_peer_p && (last_rpt_seq_peer_p[17:0] != iseq_pre[27:10]);
        do_rollover     <= (isd_len_p == 20'h0) && isd_rollover_p;
        
        send_irq        <= 0;
            
        // the huge manually-built pipeline here serves several purposes:
        //   1) provide pipeline registers for the brams we want inferred. make sure you leave enough 'pass-through' regs right after the array lookup to allow this.
        //   2) to manually push decision logic (comparisons, etc) back in the pipeline so we're not comparing every at the last minute in one cycle.
        // send stream_desc_inx to the streams, and keep track of the old indices to place alongside the data when it arrives.
        istream_desc_inx_p9 <= istream_inx_map_table[(istream_table_inx + 1) & istream_inx_mask]; // clumsy, and potential timing problem ...
        istream_desc_inx_p8 <= istream_desc_inx_p9;
        istream_desc_inx_p7 <= istream_desc_inx_p8;
        istream_desc_inx_p6 <= istream_desc_inx_p7;
        istream_desc_inx_p5 <= istream_desc_inx_p6;
        istream_desc_inx_p4 <= istream_desc_inx_p5;
        istream_desc_inx_p3 <= istream_desc_inx_p4;
        istream_desc_inx_pp <= istream_desc_inx_p3;
        // isd is the stream descriptor. isd_inx is its index.
        // we could change the OR-ing together here to allow the host to truly replace descriptors.
        //   (as is, any changes from the host will be OR-ed in and probably result in garbage.)
        // xst is hopeless at pushing regs into the inferred bram for host_sd_table_*. probably because it's four separate verilog arrays)
        //   this makes it the worst timing point in the base firmware!
        istream_desc_p3     <= istream_desc_table[istream_desc_inx_p4];
        istream_desc_pp     <= istream_desc_p3;
        istream_host_desc_p4<= {host_sd_table_d[istream_desc_inx_p5], host_sd_table_c[istream_desc_inx_p5], host_sd_table_b[istream_desc_inx_p5], host_sd_table_a[istream_desc_inx_p5]};
        istream_host_desc_p3<= istream_host_desc_p4;
        istream_host_desc_pp<= istream_host_desc_p3;
        isd_p               <= istream_desc_pp | istream_host_desc_pp;
        isd                 <= isd_p;
        isd_inx_p           <= istream_desc_inx_pp;
        isd_inx             <= isd_inx_p;
        // irem_seq is the remote sequence position, which we can't pass. this may be from the host or a peer.
        irem_seq_p5         <= irem_seq_table[istream_desc_inx_p6];
        irem_seq_p4         <= irem_seq_p5;
        irem_seq_p3         <= irem_seq_p4;
        irem_seq_pp         <= irem_seq_p3;
        irem_seq_pre        <= irem_seq_pp;
        irem_seq             <= irem_seq_pre;
        // itx_seq is the sequence position of the last piece of data we've decided to move.
        //   (note that this data/request may still be in the fpga in a queue.)
        // for incoming streams, it must be <= iseq and <= irem_seq.
        // for outgoing streams, it must be <= iseq and <= irem_seq.
        itx_seq_p5          <= itx_seq_table[istream_desc_inx_p6];
        itx_seq_p4          <= itx_seq_p5;
        itx_seq_p3          <= itx_seq_p4;
        itx_seq_pp          <= itx_seq_p3;
        itx_seq_pre         <= itx_seq_pp;
        itx_seq              <= itx_seq_pre;
        // seq_push_addr is the address we report (push) our sequence number updates to. optionally null.
        seq_push_addr_pp    <= {seq_push_addr_table_hi[istream_desc_inx_p3][15:0],
                                seq_push_addr_table_lo[istream_desc_inx_p3][31:0]};
        seq_push_addr_p     <= seq_push_addr_pp;
        seq_push_addr       <= seq_push_addr_p;
        // last_rpt_seq_peer is the last seq we sent to our peer, if we're receiving data from a peer stream.
        last_rpt_seq_peer_p3<= last_rpt_seq_peer_table[istream_desc_inx_p4][17:0];
        last_rpt_seq_peer_pp<= last_rpt_seq_peer_p3;
        last_rpt_seq_peer_p <= last_rpt_seq_peer_pp;
        last_rpt_seq_peer   <= last_rpt_seq_peer_p;
        // inext_desc is the next descriptor available, which we may or may not need right now.
        // if we do need it, we'll latch it and assert s_next_desc_rd_en.
        inext_desc_valid_p3     <= s_poll_next_desc_valid;
        inext_desc_valid_pp     <= inext_desc_valid_p3;
        inext_desc_valid_pre    <= inext_desc_valid_pp;
        inext_desc_valid        <= inext_desc_valid_pre;
        inext_desc_p3           <= s_poll_next_desc;
        inext_desc_pp           <= inext_desc_p3;
        inext_desc_pre          <= inext_desc_pp;
        inext_desc              <= inext_desc_pre;
        // iseq is the "internal" sequence position of the stream.
        // ie, this is _our_ constraint on the stream, versus irem_seq, which is our peer's constraint.
        iseq_p3             <= s_poll_seq;
        iseq_pp             <= iseq_p3;
        iseq_pre            <= iseq_pp;
        iseq                <= iseq_pre;

//        rd_tag_fifo_init_din    <= 8'h0;
        
        
        
        if (do_fetch) begin
            // load the next descriptor if we need one and it's available.
            // (checking two 20b values here is pretty heavy. we could just use 1b regs to track this info.)
            // (and we could load the next descriptor as we fire off the last packet from the old one, if it's ready.)
            if (verbose) $display("%0t: loading new isd descriptor for index 0x%x: 0x%x_0x%x_0x%x_0x%x", $time, isd_inx, inext_desc[127:96], inext_desc[95:64], inext_desc[63:32], inext_desc[31:0]);
            isd_wr_en    <= 1;
            isd_wr_desc  <= inext_desc;
            isd_wr_inx   <= isd_inx;
            // tell the descriptor fifo we read the head, and it should advance.
            s_next_desc_rd_en    <= 1;
            s_next_desc_rd_id   <= isd_inx;
        end else if (do_rollover) begin
            //TODO this code assumes the rollover is set to 12 bits, thus the size is reset to 4kB.
            //     flesh this out if we support other values later.
            isd_wr_en   <= 1;
            isd_wr_desc <= {isd[127:32], /*isd_addr_plus[47:0],*/ 12'h0, 20'h1000};
            isd_wr_inx  <= isd_inx;
        end else if (do_rd) begin
            // fire off a read request.
            //$display("%0t: burst_size:0x%x, seq_diff_local:0x%x, seq_diff_remote:0x%x", $time, burst_size, seq_diff_local, seq_diff_remote);
            if (verbose) $display("%0t: sending read req. isd_inx:0x%x, isd_len:0x%x, itx_seq:0x%x, iseq:0x%x, irem_seq:0x%x", $time, isd_inx, isd_len, itx_seq, iseq, irem_seq);
            // update the descriptor
            isd_wr_en            <= 1;
            isd_wr_desc[127:0]   <= {isd[127:80], isd_addr_plus[47:0], 12'h0, isd_len_minus[19:0]};
            isd_wr_inx           <= isd_inx;
            // update itx_seq_table
            itx_seq_table_wr_en     <= 1;
            itx_seq_table_wr_data   <= itx_seq + burst_size;
            itx_seq_table_wr_inx    <= isd_inx;
            // queue the read request
            iwr_q_q      <= 1;
            iwr_q_in     <= {// 127:96
                            20'h0,
                            1'b1,   // read
                            1'b0, //isd[127],
                            1'b0, isd_inx[8:0],   // stream number
                            // 95:32
                            16'h0,
                            isd[79:32],     // paddr (48b)
                            // 31:0
                            12'h0,
                            burst_size[19:0]};        // byte count
        end else if (do_wr) begin
            // fire off a write.
            //$display("burst_size: 0x%x", burst_size);
            if (verbose) $display("%0t: sending write. isd_inx:0x%x, isd_len:0x%x, itx_seq:0x%x, iseq:0x%x, irem_seq:0x%x", $time, isd_inx, isd_len, itx_seq, iseq, irem_seq);
            // update the descriptor
            isd_wr_en            <= 1;
            isd_wr_desc[127:0]   <= {isd[127:80], isd_addr_plus[47:0], 12'h0, isd_len_minus[19:0]};
            isd_wr_inx           <= isd_inx;
            // update itx_seq_table
            itx_seq_table_wr_en     <= 1;
            itx_seq_table_wr_data   <= itx_seq + burst_size;
            itx_seq_table_wr_inx    <= isd_inx;
            // queue the write
            iwr_wr_q_q  <= 1;
            iwr_wr_q_in <= {// 127:96
                            20'h0,
                            1'b0,   // read
                            1'b1, //isd[127],
                            1'b0, isd_inx[8:0],   // stream number
                            // 95:32
                            16'h0,
                            isd[79:32],     // paddr (48b)
                            // 31:0
                            12'h0,
                            burst_size[19:0]};//20'h10};        // byte count
        end else if (do_rpt_seq) begin
            if (verbose) $display("%0t: reporting sequence number of stream 0x%x to addr 0x%x. value: 0x%x", $time, isd_inx, seq_push_addr, itx_seq);
            // update the descriptor
            isd_wr_en            <= 1;
            isd_wr_desc[127:0]   <= {isd[127:87], 1'b0, isd[85:0]}; // knock out the rpt_seq bit (86th bit)
            isd_wr_inx           <= isd_inx;
            // send an interrupt (there's no reason this has to be done at the same time as sequence reporting)
            if (isd_irq)
                send_irq <= 1;
            // queue the write
            iwr_q_q      <= 1;
            iwr_q_in     <= {// 127:96
                            20'h0,
                            1'b0,   // write
                            1'b0, //isd[127],
                            10'h0, //isd_inx[9:0],   // stream number
                            // 95:32
                            16'h0,
                            seq_push_addr[47:0],     // paddr (48b)
                            // 31:0
                            itx_seq[31:0]}; // literal 32b to write
        end else if (do_rpt_seq_peer) begin
            // note the value we're sending to our peer. we'll check it to avoid updating them too often.
            last_rpt_seq_peer_wr_en     <= 1;
            last_rpt_seq_peer_wr_data   <= iseq[27:10];
            last_rpt_seq_peer_wr_inx    <= isd_inx;
            // queue the write
            iwr_q_q      <= 1;
            iwr_q_in     <= {// 127:96
                            20'h0,
                            1'b0,   // write
                            1'b0, //isd[127],
                            10'h0, //isd_inx[9:0],   // stream number
                            // 95:32
                            16'h0,
                            seq_push_addr[47:0],     // paddr (48b)
                            // 31:0
                            iseq[31:0]}; // literal 32b to write
        end

        if (rst_q) begin
	    // on startup, we actually go into the ISTREAM_STATE_CLEAR state
	    // before seeing reset.  thus it's critical to clear the rd_tag_fifo
	    // enable when we go into reset so that we don't write the first tag
	    // (0) twice.
//	    rd_tag_fifo_init_en     <= 0;
	    // make sure we don't write to the fifo when we temporarily jump
	    // into the "clear" state prior to getting the reset.
//	    rd_tag_fifo_rst_done    <= 1;
	    // also, when we finally hit the ISTREAM_STATE_CLEAR state "for
	    // real," istream_table_inx will start at 2, rather than 0.  that
	    // means we'll miss adding the tags "0" and "1", but that's probably
	    // better than stressing the istream_table_inx with a reset, which
	    // is the only straightforward alternative.
	    // this line makes us able to handle repeated resets. for example,
	    // if we come up at power-on, and then the bios POST does a reset.
	    // (this is why we used to have problems with putting 5.x firmware
	    // on the cards, and they required a reload before they were sane.)
//	    rd_tag_fifo_init_done   <= 0;
        end else begin
            
          case (istream_state)
            ISTREAM_STATE_CLEAR : begin
                istream_table_inx <= istream_table_inx + 1;
                if (stream_machine_en && (istream_table_inx == 9'h1ff) && tag_init_done)
                    istream_state    <= ISTREAM_STATE_RUN;
                
                isd_wr_en   <= 1;
                isd_wr_inx  <= istream_table_inx;
                isd_wr_desc <= 128'h0;
                
                itx_seq_table_wr_en     <= 1;
                itx_seq_table_wr_inx    <= istream_table_inx;
                itx_seq_table_wr_data   <= 32'h0;
                
                irem_seq_table_wr_en    <= 1;
                irem_seq_table_wr_inx   <= istream_table_inx;
                irem_seq_table_wr_data  <= 32'h0;
                
                host_sd_table_wr_inx    <= istream_table_inx;
                host_sd_table_wr_data   <= 32'h0;
                host_sd_table_wr_en     <= 4'hf;
                
                seq_push_addr_wr_en     <= 2'b11;
                seq_push_addr_wr_inx    <= istream_table_inx;
                seq_push_addr_wr_data   <= 48'h0;
                
                istream_inx_map_table_wr_en    <= 1;
                istream_inx_map_table_wr_inx   <= istream_table_inx;
                // IMPORTANT: note that the filler value in the inx map table cannot be used as a stream, or that stream
                //   will get hit on every unused entry in the map table, which will cause errors, even if its descriptor is valid.
                //   (since due to the latency of updating all the tables, you can't access a stream every cycle.)
                istream_inx_map_table_wr_data  <= 9'h0;//(istream_table_inx == 10'h1) ? 10'h0 : 10'h3ff; // just using an unlikely value

                // stuff the read tag fifo with all possible tags
//                rd_tag_fifo_init_din    <= istream_table_inx[7:0];
//                rd_tag_fifo_init_en     <= rd_tag_fifo_rst_done & ~rd_tag_fifo_init_done;
//                if (istream_table_inx == 9'hff)
//                    rd_tag_fifo_init_done <= 1;
            end
            
            ISTREAM_STATE_RUN : begin
                istream_table_inx   <= (istream_table_inx + 1) & istream_inx_mask;
                // stz: we try to avoid writing and reading the same address at irem_seq_table at the same time
                //
                irem_seq_table_wr_en_p    <= (istream_desc_inx_p8 != rem_seq_fifo_dout[32+8:32]) & ~rem_seq_fifo_empty;
                irem_seq_table_wr_inx_p   <= rem_seq_fifo_dout[32+8:32];
                irem_seq_table_wr_data_p  <= rem_seq_fifo_dout[31:0];

                irem_seq_table_wr_en      <= irem_seq_table_wr_en_p;
                irem_seq_table_wr_inx     <= irem_seq_table_wr_inx_p;
                irem_seq_table_wr_data    <= irem_seq_table_wr_data_p;
                if (rem_seq_wr_en) begin
                    if (verbose) $display("%0t: storing irem[0x%x] 0x%x", $time, wr_addr[8+2:0+2], wr_data[31:0]);
                    // stz: buffer the rem seq in the fifo first
                    rem_seq_fifo_din        <= {wr_addr[8+2:0+2], wr_data[31:0]};
		    // Don't write rem_seq_fifo when it's just an addr_window
		    // write, i.e. wr_addr[10:2] == 0, see Jira PICO-296
                    rem_seq_fifo_wr_en      <= (wr_addr[10:2] != 9'h0);
                end
                
                //TODO remove the wr_en signal, which isn't used, and rename wr_mask to wr_en
                if (wr_en && (wr_addr[31:16] == 16'h1230)) begin
                    if (verbose) $display("writing to host_sd_table[0x%x]: 0x%x", wr_addr[13:4], wr_data[31:0]);
                    host_sd_table_wr_inx[8:0]   <= wr_addr[12:4];
                    host_sd_table_wr_data       <= wr_data[31:0];
                    // here we only write 32b at a time (one of four mask bits set), while in the 'clear' state we write all 128b at once.
                    if (wr_addr[3:2] == 2'b00)    host_sd_table_wr_en[0] <= 1;
                    if (wr_addr[3:2] == 2'b01)    host_sd_table_wr_en[1] <= 1;
                    if (wr_addr[3:2] == 2'b10)    host_sd_table_wr_en[2] <= 1;
                    if (wr_addr[3:2] == 2'b11)    host_sd_table_wr_en[3] <= 1;
                end
                
                if (wr_en && (wr_addr[31:12] == 20'h12345)) begin
                    //if (wr_addr[2] == 1'b0) $display("%0t: storing seq_push_addr[0x%x] 0x%x", $time, wr_addr[8+3:0+3], wr_data[31:0]);
                    if (wr_addr[2] == 1'b0)   seq_push_addr_wr_en[0] <= 1;
                    if (wr_addr[2] == 1'b1)   seq_push_addr_wr_en[1] <= 1;
                    seq_push_addr_wr_data   <= wr_data;
                    seq_push_addr_wr_inx    <= wr_addr[11:3];
                end
                
                if (wr_en && (wr_addr[31:12] == 20'h12346)) begin
                    if (verbose) $display("%0t: setting inx_map_table[0x%x] to 0x%x", $time, wr_addr[10:2], wr_data[9:0]);
                    istream_inx_map_table_wr_en    <= 1;
                    istream_inx_map_table_wr_inx   <= wr_addr[10:2];
                    istream_inx_map_table_wr_data  <= wr_data[9:0];
                end
            end
          endcase
        end
        // stz: add some pipeline to ease timing
        istream_table_inx_q <= istream_table_inx;
        istream_table_inx_qq <= istream_table_inx_q;
    end
    
    assign rd_data = rd_data_reg;
    
    reg [12:0]  max_wr, max_wr_p;           // PCIe max payload, in bytes
    reg [11:0]  max_wr_mask;                // max payload minus one
    reg [12:0]  max_rd_req, max_rd_req_p;   // PCIe max read request, in bytes
    reg [11:0]  max_rd_req_mask;            // max_rd_req minus one

    always @(posedge clk) begin
        // for unknown reasons, the Virtex-6 cards fail when we use a read request larger than 128B.
        // actually, the K7 is doing it too. turning everything off till we investigate more.
        `ifdef PICO_MODEL_M505_DONOTUSETILLFURTHERNOTICE
        case (cfg_dcommand[14:12])
            3'b000: max_rd_req_p    <= 13'h080;
            3'b001: max_rd_req_p    <= 13'h100;
            3'b010: max_rd_req_p    <= 13'h200;
            3'b011: max_rd_req_p    <= 13'h400;
            3'b100: max_rd_req_p    <= 13'h800;
            3'b101: max_rd_req_p    <= 13'h1000;
            // 110 and 111 are reserved values. cast them to 128 (smallest size)
            3'b110: max_rd_req_p    <= 13'h080;
            3'b111: max_rd_req_p    <= 13'h080;
        endcase
        case (cfg_dcommand[7:5])
            3'b000: max_wr_p    <= 13'h080;
            3'b001: max_wr_p    <= 13'h100;
            3'b010: max_wr_p    <= 13'h200;
            3'b011: max_wr_p    <= 13'h400;
            3'b100: max_wr_p    <= 13'h800;
            3'b101: max_wr_p    <= 13'h1000;
            3'b110: max_wr_p    <= 13'h080;
            3'b111: max_wr_p    <= 13'h080;
        endcase
        `else // 505
        max_wr_p        <= 13'h80;
        max_rd_req_p    <= 13'h80;
        `endif // 505
        max_rd_req      <= max_rd_req_p;
        max_rd_req_mask <= max_rd_req_p - 1;
        max_wr          <= max_wr_p;
        max_wr_mask     <= max_wr_p - 1;
    end
    
    reg dbg_break;
    
    // this giant pile of registers is for PIO readback of DMA status.
    reg [31:0] iseq_cache_dout, iseq_cache_dout_q, iseq_cache_dout_q2, iseq_cache_dout_q3;
    reg iseq_cache_dout_valid, iseq_cache_dout_valid_q, iseq_cache_dout_valid_q2;
    reg [31:0] readback, readback_q, readback_q2, readback_q3;
    reg [31:0] rb9, rba, rbb, rbc, rbd, rbe, rbf, rb9_q, rba_q, rbb_q, rbc_q, rbd_q, rbe_q, rbf_q, rb9_q2, rba_q2, rbb_q2, rbc_q2, rbd_q2, rbe_q2, rbf_q2;
    reg rb9_valid, rba_valid, rbb_valid, rbc_valid, rbd_valid, rbe_valid, rbf_valid, rb9_valid_q, rba_valid_q, rbb_valid_q, rbc_valid_q, rbd_valid_q, rbe_valid_q, rbf_valid_q;
    
    wire [31:0] Version;
    assign Version[31:24] = `VERSION_MAJOR;
    assign Version[23:16] = `VERSION_MINOR;
    assign Version[15:8]  = `VERSION_RELEASE;
    assign Version[7:0]   = `VERSION_COUNTER;
    
    // handle PIO R/W
    // care must be taken with the address window register. when packets really start flying, writes that the cpu thinks are far apart in time
    //   can get jammed together on subsequent clock cycles. thus if you screw up the relative latency of normal writes, reads, and addr window
    //   writes, it's possible that the addr window isn't updated till after the write it was intended to modify, etc.
    always @(posedge clk) begin
        if (rst_q) begin
            addr_window             <= 21'h0;
            max_cpld_outstanding    <= 8'hf0;
        end else begin
            wr_addr     <= {32'h0, addr_window[31:11], wr_addr_raw[10:0]};
            wr_data     <= wr_data_raw;
            // be careful not to pass a window setting through as a normal write.
            wr_en           <= wr_en_raw && ~wr_addr_raw[11];
            // remote sequence updates have a priveleged access that bypasses the addr_window reg (since we need to set the seq with a single write from remote fpgas.)
            // (note that this also catches addr_window writes as rem_seq for stread 0. that's ok, since there is no stream 0.)
            // (the windowed access at addrs 0x12340XYZ is how we used to do it.)
            rem_seq_wr_en   <= wr_en_raw && (wr_addr_raw[11] || (addr_window[31:12] == 20'h12340));
            rd_addr_q       <= rd_addr;
            
            if (verbose) if (wr_en) $display("%0t: got wr to 0x%x: 0x%x", $time, wr_addr, wr_data);
            
            if (wr_en & (wr_addr[12:0] == 13'h10))
                stream_machine_en       <= wr_data[0];
            
            if (wr_en_raw &&  (wr_addr_raw[11:0] == 12'h800)) begin
                //$display("%0t: setting addr window to 0x%x", $time, {wr_data[31:11], 11'h0});
                addr_window[31:11]      <= wr_data_raw[31:11];
            end
            
            if (wr_en && (wr_addr[31:0] == 32'h12347000))
                max_cpld_outstanding    <= wr_data[7:0];
            
            if (wr_en && (wr_addr[31:0] == `STREAM_ID_MASK_ADDR))
                istream_inx_mask        <= wr_data[8:0];
            
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h12348)
                iseq_cache_dout_valid <= 1;
            else
                iseq_cache_dout_valid <= 0;
            iseq_cache_dout_valid_q <= iseq_cache_dout_valid;
            iseq_cache_dout_valid_q2 <= iseq_cache_dout_valid_q;
            iseq_cache_dout     <= iseq_cache_table[rd_addr_q[8+2:0+2]];
            iseq_cache_dout_q   <= iseq_cache_dout;
            iseq_cache_dout_q2  <= iseq_cache_dout_q;
            if (iseq_cache_dout_valid_q2)
                iseq_cache_dout_q3      <= iseq_cache_dout_q2;
            else
                iseq_cache_dout_q3  <= 32'h0;
            
            `ifdef FULL_READBACK
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h12349)  rb9_valid   <= 1;
            else                                                    rb9_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234a)  rba_valid   <= 1;
            else                                                    rba_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234b)  rbb_valid   <= 1;
            else                                                    rbb_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234c)  rbc_valid   <= 1;
            else                                                    rbc_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234d)  rbd_valid   <= 1;
            else                                                    rbd_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234e)  rbe_valid   <= 1;
            else                                                    rbe_valid   <= 0;
            if (~rd_addr_q[11] && addr_window[31:12] == 20'h1234f)  rbf_valid   <= 1;
            else                                                    rbf_valid   <= 0;
            rb9_valid_q <= rb9_valid;
            rba_valid_q <= rba_valid;
            rbb_valid_q <= rbb_valid;
            rbc_valid_q <= rbc_valid;
            rbd_valid_q <= rbd_valid;
            rbe_valid_q <= rbe_valid;
            rbf_valid_q <= rbf_valid;
            rb9 <= itx_seq_cache_table[rd_addr_q[8+2:0+2]];
            rba <= {12'h420, len_cache_table[rd_addr_q[8+2:0+2]]};
            rbb <= isd_cache_table[rd_addr_q[8+2:0+2]][31:0];
            rbc <= isd_cache_table[rd_addr_q[8+2:0+2]][63:32];
            rbd <= isd_cache_table[rd_addr_q[8+2:0+2]][95:64];
            rbe <= isd_cache_table[rd_addr_q[8+2:0+2]][127:96];
            rbf <= irem_seq_cache_table[rd_addr_q[8+2:0+2]][31:0];
            rb9_q   <= rb9;
            rba_q   <= rba;
            rbb_q   <= rbb;
            rbc_q   <= rbc;
            rbd_q   <= rbd;
            rbe_q   <= rbe;
            rbf_q   <= rbf;
            if (rb9_valid_q) rb9_q2 <= rb9_q; else rb9_q2 <= 32'h0;
            if (rba_valid_q) rba_q2 <= rba_q; else rba_q2 <= 32'h0;
            if (rbb_valid_q) rbb_q2 <= rbb_q; else rbb_q2 <= 32'h0;
            if (rbc_valid_q) rbc_q2 <= rbc_q; else rbc_q2 <= 32'h0;
            if (rbd_valid_q) rbd_q2 <= rbd_q; else rbd_q2 <= 32'h0;
            if (rbe_valid_q) rbe_q2 <= rbe_q; else rbe_q2 <= 32'h0;
            if (rbf_valid_q) rbf_q2 <= rbf_q; else rbf_q2 <= 32'h0;
            readback_q3 <= rb9_q2 | rba_q2 | rbb_q2 | rbc_q2 | rbd_q2 | rbe_q2 | rbf_q2;
            `else
            readback_q3 <= 32'h0;
            `endif //FULL_READBACK
            
            if (rd_addr_q[11:0] == 12'h810)
                rd_misc_reg_q <= Version[31:0];
            else if (rd_addr_q[11:0] == 12'h820)
                rd_misc_reg_q <= {3'h7, max_rd_req_p[12:0], cfg_dcommand[15:0]};//next_rd_tag_q[7:0], 5'h0, rd_tag_fifo_full, rd_tag_fifo_almost_empty, dbg_break};
            //else if (rd_addr_q[11:0] == 12'h8f0)
            //    rd_misc_reg_q <= {addr_window[31:12], 12'h8f0};
            else
                rd_misc_reg_q <= 32'h0;
            
            rd_data_reg <= rd_misc_reg_q | iseq_cache_dout_q3 | readback_q3;
        end
    end
    
    //
    // Local-Link Receive Controller
    //
    
    wire [127:0] m_axis_rx_tdata_buf;
    wire m_axis_rx_tlast_buf;
    wire m_axis_rx_tvalid_buf;
    wire m_axis_rx_tready_buf;
    wire [21:0] m_axis_rx_tuser_buf;

    wire [7:0]  sent_tag;
    wire [31:0] sent_tag_seq;
    wire        sent_tag_en;
    
//    `define USE_AXI_BUFFER
    `ifdef USE_AXI_BUFFER
    AXIBuffer axibuffer (
        .clk(clk),                              // I
        .rst(rst_q),                          // I

        // AXIS RX
        .s_axis_rx_tdata( m_axis_rx_tdata ),    // I
        .s_axis_rx_tlast( m_axis_rx_tlast ),    // I
        .s_axis_rx_tvalid( m_axis_rx_tvalid ),  // I
        .s_axis_rx_tready( m_axis_rx_tready ),  // O
        .s_axis_rx_tuser ( m_axis_rx_tuser ),   // I

        // AXIS TX
        .m_axis_rx_tdata( m_axis_rx_tdata_buf ),
        .m_axis_rx_tlast( m_axis_rx_tlast_buf ),
        .m_axis_rx_tvalid( m_axis_rx_tvalid_buf ),
        .m_axis_rx_tready( m_axis_rx_tready_buf ),
        .m_axis_rx_tuser ( m_axis_rx_tuser_buf )
    );
    `else
    assign m_axis_rx_tdata_buf = m_axis_rx_tdata;
    assign m_axis_rx_tlast_buf = m_axis_rx_tlast;
    assign m_axis_rx_tvalid_buf = m_axis_rx_tvalid;
    assign m_axis_rx_tready = m_axis_rx_tready_buf;
    assign m_axis_rx_tuser_buf = m_axis_rx_tuser;
    `endif
    
    wire [127:0]    rx_hdr, rx_data;
    wire            rx_sof;
    wire [7:0]      rx_bar_hit;
    
    PCIeHdrAlignSplit HdrAligner (
        .clk(clk),                              // I
        .rst_n(rst_n),                          // I

        // AXIS RX
        .m_axis_rx_tdata( m_axis_rx_tdata_buf ),    // I
        //.m_axis_rx_tstrb( m_axis_rx_tstrb_buf ),    // I
        .m_axis_rx_tlast( m_axis_rx_tlast_buf ),    // I
        .m_axis_rx_tvalid( m_axis_rx_tvalid_buf ),  // I
        .m_axis_rx_tready( m_axis_rx_tready_buf ),  // O
        .m_axis_rx_tuser ( m_axis_rx_tuser_buf ),   // I
        
        // outputs
        .hdr(rx_hdr),
        .data(rx_data),
        //.valid(rx_valid),
        .sof(rx_sof),
        .bar_hit(rx_bar_hit)
    );
    
  PIO_128_RX_ENGINE #(
    .C_DATA_WIDTH( C_DATA_WIDTH ),
    .STRB_WIDTH( STRB_WIDTH )

  ) EP_RX (

    .clk(clk),                              // I
    .rst_n(rst_n),                          // I
    
    .read_log(read_log_rd_data_q),
    .read_log_inx(read_log_rd_inx),
    .last_cpld_tag(last_cpld_tag),
    .last_cpld_tag_valid(last_cpld_tag_valid),

    .sent_tag(sent_tag),
    .sent_tag_seq(sent_tag_seq),
    .sent_tag_en(sent_tag_en),
    
    .stream_data(s_in_data),
    .stream_valid(s_in_valid),
    .stream_inx(s_in_id),
    .direct_rx_valid(direct_rx_valid),
    
    .rx_hdr(rx_hdr),
    .rx_data(rx_data),
    .rx_sof(rx_sof),
    .rx_bar_hit(rx_bar_hit),

    // Handshake with Tx engine
    .req_compl_o(req_compl),                // O
    .req_compl_wd_o(req_compl_wd),          // O
    .compl_done_i(compl_done),              // I

    .req_tc_o(req_tc),                      // O [2:0]
    .req_td_o(req_td),                      // O
    .req_ep_o(req_ep),                      // O
    .req_attr_o(req_attr),                  // O [1:0]
    .req_len_o(req_len),                    // O [9:0]
    .req_rid_o(req_rid),                    // O [15:0]
    .req_tag_o(req_tag),                    // O [7:0]
    .req_be_o(req_be),                      // O [7:0]
    .req_addr_o(req_addr),                  // O [63:0]

    // Memory Write Port
    .wr_addr_o(wr_addr_raw),                // O [63:0]
    .wr_be_o(wr_be),                        // O [7:0]
    .wr_data_o(wr_data_raw),                // O [31:0]
    .wr_en_o(wr_en_raw)                     // O

  );

    //
    // Local-Link Transmit Controller
    //

  PIO_128_TX_ENGINE #(
    .C_DATA_WIDTH( C_DATA_WIDTH ),
    .STRB_WIDTH( STRB_WIDTH )

  )EP_TX(

    .clk(clk),                                  // I
    .rst_n(rst_n),                              // I
    
    .iwr_q_data(iwr_q_out),
    .iwr_q_valid(~iwr_q_empty),
    .iwr_q_en(iwr_q_deq),
    
    .iwr_wr_q_data(iwr_wr_postdata_q_out),
    .iwr_wr_q_valid(~iwr_wr_postdata_q_empty),
    .iwr_wr_q_en(iwr_wr_postdata_q_deq),
    
    .wr_data_q_data(wr_data_q_out),
    .wr_data_q_valid(~wr_data_q_empty),
    .wr_data_q_en(wr_data_q_deq),
  
    // user-direct writes
    .user_pci_wr_q_data(user_pci_wr_q_data),
    .user_pci_wr_q_valid(user_pci_wr_q_valid),
    .user_pci_wr_q_en(user_pci_wr_q_en),

    .user_pci_wr_data_q_data(user_pci_wr_data_q_data),
    .user_pci_wr_data_q_valid(user_pci_wr_data_q_valid),
    .user_pci_wr_data_q_en(user_pci_wr_data_q_en),
    
    .tx_rd_req_ok(tx_rd_req_ok),
    
    .read_log_data(read_log_wr_data),
    .read_log_inx(read_log_wr_inx),
    .read_log_en(read_log_wr_en),
    .last_cpld_tag(last_tx_cpld_tag),
    .next_rd_tag(next_rd_tag),
    .next_rd_tag_en(next_rd_tag_en),

    // AXIS Tx
    .s_axis_tx_tready( s_axis_tx_tready ),      // I
    .s_axis_tx_tdata( s_axis_tx_tdata ),        // O
    .s_axis_tx_tstrb( s_axis_tx_tstrb ),        // O
    .s_axis_tx_tlast( s_axis_tx_tlast ),        // O
    .s_axis_tx_tvalid( s_axis_tx_tvalid ),      // O
    .tx_src_dsc( tx_src_dsc ),                  // O

    // Handshake with Rx engine
    .req_compl_i(req_compl),                    // I
    .req_compl_wd_i(req_compl_wd),              // I
    .compl_done_o(compl_done),                  // 0

    .req_tc_i(req_tc),                          // I [2:0]
    .req_td_i(req_td),                          // I
    .req_ep_i(req_ep),                          // I
    .req_attr_i(req_attr),                      // I [1:0]
    .req_len_i(req_len),                        // I [9:0]
    .req_rid_i(req_rid),                        // I [15:0]
    .req_tag_i(req_tag),                        // I [7:0]
    .req_be_i(req_be),                          // I [7:0]
    .req_addr_i(req_addr),                      // I [63:0]

    // Read Port

    .rd_addr_o(rd_addr),                        // O [63:0]
    .rd_be_o(rd_be),                            // O [3:0]
    .rd_data_i(rd_data),                        // I [31:0]

    .completer_id_i(cfg_completer_id),          // I [15:0]
    .cfg_bus_mstr_enable_i(cfg_bus_mstr_enable),// I

    .sent_tag(sent_tag),
    .sent_tag_seq(sent_tag_seq),
    .sent_tag_en(sent_tag_en),
    
    .max_rd_req(max_rd_req[12:0]),
    .max_rd_req_mask(max_rd_req_mask[11:0]),
    .max_wr(max_wr),
    .max_wr_mask(max_wr_mask)

    );

  assign req_compl_o  = req_compl;
  assign compl_done_o = compl_done;

endmodule // PIO_EP
