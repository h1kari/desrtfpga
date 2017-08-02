// StreamToPicoBus.v
// Copyright 2015 Pico Computing, Inc.

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

`default_nettype none

module StreamToPicoBus #(
    parameter                   WIDTH=128
) (
    input  wire                 s_clk,
    input  wire                 s_rst,
    
    output wire                 si_ready,
    input  wire                 si_valid,
    input  wire [127:0]         si_data,
    
    input  wire                 so_ready,
    output wire                 so_valid,
    output wire [127:0]         so_data,

    output wire                 PicoClk,
    output reg                  PicoRst,
    output reg  [WIDTH-1:0]     PicoDataIn,
    output reg                  PicoWr,
    input  wire [WIDTH-1:0]     PicoDataOut,
    output reg  [31:0]          PicoAddr,
    output reg                  PicoRd
);
    
    // generate PicoClk using a counter based clk source.
    // the output frequency is roughly 4MHz
    CounterClkGen #(
        .REF_CLK_FREQ(250),
        .OUT_CLK_FREQ(4)
    ) clk_gen (
        .refclk         (s_clk),
        .rst            (s_rst),
        .clk_o          (PicoClk)
    );

    wire                            i_valid;
    wire                            i_rdy;
    wire        [127:0]             i_data;
    wire                            o_valid;
    wire                            o_rdy;
    wire        [127:0]             o_data;

    // async fifos for crossing between stream clk domain and PicoClk domain
    wire so_full;
    wire so_empty;
    FIFO #(.SYNC(0),
           .DATA_WIDTH(128))
    so_fifo (
        .wr_clk     (PicoClk),
        .wr_rst     (PicoRst),
        .wr_en      (o_valid),
        .din        (o_data),
        .full       (so_full),

        .rd_clk     (s_clk),
        .rd_rst     (s_rst),
        .rd_en      (so_ready),
        .dout       (so_data),
        .empty      (so_empty)
    );
    assign so_valid = ~so_empty;
    assign o_rdy = ~so_full;

    wire si_full;
    wire si_empty;
    FIFO #(.SYNC(0),
           .DATA_WIDTH(128))
    si_fifo (
        .wr_clk     (s_clk),
        .wr_rst     (s_rst),
        .wr_en      (si_valid),
        .din        (si_data),
        .full       (si_full),

        .rd_clk     (PicoClk),
        .rd_rst     (PicoRst),
        .rd_en      (i_rdy),
        .dout       (i_data),
        .empty      (si_empty)
    );
    assign si_ready = ~si_full;
    assign i_valid = ~si_empty;
    
    reg         start_wr, rd_active, wr_active;
    reg [31:0]  rd_len, wr_len;
    reg         PicoRd_q;
    reg         rst_q;
    
    reg [127:0] cmd;
    reg         cmd_valid;
    
    // handle carefully about crossing reset signal from fast clock domain
    // to slow clock domain. use a two way hand shake
    reg rst_q_=0;
    reg [7:0] PicoRst_q=0;
    reg [7:0] PicoRst_qq=0;
    always @(posedge s_clk) begin
        if (s_rst) begin
            rst_q_ <= 1'b1;
        end else begin
            // deasert rst_q_ when capture assertion of PicoRst in PicoClk 
            // domain
            if (PicoRst_qq[7]) rst_q_<=0;
        end
        PicoRst_qq <= {PicoRst_qq[6:0], PicoRst_q[7]};
    end

    reg [3:0] rst_qq_=0;
    always @(posedge PicoClk) begin
        rst_qq_ <= {rst_qq_[2:0], rst_q_};
        rst_q <= rst_qq_[3];
        PicoRst <= rst_q;
        PicoRst_q <= {PicoRst_q[6:0], PicoRst};
    end

    always @(posedge PicoClk) begin
        if (rst_q) begin
            cmd_valid   <= 0;
        end else begin
            cmd_valid       <= 0;
            if (i_valid && ~rd_active && ~wr_active && ~cmd_valid) begin
                cmd_valid   <= 1;
                cmd         <= i_data;
            end
        end
    end
    
    generate if (WIDTH == 128) begin:W128
        
        assign i_rdy = ~rd_active && ~cmd_valid;
        assign o_valid = PicoRd_q;
        assign o_data = PicoDataOut[127:0];
        
        always @(posedge PicoClk) begin
            if (rst_q) begin
                rd_active   <= 0;
                wr_active   <= 0;
            end
            
            PicoRd  <= 0;
            PicoWr  <= 0;
            PicoRd_q<= PicoRd;
            
            if (cmd_valid /*&& ~rd_active && ~wr_active*/) begin
                if (cmd[64]) begin
                    rd_len      <= cmd[31:0];
                    PicoAddr  <= {cmd[63:32+4], 4'h0};
                    rd_active   <= 1;
                end else begin
                    wr_len      <= cmd[31:0];
                    PicoAddr  <= {cmd[63:32+4], 4'h0};
                    start_wr    <= 1;
                    wr_active   <= 1;
                end
            end
            
            if (i_valid) begin
                
                if (wr_active) begin
                    wr_len      <= wr_len - 16;
                    PicoDataIn  <= i_data[127:0];
                    PicoWr      <= 1;
                    if (~start_wr)
                        PicoAddr  <= PicoAddr + 16;
                    start_wr    <= 0;
                    if (wr_len == 32'h10)
                        wr_active   <= 0;
                end
            end
            
            // we'll fire a read every 3 clock cycles when the output is ready.
            // we could fire one every cycle if we had our own fifo with an almost-full flag, but this is good enough.
            if (o_rdy && |rd_active) begin
                if (~PicoRd && ~PicoRd_q)
                    PicoRd      <= 1;
                if (PicoRd_q) begin
                    rd_len      <= rd_len - 16;
                    PicoAddr  <= PicoAddr + 16;
                    if (rd_len == 32'h10)
                        rd_active   <= 0;
                end
            end
        end
        
    end else if (WIDTH == 32) begin:W32
    
        reg [1:0]   wr_byte, rd_byte;
        reg         o_valid_reg;
        reg [127:0] o_data_reg;
        
        assign i_rdy = (~rd_active && ~wr_active && ~cmd_valid) || (wr_active && ((wr_byte == 2'h3) || (wr_len == 32'h4)));
        assign o_valid = o_valid_reg;
        assign o_data = o_data_reg;
        
        always @(posedge PicoClk) begin
            if (rst_q) begin
                rd_active   <= 0;
                wr_active   <= 0;
            end
            
            //if (PicoRd)     $display("%0t: PicoRd @ 0x%x", $time, PicoAddr);
            //if (PicoRd_q)   $display("%0t: PicoRd data 0x%x", $time, PicoDataOut[31:0]);
            //if (PicoWr)     $display("%0t: PicoWr @ 0x%x. data: 0x%x", $time, PicoAddr, PicoDataIn[31:0]);
            
            PicoRd  <= 0;
            PicoWr  <= 0;
            PicoRd_q<= PicoRd;
            
            if (cmd_valid /*&& ~rd_active && ~wr_active*/) begin
                if (cmd[64]) begin
                    rd_len      <= cmd[31:0];
                    PicoAddr  <= {cmd[63:32+2], 2'h0};
                    rd_byte     <= 2'h0;
                    rd_active   <= 1;
                end else begin
                    wr_len      <= cmd[31:0];
                    PicoAddr  <= {cmd[63:32+2], 2'h0};
                    wr_byte     <= 2'h0;
                    start_wr    <= 1;
                    wr_active   <= 1;
                end
            end
            
            if (wr_active && (~i_rdy || i_valid  || (wr_len == 32'h4))) begin
                wr_len      <= wr_len - 4;
                if      (wr_byte == 2'h0)   PicoDataIn <= i_data[31:0];
                else if (wr_byte == 2'h1)   PicoDataIn <= i_data[63:32];
                else if (wr_byte == 2'h2)   PicoDataIn <= i_data[95:64];
                else if (wr_byte == 2'h3)   PicoDataIn <= i_data[127:96];
                wr_byte     <= wr_byte + 1;
                PicoWr      <= 1;
                if (~start_wr)
                    PicoAddr  <= PicoAddr + 4;
                start_wr    <= 0;
                if (wr_len == 32'h4)
                    wr_active   <= 0;
            end
            
            // we'll fire a read every 3 clock cycles when the output is ready.
            // we could fire one every cycle if we had our own fifo with an almost-full flag, but this is good enough.
            if (o_rdy && |rd_active) begin
                if (~PicoRd && ~PicoRd_q)
                    PicoRd      <= 1;
                if (PicoRd_q) begin
                    rd_len      <= rd_len - 4;
                    PicoAddr  <= PicoAddr + 4;
                    if (rd_len == 32'h4)
                        rd_active   <= 0;
                end
            end
            
            // assemble the PicoDataOut into the 128b register for stream output.
            // (this should be able to handle any number of 32b words, not just multiples of 4. so we may send out partial 128b words.)
            o_valid_reg <= PicoRd_q && ((rd_byte == 2'h3) || (rd_len == 32'h4));
            if (PicoRd_q) begin
                rd_byte <= rd_byte + 1;
                if      (rd_byte == 2'h0)   o_data_reg[31:0]    <= PicoDataOut;
                else if (rd_byte == 2'h1)   o_data_reg[63:32]   <= PicoDataOut;
                else if (rd_byte == 2'h2)   o_data_reg[95:64]   <= PicoDataOut;
                else if (rd_byte == 2'h3)   o_data_reg[127:96]  <= PicoDataOut;
            end
        end
    
    end endgenerate
    
endmodule

`default_nettype wire

