// Reorder.v
// Copyright 2012 Pico Computing, Inc.

// tag_en must be valid one cycle before the associated data_in_en.


module Reorder #(
    parameter       W = 128
)
(
    input           clk,
    input           rst,
    input [7:0]     tag_in,
    input           tag_en,
    input [7:0]     rem_count,
    input [W-1:0]   data_in,
    input           data_in_en,
    input           tag_seq_end_in_en,
    input [31:0]    tag_seq_end_in,
    input [7:0]     tag_seq_end_in_tag,
    output reg      data_out_en,
    output reg [W-1:0]   data_out,
    output reg [7:0]     tag_out
    );

    localparam BUF_SIZE = 512;
    localparam LOG_BUF_SIZE = 9;

    reg [7:0]   tag_arr [BUF_SIZE-1:0], cur_tag;

    // this is the data buffer itself.
    reg [W-1:0] data_arr [BUF_SIZE-1:0], cur_data;
    always @(posedge clk) begin
        
    end

    // this array stores the offsets of each tag into our data buffer.
    (* ram_style = "distributed" *) reg [LOG_BUF_SIZE-1:0]  tag_seq_end [255:0];
    always @(posedge clk) begin
        if (tag_seq_end_in_en)
            tag_seq_end[tag_seq_end_in_tag] <= tag_seq_end_in[LOG_BUF_SIZE-1:0]; // we don't need all the bits, just enough to index our buffer
    end

    reg [BUF_SIZE-1:0]      id_arr , id_arr_shadow = {BUF_SIZE{1'b0}};
    reg                     cur_id;
    reg [LOG_BUF_SIZE-1:0]  rd_addr, rd_addr_q;
    reg                     do_rd, do_rd_q;

    wire                    cur_id_valid = (cur_id == id_arr[rd_addr]);

    always @(posedge clk) begin
        do_rd   <= 0;
        data_out    <= {W{1'h0}};
        data_out_en <= 0;
        rd_addr_q   <= rd_addr;
        do_rd_q     <= do_rd;

        cur_data    <= data_arr[rd_addr_q];
        cur_tag     <= tag_arr[rd_addr_q];
        if (do_rd_q) begin
            data_out_en <= 1;
            data_out    <= cur_data;
            tag_out     <= cur_tag;
        end

        if (rst) begin
            rd_addr <= {LOG_BUF_SIZE{1'b0}};
            cur_id  <= 1'h1;
        end else begin
            if (cur_id_valid) begin
                rd_addr <= rd_addr + 1;
                // this seems heavy. really we could just add another bit to the top of rd_addr and use that as our cur_id
                // (but that makes rd_addr less obvious.)
                if (rd_addr == (BUF_SIZE-1))
                    cur_id  <= ~cur_id;
                do_rd   <= 1;
            end
        end
    end

    reg [7:0]               wr_offset;
    reg [7:0]               tag_latch;
    reg [LOG_BUF_SIZE-1:0]  tse_1, tse_1_p;
    reg [W-1:0]             data_in_1;
    reg                     data_in_en_1;
    reg                     do_wr;
    reg                     wr_data;
    reg [LOG_BUF_SIZE-1:0]  wr_addr_q;
    reg                     tag_en_1    = 0;
    reg [7:0]               rem_count_1 = 0;
    reg [7:0]               tag_in_1    = 0;

    wire [LOG_BUF_SIZE-1:0] wr_addr = tse_1 - wr_offset;
    wire shadow_id = ~id_arr_shadow[wr_addr];

    always @(posedge clk) begin
        // first clock cycle on tag_en
        tse_1 <= tse_1_p;
        if (tag_en) begin
            tse_1_p       <= tag_seq_end[tag_in];
        end
        tag_in_1        <= tag_in;
        tag_en_1        <= tag_en;
        rem_count_1     <= rem_count;
        if (tag_en_1) begin
            wr_offset   <= rem_count_1;
            tag_latch   <= tag_in_1;
        end else if (data_in_en_1) begin
            wr_offset   <= wr_offset - 1;
        end
        data_in_1   <= data_in;
        data_in_en_1<= data_in_en;
        do_wr <= 0;
        wr_addr_q <= wr_addr;
        if (rst) begin
            
        end else begin
            if (data_in_en_1) begin
                //$display("reordering data with tag 0x%x at addr 0x%x, id: 0x%x", tag_latch, wr_addr, ~id_arr_shadow[wr_addr]);
                //$display("tse_1: 0x%x, wr_offset: 0x%x", tse_1, wr_offset);
                // the tag will show up a cycle late, because we need to register it.
                do_wr <= 1;
                wr_data <= shadow_id;
                data_arr[wr_addr]       <= data_in_1;
                tag_arr[wr_addr]        <= tag_latch;
            end
            if (do_wr) begin
                id_arr[wr_addr_q]         <= wr_data;
                id_arr_shadow[wr_addr_q]  <= wr_data;
            end
        end
    end

endmodule
