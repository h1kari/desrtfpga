//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2010 Xilinx, Inc. All rights reserved.
//

// Modifications Copyright 2011 Pico Computing, Inc.

//TODO make the max size packet size configurable, rather than fixed at 128.
//  since maxreadrequest is often 512, that would allow us to send just 1/4 the number of packets for the same read.
//TODO we should be able to assert the 'streaming' line, reducing latency a little bit. test it sometime.
//
////////////////////////////////////////////////////////////////////////////
// Modifications for Xilinx UltraScale
////////////////////////////////////////////////////////////////////////////
// 
// For Xilinx UltraScale devices there is no swizzling of the data 
// required. This is different from Kintex 7 and Virtex 6 devices 
// that did require swizzled data.
//
//      * For instance when we did a TX MEM_WR64 we would swizzle the data:
//               EXAMPLE 1: s_axis_tx_tdata <= #TCQ {
//                               wr_data_q_data_q[103:96],
//                               wr_data_q_data_q[111:104],
//                               wr_data_q_data_q[119:112],
//                               wr_data_q_data_q[127:120],
//                               wr_data_q_data_q[71:64],
//                               wr_data_q_data_q[79:72],
//                               wr_data_q_data_q[87:80],
//                               wr_data_q_data_q[95:88],
//                               wr_data_q_data_q[39:32],
//                               wr_data_q_data_q[47:40],
//                               wr_data_q_data_q[55:48],
//                               wr_data_q_data_q[63:56],
//                               wr_data_q_data_q[7:0],
//                               wr_data_q_data_q[15:8],
//                               wr_data_q_data_q[23:16],
//                               wr_data_q_data_q[31:24]};
//
//              EXAMPLE 2: wire [31:0]     rd_data_sw = {rd_data_i[7:0], rd_data_i[15:8], 
//                                          rd_data_i[23:16], rd_data_i[31:24]};
//
//      * However with UltraScale devices for a TX MEM_WR64 we don't do that:
//              s_axis_tx_tdata <= #TCQ wr_data_q_data_q; 
//
// The other major difference is that for Xilinx UltraScale for these packets:
//      * MEM_RD for data
//      * MEM_WR for seq_rpt
//      * MEM_WR for data
//      
//      Before we had seperate blocks of code for 32 bit and 64 bit FMT types:
//            if (|cmd_addr[47:32]) begin
//                *64_FMT_TYPE
//            else
//                *32_FMT_TYPE
//            end
//      
//      For UltraScale we have one block of code, and we use an ifdef
//       XILINX_ULTRASCALE to choose between the two:
//            `ifdef XILINX_ULTRASCALE
//                (|cmd_addr[47:32]) ? *64_FMT_TYPE : *32_FMT_TYPE
//            `else
//                if (|cmd_addr[47:32]) begin
//                    *64_FMT_TYPE
//                else
//                    *32_FMT_TYPE
//                end
//            `endif //XILINX_ULTRASCALE
//
//TODO: should be able to combine these and no have ifdef.
//
// For more info on UltraScale PCIe diff look at:
//  https://github.com/PicoComputing/pico/issues/537
//
////////////////////////////////////////////////////////////////////////////
                                 
`timescale 1ns/1ns

`include "PicoDefines.v"

module PIO_128_TX_ENGINE    #(
    // RX/TX interface data width
    parameter C_DATA_WIDTH = 128,
    parameter TCQ = 1,

    // TSTRB width
    parameter STRB_WIDTH = C_DATA_WIDTH / 8
)(
    input               clk,
    input               rst_n,

    // AXIS
    input                           s_axis_tx_tready,
    output  reg [C_DATA_WIDTH-1:0]  s_axis_tx_tdata,
    output  reg [STRB_WIDTH-1:0]    s_axis_tx_tstrb,
    output  reg                     s_axis_tx_tlast,
    output  reg                     s_axis_tx_tvalid,
    output                          tx_src_dsc,

    input [127:0]     iwr_q_data,
    input             iwr_q_valid,
    output reg        iwr_q_en,

    input [127:0]     iwr_wr_q_data,
    input             iwr_wr_q_valid,
    output reg        iwr_wr_q_en,

    input [127:0]     wr_data_q_data,
    input             wr_data_q_valid,
    output            wr_data_q_en,

    // user-direct writes
    input [127:0]     user_pci_wr_q_data,
    input             user_pci_wr_q_valid,
    output reg        user_pci_wr_q_en,

    input [127:0]     user_pci_wr_data_q_data,
    input             user_pci_wr_data_q_valid,
    output            user_pci_wr_data_q_en,

    input             tx_rd_req_ok,

    output reg [11:0] read_log_data,
    output reg [7:0]  read_log_inx,
    output reg        read_log_en,
    output reg [7:0]  last_cpld_tag, //TODO is this obsolete that that we're using a fifo for the tags?
    input       [7:0] next_rd_tag,
    output            next_rd_tag_en,

    input               req_compl_i,
    input               req_compl_wd_i,
    output  reg         compl_done_o,

    input [2:0]         req_tc_i,
    input               req_td_i,
    input               req_ep_i,
    input [1:0]         req_attr_i,
    input [9:0]         req_len_i,
    input [15:0]        req_rid_i,
    input [7:0]         req_tag_i,
    input [7:0]         req_be_i,
    input [63:0]        req_addr_i,

    output [63:0]       rd_addr_o,
    output [3:0]        rd_be_o,
    input  [31:0]       rd_data_i,

    input [15:0]        completer_id_i,
    input               cfg_bus_mstr_enable_i,

    output reg [7:0]    sent_tag,
    output reg [31:0]   sent_tag_seq,
    output reg          sent_tag_en,
    
    input [12:0]        max_rd_req,
    input [11:0]        max_rd_req_mask,
    input [12:0]        max_wr,
    input [11:0]        max_wr_mask
);

    localparam TX_CMD_WR_SEQ= 2'b00;
    localparam TX_CMD_WR    = 2'b01;
    localparam TX_CMD_RD    = 2'b10;
    localparam TX_CMD_USER_WR=2'b11;
    localparam verbose = 0;


    localparam MEM_RD32_FMT_TYPE    = 7'b00_00000;
    localparam MEM_RD64_FMT_TYPE    = 7'b01_00000;
    localparam MEM_WR32_FMT_TYPE    = 7'b10_00000;
    localparam MEM_WR64_FMT_TYPE    = 7'b11_00000;
    localparam CPLD_FMT_TYPE        = 7'b10_01010;
    localparam CPL_FMT_TYPE         = 7'b00_01010;

    localparam STATE_RST                = 8'b00000001;
    localparam STATE_BS                 = 8'b00000010;
    localparam STATE_CMD                = 8'b00000100;
    localparam STATE_MEM_WR64           = 8'b00001000;
    localparam STATE_MEM_W_DATA         = 8'b00010000;
    localparam STATE_MEM_W_USER_DATA    = 8'b00100000;

    // Local registers
    reg [7:0]           state;

    reg [11:0]          byte_count;
    reg [06:0]          lower_addr;

    reg                 req_compl_q;
    reg                 req_compl_q2, req_compl_q3;
    reg                 req_compl_wd_q;
    reg                 req_compl_wd_q2, req_compl_wd_q3;

    reg                 hold_cpl;
    //reg [7:0]           next_rd_tag; // the next header tag we'll use for a read request.
    
    // cmd pipeline's constituents
    reg [127:0]         cmd;
    reg [47:0]          cmd_addr;
    reg [1:0]           cmd_type;
    reg [19:0]          cmd_size;
    reg [8:0]           cmd_stream_num;
    
    reg                 iwr_q_en_q;
    
    reg                 writing;
    reg [127:0]         wr_data_q_data_q;
    reg                 user_writing;
    reg [127:0]         user_pci_wr_data_q_data_q;
    
    //wire [11:0]          max_rd_req = 12'h200; // in bytes
    //wire [11:0]          max_rd_req = 12'h80; // in bytes

    //TODO this doesn't handle a max read request of 4kB. (which is represented in the header as 0)
    wire [11:0]         read_burst_size = (|(cmd_size[11:0] & max_rd_req_mask[11:0])) ? (cmd_size[11:0] & max_rd_req_mask) : max_rd_req[11:0];
    //wire [11:0]         read_burst_size = (|cmd_size[8:0]) ? {3'h0, cmd_size[8:0]} : max_rd_req;
    //wire [11:0]         read_burst_size = (|cmd_size[10:0]) ? {1'h0, cmd_size[10:0]} : max_rd_req;

    wire [11:0]         wr_burst_size =   (|(cmd_size[11:0] & max_wr_mask))           ? (cmd_size[11:0] & max_wr_mask[11:0]) : max_wr[11:0];

    assign next_rd_tag_en = (state == STATE_CMD && cmd_type == 2'b10 && s_axis_tx_tready && tx_rd_req_ok);

    // Local wires
    `ifdef XILINX_ULTRASCALE
        wire [31:0]     rd_data_sw = rd_data_i[31:0];
    `else
        wire [31:0]     rd_data_sw = {rd_data_i[7:0], rd_data_i[15:8], rd_data_i[23:16], rd_data_i[31:24]};
    `endif
    
    assign wr_data_q_en = s_axis_tx_tready && writing && ~((state == STATE_MEM_W_DATA) && ((cmd_size[11:0] & max_wr_mask) <= 16) && |(cmd_size[11:0] & max_wr_mask));
    assign user_pci_wr_data_q_en = s_axis_tx_tready && user_writing && ~((state == STATE_MEM_W_USER_DATA) && ((cmd_size[11:0] & max_wr_mask) <= 16) && |(cmd_size[11:0] & max_wr_mask));

    // Unused discontinue
    assign tx_src_dsc = 1'b0;

    /*
     * Present address and byte enable to memory module
     */

    assign rd_addr_o = req_addr_i;
    assign rd_be_o =   req_be_i[3:0];

    /*
     * Calculate byte count based on byte enable
     */

    always @ (rd_be_o) begin

      casex (rd_be_o[3:0])

        4'b1xx1 : byte_count = 12'h004;
        4'b01x1 : byte_count = 12'h003;
        4'b1x10 : byte_count = 12'h003;
        4'b0011 : byte_count = 12'h002;
        4'b0110 : byte_count = 12'h002;
        4'b1100 : byte_count = 12'h002;
        4'b0001 : byte_count = 12'h001;
        4'b0010 : byte_count = 12'h001;
        4'b0100 : byte_count = 12'h001;
        4'b1000 : byte_count = 12'h001;
        4'b0000 : byte_count = 12'h001;

      endcase

    end

    /*
     * Calculate lower address based on  byte enable
     */

    always @ (rd_be_o or req_addr_i) begin

      casex ({req_compl_wd_q3, rd_be_o[3:0]})

        5'b0_xxxx : lower_addr = 8'h0;
        5'bx_0000 : lower_addr = {req_addr_i[6:2], 2'b00};
        5'bx_xxx1 : lower_addr = {req_addr_i[6:2], 2'b00};
        5'bx_xx10 : lower_addr = {req_addr_i[6:2], 2'b01};
        5'bx_x100 : lower_addr = {req_addr_i[6:2], 2'b10};
        5'bx_1000 : lower_addr = {req_addr_i[6:2], 2'b11};

      endcase

    end

    always @ ( posedge clk ) begin

        if (!rst_n ) begin

          req_compl_q     <= #TCQ 1'b0;
          req_compl_q2    <= #TCQ 1'b0;
          req_compl_q3    <= #TCQ 1'b0;
          req_compl_wd_q  <= #TCQ 1'b0;
          req_compl_wd_q2 <= #TCQ 1'b0;
          req_compl_wd_q3 <= #TCQ 1'b0;

        end else begin

          req_compl_q     <= #TCQ req_compl_i;
          req_compl_q2    <= #TCQ req_compl_q;
          req_compl_q3    <= #TCQ req_compl_q2;
          req_compl_wd_q  <= #TCQ req_compl_wd_i;
          req_compl_wd_q2 <= #TCQ req_compl_wd_q;
          req_compl_wd_q3 <= #TCQ req_compl_wd_q2;


        end

    end

    /*
     *  Generate Completion with 1 DW Payload
     */

    always @ ( posedge clk ) begin
        if (!rst_n ) begin
            state           <= STATE_RST;

            s_axis_tx_tlast   <= #TCQ 1'b0;
            s_axis_tx_tvalid  <= #TCQ 1'b0;
            s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
            s_axis_tx_tstrb   <= #TCQ {STRB_WIDTH{1'b1}};

            compl_done_o      <= #TCQ 1'b0;
            hold_cpl        <= #TCQ 1'b0;
            
            iwr_q_en            <= #TCQ 0;
            user_pci_wr_q_en    <= #TCQ 0;
            //next_rd_tag         <= #TCQ 8'h1;
            last_cpld_tag       <= #TCQ 8'h0;
            
            writing             <= #TCQ 0;
            user_writing        <= #TCQ 0;

            sent_tag_seq    <= #TCQ 32'h0;

        end else begin
            if (req_compl_q3)
                hold_cpl <= 1;
            
            iwr_wr_q_en     <= #TCQ 0;
            
            iwr_q_en_q      <= #TCQ iwr_q_en;
            
            compl_done_o    <= #TCQ 0;
            read_log_en     <= #TCQ 0;
            sent_tag_en     <= #TCQ 0;
            
            if (wr_data_q_en)
                wr_data_q_data_q    <= #TCQ wr_data_q_data;
            if (user_pci_wr_data_q_en)
                user_pci_wr_data_q_data_q    <= #TCQ user_pci_wr_data_q_data;
            
            case (state)
                STATE_RST : begin
                    // completion request pending
                    // TODO we should put these into the pipeline we use for all other writes
                    if ((req_compl_q3 | hold_cpl) && (s_axis_tx_tready || ~s_axis_tx_tvalid)) begin
                        s_axis_tx_tlast   <= #TCQ 1'b1;
                        s_axis_tx_tvalid  <= #TCQ 1'b1;
                        s_axis_tx_tdata   <= #TCQ {                   // Bits
                                            rd_data_sw,               // 32
                                            // [95:64]
                                            req_rid_i,                // 16
                                            req_tag_i,                //  8
                                            {1'b0},                   //  1
                                            lower_addr,               //  7
                                            // [63:32]
                                            completer_id_i,           // 16
                                            {3'b0},                   //  3 compl status (0 == success)
                                            {1'b0},                   //  1 byte count modified? (BCM)
                                            byte_count,               // 12
                                            // [31:0]
                                            {1'b0},                   //  1
                                            (req_compl_wd_q3 ?
                                            CPLD_FMT_TYPE :
                                            CPL_FMT_TYPE),            //  7
                                            {1'b0},                   //  1
                                            req_tc_i,                 //  3
                                            {4'b0},                   //  4
                                            req_td_i,                 //  1
                                            req_ep_i,                 //  1
                                            req_attr_i,               //  2
                                            {2'b0},                   //  2
                                            req_len_i                 // 10
                                            };

                        // Here we select if the packet has data or
                        // not.  The strobe signal will mask data
                        // when it is not needed.  No reason to change
                        // the data bus.
                        if (req_compl_wd_q3)
                          s_axis_tx_tstrb   <= #TCQ 16'hFFFF;
                        else
                          s_axis_tx_tstrb   <= #TCQ 16'h0FFF;

                        compl_done_o        <= #TCQ 1'b1;
                        hold_cpl            <= #TCQ 0;
                    
                    //TODO we wouldn't have to check ready/valid on moving to the CMD state if we were more selective with
                    //  clearing valid/ready and postponed the check till the CMD state.
                    //TODO ideally we'd send descriptor read requests ahead of writes, otherwise large writes will stall
                    //  periodically when the descriptor buffer runs dry.
                    // Reads and writes-with-immediate-data
                    end else if (iwr_q_valid && (s_axis_tx_tready || ~s_axis_tx_tvalid)) begin
                        iwr_q_en        <= #TCQ 1;
                        cmd             <= #TCQ iwr_q_data;
                        cmd_addr        <= iwr_q_data[79:32];
                        cmd_type        <= iwr_q_data[107:106];
                        cmd_size        <= iwr_q_data[19:0];
                        cmd_stream_num  <= iwr_q_data[104:96];
                        s_axis_tx_tlast <= #TCQ 1'b0;
                        s_axis_tx_tvalid<= #TCQ 1'b0;
                        state           <= STATE_CMD;
                    // Writes
                    end else if (iwr_wr_q_valid && (s_axis_tx_tready || ~s_axis_tx_tvalid)) begin
                        iwr_wr_q_en     <= #TCQ 1;
                        cmd_addr        <= iwr_wr_q_data[79:32];
                        cmd_type        <= iwr_wr_q_data[107:106];
                        cmd_size        <= iwr_wr_q_data[19:0];
                        cmd_stream_num  <= iwr_wr_q_data[104:96];
                        s_axis_tx_tlast <= #TCQ 1'b0;
                        s_axis_tx_tvalid<= #TCQ 1'b0;
                        writing         <= #TCQ 1;
                        state           <= STATE_CMD;
                    // user writes
                    end else if (user_pci_wr_q_valid && (s_axis_tx_tready || ~s_axis_tx_tvalid)) begin
                        /*if (verbose)*/ $display("%0t: starting user direct write of 0x%xB to 0x%x", $time, user_pci_wr_q_data[19:0], user_pci_wr_q_data[79:32]);
                        user_pci_wr_q_en<= #TCQ 1;
                        cmd_addr        <= user_pci_wr_q_data[79:32];
                        cmd_type        <= 2'b01; //user_pci_q_data[107:106];
                        cmd_size        <= user_pci_wr_q_data[19:0];
                        s_axis_tx_tlast <= #TCQ 1'b0;
                        s_axis_tx_tvalid<= #TCQ 1'b0;
                        user_writing    <= #TCQ 1; // we'll use this flag later to determine which fifo to pull data from
                        state           <= STATE_CMD;
                    end else if (s_axis_tx_tready || ~s_axis_tx_tvalid) begin
                        // this is excessive. we really only need to clear tvalid, right?
                        s_axis_tx_tlast   <= #TCQ 1'b0;
                        s_axis_tx_tvalid  <= #TCQ 1'b0;
                        s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
                        s_axis_tx_tstrb   <= #TCQ {STRB_WIDTH{1'b1}};
                    end
                end //STATE_RST
                
                STATE_CMD : begin
                    iwr_q_en    <= #TCQ 0;
                    user_pci_wr_q_en <= #TCQ 0;
                    if (cmd_type == 2'b10 && s_axis_tx_tready && tx_rd_req_ok) begin
                        // it's important that this read_log stuff just go high for a cycle, even though
                        //   we may have to hold the tx_t* signals a while.
                        read_log_data       <= #TCQ {3'b0, cmd_stream_num[8:0]}; // 12 bits total
                        read_log_inx        <= #TCQ next_rd_tag;
                        read_log_en         <= #TCQ 1;
                        last_cpld_tag       <= #TCQ next_rd_tag;
                        //next_rd_tag[7:0]    <= #TCQ next_rd_tag[7:0] + 1; // the top 3 tag bits aren't used unless we enable the Extended Tag feature.
                        sent_tag_en         <= #TCQ 1;
                        sent_tag            <= #TCQ next_rd_tag;
                        sent_tag_seq        <= #TCQ sent_tag_seq + read_burst_size[11:4];
                        s_axis_tx_tlast     <= #TCQ 1'b1;
                        s_axis_tx_tvalid    <= #TCQ 1'b1;
                        cmd_addr            <= #TCQ cmd_addr + read_burst_size;
                        cmd_size            <= #TCQ cmd_size - read_burst_size;
                        if (verbose) $display("read_burst_size: 0x%x", read_burst_size);
                        `ifdef XILINX_ULTRASCALE
                            if (verbose) $display("%0t: TX MEM_RD64. addr:0x%x, len:0x%xB, tag:0x%x", $time, cmd_addr[47:0], read_burst_size, next_rd_tag);
                            s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                            s_axis_tx_tdata     <= #TCQ {
                                                                                // <bit width> <description>
                                                // [127:64]
                                                cmd_addr[31:2],                 // 30 addr[31:2]
                                                2'b0,                           //  2 reserved (addr[1:0])
                                                16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data.
                                                // [63:32]
                                                completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                next_rd_tag,                    //  8 tag XXX:increment this for multi-packet mrds
                                                4'hF,                           //  4 last DWORD byte enables XXX:must be zero if count==1
                                                4'hF,                           //  4 first DWORD byte enables
                                                // [31:0]
                                                1'b0,                           //  1 reserved
                                                (|cmd_addr[47:32]) ? MEM_RD64_FMT_TYPE : MEM_RD32_FMT_TYPE,              //  7 type and 32/64b flag
                                                1'b0,                           //  1 reserved
                                                3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                4'b0,                           //  4 reserved
                                                1'b0,                           //  1 TLP digest present (TD)
                                                1'b0,                           //  1 poisoned (EP)
                                                2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                2'b0,                           //  2 reserved
                                                read_burst_size[11:2] //(|cmd_size[6:0]) ? {5'h0, cmd_size[6:2]} : max_rd_req_dw[9:0]                  // 10 length in DWORDs
                                                };
                        `else
                            if (|cmd_addr[47:32]) begin
                                if (verbose) $display("%0t: TX MEM_RD64. addr:0x%x, len:0x%xB, tag:0x%x", $time, cmd_addr[47:0], read_burst_size, next_rd_tag);
                                s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:64]
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data.
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    next_rd_tag,                    //  8 tag XXX:increment this for multi-packet mrds
                                                    4'hF,                           //  4 last DWORD byte enables XXX:must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_RD64_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    read_burst_size[11:2] //(|cmd_size[6:0]) ? {5'h0, cmd_size[6:2]} : max_rd_req_dw[9:0]                  // 10 length in DWORDs
                                                    };
                            end else begin
                                if (verbose) $display("%0t: TX MEM_RD32. addr:0x%x, len:0x%xB, tag:0x%x", $time, cmd_addr[47:0], cmd_size[11:2]*4, next_rd_tag);
                                s_axis_tx_tstrb     <= #TCQ {4'h0, 12'hFFF};        // tdata byte enables. 0x0FFF for a 3DWORD packet
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:64]
                                                    32'h0,                          // 32 upper addr or first DWORD of data.
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    next_rd_tag,                    //  8 tag XXX:increment this for multi-packet mrds
                                                    4'hF,                           //  4 last DWORD byte enables XXX:must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_RD32_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    read_burst_size[11:2] //(|cmd_size[6:0]) ? {5'h0, cmd_size[6:2]} : max_rd_req_dw[9:0]
                                                    };
                            end
                        `endif //XILINX_ULTRASCALE
                        // note that we aren't waiting for the tready ack. we're counting on STATE_RST to handle that.
                        if (cmd_size[19:0] == {8'h0, read_burst_size})
                            state   <= STATE_RST;
                        // otherwise, stay in this state, we need to send more packets to finish this request.
                    end else if (cmd_type == 2'b00 /*&& s_axis_tx_tready*/) begin
                        s_axis_tx_tvalid    <= #TCQ 1'b1;
                        `ifdef XILINX_ULTRASCALE
                            if (verbose) $display("%0t: TX MEM_WR64 for seq_rpt. addr:0x%x, data:0x%x", $time, cmd_addr[47:0], cmd[31:0]);
                            s_axis_tx_tlast     <= #TCQ 1'b0;
                            s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                            s_axis_tx_tdata     <= #TCQ {
                                                                                // <bit width> <description>
                                                // [127:96]
                                                cmd_addr[31:2],                 // 30 addr[31:2]
                                                2'b0,                           //  2 reserved (addr[1:0])
                                                16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data. XXX
                                                // [63:32]
                                                completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                8'h0,                           //  8 tag
                                                4'h0,                           //  4 last DWORD byte enables. must be zero if count==1
                                                4'hF,                           //  4 first DWORD byte enables
                                                // [31:0]
                                                1'b0,                           //  1 reserved
                                                (|cmd_addr[47:32]) ? MEM_WR64_FMT_TYPE : MEM_WR32_FMT_TYPE,              //  7 type and 32/64b flag
                                                1'b0,                           //  1 reserved
                                                3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                4'b0,                           //  4 reserved
                                                1'b0,                           //  1 TLP digest present (TD)
                                                1'b0,                           //  1 poisoned (EP)
                                                2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                2'b0,                           //  2 reserved
                                                10'h1                           // 10 length in DWORDs
                                                };
                            state   <=  STATE_MEM_WR64;
                        `else
                            if (|cmd_addr[47:32]) begin
                                if (verbose) $display("%0t: TX MEM_WR64 for seq_rpt. addr:0x%x, data:0x%x", $time, cmd_addr[47:0], cmd[31:0]);
                                s_axis_tx_tlast     <= #TCQ 1'b0;
                                s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:96]
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data. XXX
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    8'h0,                           //  8 tag
                                                    4'h0,                           //  4 last DWORD byte enables. must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_WR64_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    10'h1                           // 10 length in DWORDs
                                                    };
                                state   <=  STATE_MEM_WR64;
                            end else begin
                                if (verbose) $display("%0t: TX MEM_WR32 for seq_rpt. addr:0x%x, data:0x%x", $time, cmd_addr[47:0], cmd[31:0]);
                                s_axis_tx_tlast     <= #TCQ 1'b1;
                                s_axis_tx_tstrb     <= #TCQ 16'hFFFF;                // tdata byte enables
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:96]
                                                    cmd[7:0], cmd[15:8], cmd[23:16], cmd[31:24],    // 32 first DWORD of data.
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    8'h0,                           //  8 tag
                                                    4'h0,                           //  4 last DWORD byte enables. must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_WR32_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    10'h1                           // 10 length in DWORDs
                                                    };
                                state   <= STATE_RST;
                            end
                        `endif //XILINX_ULTRASCALE
                    end else if (cmd_type == 2'b01 && s_axis_tx_tready) begin
                        s_axis_tx_tvalid    <= #TCQ 1'b1;
                        `ifdef XILINX_ULTRASCALE
                            if (verbose) $display("%0t: TX MEM_WR64. addr:0x%x, size(DW):0x%x", $time, cmd_addr[47:0],
                                    wr_burst_size[11:2]);
                            s_axis_tx_tlast     <= #TCQ 1'b0;
                            s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                            s_axis_tx_tdata     <= #TCQ {
                                                                                // <bit width> <description>
                                                // [127:96]
                                                cmd_addr[31:2],                 // 30 addr[31:2]
                                                2'b0,                           //  2 reserved (addr[1:0])
                                                16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data. XXX
                                                // [63:32]
                                                completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                8'h0,                           //  8 tag
                                                4'hF,                           //  4 last DWORD byte enables. must be zero if count==1
                                                4'hF,                           //  4 first DWORD byte enables
                                                // [31:0]
                                                1'b0,                           //  1 reserved
                                                (|cmd_addr[47:32]) ? MEM_WR64_FMT_TYPE : MEM_WR32_FMT_TYPE,              //  7 type and 32/64b flag
                                                1'b0,                           //  1 reserved
                                                3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                4'b0,                           //  4 reserved
                                                1'b0,                           //  1 TLP digest present (TD)
                                                1'b0,                           //  1 poisoned (EP)
                                                2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                2'b0,                           //  2 reserved
                                                wr_burst_size[11:2] // 10 length in DWORDs
                                                };
                            if (user_writing)
                                state   <=  STATE_MEM_W_USER_DATA;
                            else
                                state   <=  STATE_MEM_W_DATA;
                        `else
                            if (|cmd_addr[47:32]) begin
                                if (verbose) $display("%0t: TX MEM_WR64. addr:0x%x, size(DW):0x%x", $time, cmd_addr[47:0],
                                        wr_burst_size[11:2]);
                                s_axis_tx_tlast     <= #TCQ 1'b0;
                                s_axis_tx_tstrb     <= #TCQ 16'hFFFF;        // tdata byte enables. 0xFFFF for a 4DWORD packet
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:96]
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    16'h0, cmd_addr[47:32],         // 32 upper addr or first DWORD of data. XXX
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    8'h0,                           //  8 tag
                                                    4'hF,                           //  4 last DWORD byte enables. must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_WR64_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    wr_burst_size[11:2] // 10 length in DWORDs
                                                    };
                                if (user_writing)
                                    state   <=  STATE_MEM_W_USER_DATA;
                                else
                                    state   <=  STATE_MEM_W_DATA;
                            end else begin
                                if (verbose) $display("%0t: TX MEM_WR32. addr:0x%x, size(DW):0x%x, data:0x%x",
                                        $time, cmd_addr[47:0],
                                        wr_burst_size[11:2],
                                        user_writing ? user_pci_wr_data_q_data[127:96] : wr_data_q_data[127:96]);
                                s_axis_tx_tlast     <= #TCQ 1'b0;
                                s_axis_tx_tstrb     <= #TCQ 16'hFFFF;                // tdata byte enables
                                s_axis_tx_tdata     <= #TCQ {
                                                                                    // <bit width> <description>
                                                    // [127:96]
                                                    user_writing ?
                                                       {user_pci_wr_data_q_data[7:0],
                                                        user_pci_wr_data_q_data[15:8],
                                                        user_pci_wr_data_q_data[23:16],
                                                        user_pci_wr_data_q_data[31:24]} :
                                                       {wr_data_q_data[7:0],
                                                        wr_data_q_data[15:8],
                                                        wr_data_q_data[23:16],
                                                        wr_data_q_data[31:24]},     // 32 first DWORD of data.
                                                    cmd_addr[31:2],                 // 30 addr[31:2]
                                                    2'b0,                           //  2 reserved (addr[1:0])
                                                    // [63:32]
                                                    completer_id_i,                 // 16 our id (actually called requester id in this context)
                                                    8'h0,                           //  8 tag
                                                    4'hF,                           //  4 last DWORD byte enables. must be zero if count==1
                                                    4'hF,                           //  4 first DWORD byte enables
                                                    // [31:0]
                                                    1'b0,                           //  1 reserved
                                                    MEM_WR32_FMT_TYPE,              //  7 type and 32/64b flag
                                                    1'b0,                           //  1 reserved
                                                    3'b0, /*XXX*/                   //  3 traffic class (TC)
                                                    4'b0,                           //  4 reserved
                                                    1'b0,                           //  1 TLP digest present (TD)
                                                    1'b0,                           //  1 poisoned (EP)
                                                    2'b0, /*XXX*/                   //  2 relaxed order, no snoop bits
                                                    2'b0,                           //  2 reserved
                                                    wr_burst_size[11:2] // 10 length in DWORDs
                                                    };
                                if (user_writing)
                                    state   <=  STATE_MEM_W_USER_DATA;
                                else
                                    state   <=  STATE_MEM_W_DATA;
                            end
                        `endif // XILINX_ULTRASCALE
                    end else if (s_axis_tx_tready && s_axis_tx_tvalid) begin
                        // this is state is used when, for example, we're in the middle of sending a string of read requests
                        //   and our "max outstanding requests" machinery tells us to stop. we're essentially freezing here
                        //   until we're allowed to go again. but we can't assert valid while we're waiting.
                        //TODO this could stall us for as much as 1us!!! rewrite the state machine to be able to
                        //  carry on with other traffic while we're waiting for permission to send more read requests.
                        s_axis_tx_tvalid    <= #TCQ 0; //TODO this is pretty clumsy
                    end
                end
                
                STATE_MEM_WR64 : begin
                    //TODO do we really need to check tx_ready? I don't think axi will deassert it in the middle of this packet
                    //  update 20110404: it won't deassert in the middle, if we just sent out the first cycle, tready may not
                    //    have been asserted yet. wait on tready till we're really in the middle of the packet.
                    if (s_axis_tx_tready) begin
                        s_axis_tx_tvalid    <= #TCQ 1'b1;
                        s_axis_tx_tlast     <= #TCQ 1'b1;
                        s_axis_tx_tstrb     <= #TCQ {12'h0, 4'hF};
                        `ifdef XILINX_ULTRASCALE
                            s_axis_tx_tdata     <= #TCQ {96'h0, cmd[31:0]};
                        `else
                            s_axis_tx_tdata     <= #TCQ {96'h0, cmd[7:0], cmd[15:8], cmd[23:16], cmd[31:24]};
                        `endif
                        state               <= STATE_RST;
                    end
                end
                
                STATE_MEM_W_DATA : begin
                    if (s_axis_tx_tready) begin
                        //s_axis_tx_tvalid    <= #TCQ 1'b1;
                        cmd_size    <= #TCQ cmd_size - 20'h10;
                        cmd_addr    <= #TCQ cmd_addr + 48'h10; //TODO do we really need to wrap over more than 12 bits?
                        // if we're on the border of a 128B packet, we're either done or starting a new packet.
                        if ((cmd_size[11:0] & max_wr_mask) <= 16 && |(cmd_size[11:0] & max_wr_mask)) begin
                            s_axis_tx_tlast     <= #TCQ 1'b1;
                            //wr_data_q_en        <= #TCQ 0;
                            if (|(cmd_size[19:0] & {8'hff, ~max_wr_mask[11:0]})) begin
                                state               <= STATE_CMD;
                            end else begin
                                writing             <= #TCQ 0;
                                state               <= STATE_RST;
                            end
                        end
                        `ifdef XILINX_ULTRASCALE
                            if (verbose) $display("%0t: TX MEM_WR64 data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                    $time, cmd_size[19:0], cmd_addr[47:0],
                                    wr_data_q_data_q[127:96], wr_data_q_data_q[95:64],
                                    wr_data_q_data_q[63:32], wr_data_q_data_q[31:0]);
                            s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                            s_axis_tx_tdata <= #TCQ wr_data_q_data_q;
                        `else
                            if (|cmd_addr[47:32]) begin
                                if (verbose) $display("%0t: TX MEM_WR64 data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                        $time, cmd_size[19:0], cmd_addr[47:0],
                                        wr_data_q_data_q[127:96], wr_data_q_data_q[95:64],
                                        wr_data_q_data_q[63:32], wr_data_q_data_q[31:0]);
                                s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                                s_axis_tx_tdata <= #TCQ {
                                                wr_data_q_data_q[103:96],
                                                wr_data_q_data_q[111:104],
                                                wr_data_q_data_q[119:112],
                                                wr_data_q_data_q[127:120],
                                                wr_data_q_data_q[71:64],
                                                wr_data_q_data_q[79:72],
                                                wr_data_q_data_q[87:80],
                                                wr_data_q_data_q[95:88],
                                                wr_data_q_data_q[39:32],
                                                wr_data_q_data_q[47:40],
                                                wr_data_q_data_q[55:48],
                                                wr_data_q_data_q[63:56],
                                                wr_data_q_data_q[7:0],
                                                wr_data_q_data_q[15:8],
                                                wr_data_q_data_q[23:16],
                                                wr_data_q_data_q[31:24]};
                            end else begin
                                if (verbose) $display("%0t: TX MEM_WR32 data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                        $time, cmd_size[19:0], cmd_addr[47:0],
                                        wr_data_q_data[127:96], wr_data_q_data_q[95:64],
                                        wr_data_q_data_q[63:32], wr_data_q_data_q[31:0]);
                                if ((cmd_size[11:0] & max_wr_mask) <= 16 && |(cmd_size[11:0] & max_wr_mask))
                                    s_axis_tx_tstrb <= #TCQ {4'h0, 12'hFFF};
                                else
                                    s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                                s_axis_tx_tdata <= #TCQ {
                                                wr_data_q_data[7:0],
                                                wr_data_q_data[15:8],
                                                wr_data_q_data[23:16],
                                                wr_data_q_data[31:24],
                                                wr_data_q_data_q[103:96],
                                                wr_data_q_data_q[111:104],
                                                wr_data_q_data_q[119:112],
                                                wr_data_q_data_q[127:120],
                                                wr_data_q_data_q[71:64],
                                                wr_data_q_data_q[79:72],
                                                wr_data_q_data_q[87:80],
                                                wr_data_q_data_q[95:88],
                                                wr_data_q_data_q[39:32],
                                                wr_data_q_data_q[47:40],
                                                wr_data_q_data_q[55:48],
                                                wr_data_q_data_q[63:56]};
                            end
                        `endif //XILINX_ULTRASCALE
                    end // tready
                end
                
                STATE_MEM_W_USER_DATA : begin
                    if (s_axis_tx_tready) begin
                        //s_axis_tx_tvalid    <= #TCQ 1'b1;
                        cmd_size    <= #TCQ cmd_size - 20'h10;
                        cmd_addr    <= #TCQ cmd_addr + 48'h10; //TODO do we really need to wrap over more than 12 bits?
                        // if we're on the border of a 128B packet, we're either done or starting a new packet.
                        if ((cmd_size[11:0] & max_wr_mask) <= 16 && |(cmd_size[11:0] & max_wr_mask)) begin
                            s_axis_tx_tlast     <= #TCQ 1'b1;
                            //wr_data_q_en        <= #TCQ 0;
                            if (|(cmd_size[19:0] & {8'hff, ~max_wr_mask[11:0]})) begin
                                state               <= STATE_CMD;
                            end else begin
                                user_writing        <= #TCQ 0;
                                state               <= STATE_RST;
                            end
                        end
                        `ifdef PICO_MODEL_M510
                            if (verbose) $display("%0t: TX MEM_WR64 data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                    $time, cmd_size[19:0], cmd_addr[47:0],
                                    wr_data_q_data_q[127:96], wr_data_q_data_q[95:64],
                                    wr_data_q_data_q[63:32], wr_data_q_data_q[31:0]);
                            s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                            s_axis_tx_tdata <= #TCQ wr_data_q_data_q;
                        `else
                            if (|cmd_addr[47:32]) begin
                                /*if (verbose)*/ $display("%0t: TX MEM_WR64 user data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                        $time, cmd_size[19:0], cmd_addr[47:0],
                                        user_pci_wr_data_q_data_q[127:96], user_pci_wr_data_q_data_q[95:64],
                                        user_pci_wr_data_q_data_q[63:32], user_pci_wr_data_q_data_q[31:0]);
                                s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                                s_axis_tx_tdata <= #TCQ {
                                                user_pci_wr_data_q_data_q[103:96],
                                                user_pci_wr_data_q_data_q[111:104],
                                                user_pci_wr_data_q_data_q[119:112],
                                                user_pci_wr_data_q_data_q[127:120],
                                                user_pci_wr_data_q_data_q[71:64],
                                                user_pci_wr_data_q_data_q[79:72],
                                                user_pci_wr_data_q_data_q[87:80],
                                                user_pci_wr_data_q_data_q[95:88],
                                                user_pci_wr_data_q_data_q[39:32],
                                                user_pci_wr_data_q_data_q[47:40],
                                                user_pci_wr_data_q_data_q[55:48],
                                                user_pci_wr_data_q_data_q[63:56],
                                                user_pci_wr_data_q_data_q[7:0],
                                                user_pci_wr_data_q_data_q[15:8],
                                                user_pci_wr_data_q_data_q[23:16],
                                                user_pci_wr_data_q_data_q[31:24]};
                            end else begin
                                /*if (verbose)*/ $display("%0t: TX MEM_WR32 user data. size:0x%x, addr:0x%x, 0x%x_0x%x_0x%x_0x%x",
                                        $time, cmd_size[19:0], cmd_addr[47:0],
                                        user_pci_wr_data_q_data[127:96], user_pci_wr_data_q_data_q[95:64],
                                        user_pci_wr_data_q_data_q[63:32], user_pci_wr_data_q_data_q[31:0]);
                                if ((cmd_size[11:0] & max_wr_mask) <= 16 && |(cmd_size[11:0] & max_wr_mask))
                                    s_axis_tx_tstrb <= #TCQ {4'h0, 12'hFFF};
                                else
                                    s_axis_tx_tstrb <= #TCQ 16'hFFFF;
                                s_axis_tx_tdata <= #TCQ {
                                                user_pci_wr_data_q_data[7:0],
                                                user_pci_wr_data_q_data[15:8],
                                                user_pci_wr_data_q_data[23:16],
                                                user_pci_wr_data_q_data[31:24],
                                                user_pci_wr_data_q_data_q[103:96],
                                                user_pci_wr_data_q_data_q[111:104],
                                                user_pci_wr_data_q_data_q[119:112],
                                                user_pci_wr_data_q_data_q[127:120],
                                                user_pci_wr_data_q_data_q[71:64],
                                                user_pci_wr_data_q_data_q[79:72],
                                                user_pci_wr_data_q_data_q[87:80],
                                                user_pci_wr_data_q_data_q[95:88],
                                                user_pci_wr_data_q_data_q[39:32],
                                                user_pci_wr_data_q_data_q[47:40],
                                                user_pci_wr_data_q_data_q[55:48],
                                                user_pci_wr_data_q_data_q[63:56]};
                            end
                        `endif //XILINX_ULTRASCALE
                    end // tready
                end
                
                // this state just sets stuff that might otherwise be optimized out, so we can chipscope it.
                STATE_BS : begin
                    s_axis_tx_tlast <= 0;
                    if (s_axis_tx_tlast)
                        s_axis_tx_tdata <= {128{1'b1}};
                    else begin
                        s_axis_tx_tdata <= {128{1'b0}};
                        state           <= STATE_RST;
                    end
                end
            endcase
        end
    end

endmodule // PIO_128_TX_ENGINE
