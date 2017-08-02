// PicoStreamOut.v
// Copyright 2011 Pico Computing, Inc.

//TODO tune the starting sequence numbers to be what the fifos can really handle.
// A lot of the registers in here could be eliminated for a modest timing penalty.

module PicoStreamOut #(
    parameter           ID=1,
    parameter           DESC_FIFO_DEPTH=32
    ) (
    input               clk,
    input               rst,
    
    input               s_valid,
    input      [127:0]  s_data,
    output reg          s_rdy,
    
    input               s_out_en,
    input       [8:0]   s_out_id,
    output reg  [127:0] s_out_data,
    
    input               s_in_valid,
    input [8:0]         s_in_id,
    input [127:0]       s_in_data,
    
    input       [8:0]   s_poll_id,
    output reg  [31:0]  s_poll_seq,
    output reg  [127:0] s_poll_next_desc,
    output reg          s_poll_next_desc_valid,
    
    input       [8:0]   s_next_desc_rd_id,
    input               s_next_desc_rd_en
    );
    
    // construct the full id tag, which is our stream number plus some flags.
    wire [6:0]  id7_wire = ID;
    wire [8:0]  id      = {1'b0 /* non-desc stream */  , 1'b0 /* input stream */, id7_wire};
    wire [8:0]  desc_id = {1'b1 /* descriptor stream */, 1'b0 /* input stream */, id7_wire};
    
    // we can pipeline a lot of things with this fifo that we wouldn't normally, since it'll never be accessed on consecutive cycles.
    reg [127:0]     s0_desc_fifo_din;
    reg             s0_desc_fifo_in_rdy, s0_desc_fifo_wr_en;
    wire            s0_desc_fifo_empty;
    wire [127:0]    s0_desc_fifo_dout;
    reg [31:0]      s0_desc_fifo_seq;
    reg             s0_desc_fifo_rd_en;
    wire [31:0]     s0_desc_next = s0_desc_fifo_din[127:96] + 32'h10;
    
    reg [127:0]     s0_fifo_din;
    reg             s0_fifo_wr_en;
    wire            s0_fifo_almost_full, s0_fifo_empty;
    reg             s0_fifo_almost_full_q;
    wire [127:0]    s0_fifo_dout;
    reg [31:0]      s0_seq;
    reg             rst_q;
    // we could and-in the empty signal here, but if we're asked for data we don't have, things have already gone off the rails.
    `ifdef SIMULATION
    wire s0_fifo_rd_en = ~rst_q && s_out_en && (s_out_id[8:0] == id[8:0]);
    `else
    wire s0_fifo_rd_en = s_out_en && (s_out_id[8:0] == id[8:0]);
    `endif
    
    always @(posedge clk) begin
        rst_q   <= rst;
        
        s0_desc_fifo_din    <= s_in_data[127:0];
        s0_fifo_din         <= s_data;
        
        s_poll_seq  <= 32'h0;
        s_poll_next_desc    <= 128'h0;
        s_poll_next_desc_valid  <= 0;
        
        if (s0_fifo_rd_en)
            s_out_data  <= s0_fifo_dout;
        else
            s_out_data  <= 128'h0;
        
        if (s_poll_id[8:0] == desc_id[8:0]) begin
            s_poll_seq  <= s0_desc_fifo_seq;
        end else if (s_poll_id[8:0] == id[8:0]) begin
            s_poll_seq              <= s0_seq;
            s_poll_next_desc        <= s0_desc_fifo_dout;
            s_poll_next_desc_valid  <= ~s0_desc_fifo_empty;
        end
        
        if (rst) begin
            s0_fifo_wr_en       <= 0;
            s_rdy               <= 0;
            s0_seq              <= 32'h0;
            s0_desc_fifo_wr_en  <= 0;
            s0_desc_fifo_rd_en  <= 0;
            s0_desc_fifo_seq    <= 32'h200;
        end else begin
            s_rdy                   <= ~s0_fifo_almost_full_q;
            s0_fifo_almost_full_q   <= s0_fifo_almost_full;
            s0_desc_fifo_wr_en      <= 0;
            s0_desc_fifo_rd_en      <= 0;
            
            if (s_in_valid && (s_in_id[8:0] == desc_id[8:0])) begin
                s0_desc_fifo_wr_en  <= 1;
            end
            
            s0_fifo_wr_en   <= s_valid && s_rdy;
            
            if (s0_fifo_wr_en)
                s0_seq      <= s0_seq + 16;
            
            if (s_next_desc_rd_en && (s_next_desc_rd_id[8:0] == id[8:0]))
                s0_desc_fifo_rd_en  <= 1;
            
            if (s0_desc_fifo_rd_en)
                s0_desc_fifo_seq    <= s0_desc_fifo_seq + 16;
            
            //if (s0_fifo_wr_en)
            //    $display("%0t: PicoStreamOut writing 0x%x to fifo", $time, s0_fifo_din[31:0]);
            
            //if (s_out_en && (s_out_id[8:0] == id[8:0])) begin
            //    $display("%0t: stream output id 0x%x. pso127 data: 0x%x. empty: %i", $time, s_out_id, s0_fifo_dout[31:0], s0_fifo_empty);
            //end
        end
    end
    
    coregen_fifo_32x128 s0_desc_fifo (
        .clk(clk),
        .rst(rst_q),
        .din(s0_desc_fifo_din),
        .wr_en(s0_desc_fifo_wr_en),
        .rd_en(s0_desc_fifo_rd_en),
        .dout(s0_desc_fifo_dout),
        .empty(s0_desc_fifo_empty)
    );

        fifo_512x128 s0_fifo (
            .clk(clk),
            .rst(rst_q),
            .din(s0_fifo_din),
            .wr_en(s0_fifo_wr_en),
            .rd_en(s0_fifo_rd_en),
            .dout(s0_fifo_dout),
            .empty(s0_fifo_empty),
            .prog_full(s0_fifo_almost_full)
        );

endmodule

