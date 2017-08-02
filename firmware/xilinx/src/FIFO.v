// FIFO.v
// Copyright 2014, Pico Computing, Inc.

`include "PicoDefines.v"

module FIFO # (
    parameter SYNC = 1,
    parameter DATA_WIDTH = 128,
    parameter ALMOST_FULL = 13'h100,
    parameter ALMOST_EMPTY = 13'h10
    ) (
    input  wire                     clk,
    input  wire                     rst,

    input  wire                     rd_clk,
    input  wire                     rd_rst,
    input  wire                     rd_en,
    output wire  [DATA_WIDTH-1:0]   dout,
    output wire                     empty,
    output wire                     almostempty,

    input  wire                     wr_clk,
    input  wire                     wr_rst,
    input  wire                     wr_en,
    input  wire  [DATA_WIDTH-1:0]   din,
    output wire                     full,
    output wire                     almostfull
    );

    wire rd_clk_int;
    wire wr_clk_int;
    wire rst_int;

    generate 
        if (SYNC) begin
            assign rd_clk_int = clk;
            assign wr_clk_int = clk;
            reg [4:0] power_on_rst_reg = 5'b11111;
            reg [4:0] rst_q = 5'b11111;
            always @ (posedge clk) begin
                power_on_rst_reg <= {power_on_rst_reg[3:0], 1'b0};
                rst_q <= {rst_q[3:0], rst};
            end
            assign rst_int = power_on_rst_reg[4] | rst_q[4];

        end else begin
            assign rd_clk_int = rd_clk;
            assign wr_clk_int = wr_clk;
            reg [4:0] power_on_rd_rst_reg = 5'b11111;
            reg [4:0] power_on_wr_rst_reg = 5'b11111;
            reg [4:0] rd_rst_q = 5'b11111;
            reg [4:0] wr_rst_q = 5'b11111;
            always @ (posedge rd_clk) begin
                power_on_rd_rst_reg <= {power_on_rd_rst_reg[3:0], 1'b0};
                rd_rst_q <= {rd_rst_q[3:0], rd_rst};
            end
            always @ (posedge wr_clk) begin
                power_on_wr_rst_reg <= {power_on_wr_rst_reg[3:0], 1'b0};
                wr_rst_q <= {wr_rst_q[3:0], wr_rst};
            end

            assign rst_int = power_on_rd_rst_reg[4] | rd_rst_q[4] | power_on_wr_rst_reg[4] | wr_rst_q[4];
        end
    endgenerate

    localparam ACTUAL_WIDTH = DATA_WIDTH > 36 ? (DATA_WIDTH/72+1) * 72 : 36;
    localparam N = DATA_WIDTH > 36 ? DATA_WIDTH/72+1: 1;
    //////////////////////
    // internal signals //
    //////////////////////


    wire   [ACTUAL_WIDTH-1:0] din_int;
    wire   [ACTUAL_WIDTH-1:0] dout_int;

    wire   rd_en_int, wr_en_int;
    assign rd_en_int = !empty & rd_en;
    assign wr_en_int = !full & wr_en;

    assign din_int = {72'h0, din};
  
    wire [N-1:0] full_int, empty_int, afull_int, aempty_int;
    
    assign full = |full_int;
    assign empty = |empty_int;
    assign almostfull = |afull_int;
    assign almostempty = |aempty_int;
    assign dout = dout_int[DATA_WIDTH-1:0];

    ///////////
    // FIFOS //
    ///////////
    genvar i;
    generate
        if (DATA_WIDTH > 36) begin
            for(i = 0; i < N; i=i+1) begin: FIFO36
                `ifdef XILINX_ULTRASCALE
                    FIFO36E2 #(
                        .PROG_FULL_THRESH           (ALMOST_FULL),
                        .PROG_EMPTY_THRESH          (ALMOST_EMPTY),
                        .WRITE_WIDTH                (72),
                        .READ_WIDTH                 (72),
                        .REGISTER_MODE              ("REGISTERED"),
                        .CLOCK_DOMAINS              ("INDEPENDENT"),
                        .FIRST_WORD_FALL_THROUGH    ("TRUE")
                    ) __fifo__ (
                        .WRCLK      (wr_clk_int),
                        .WREN       (wr_en_int),
                        .WRCOUNT    (),
                        .WRERR      (),
                        .WRRSTBUSY  (),
                        .DIN        (din_int[(i*72)+63:(i*72)]),
                        .DINP       (din_int[(i*72)+71:(i*72)+64]),
                        .RDCLK      (rd_clk_int),
                        .RDEN       (rd_en_int & ~empty_int[i]),
                        .RDCOUNT    (),
                        .RDERR      (),
                        .REGCE      (1'b1),
                        .RST        (rst_int),
                        .RSTREG     (1'b0),
                        .RDRSTBUSY  (),
                        .SLEEP      (1'b0),
                        .DOUT       (dout_int[(i*72)+63:(i*72)]),
                        .DOUTP      (dout_int[(i*72)+71:(i*72)+64]),
                        .EMPTY      (empty_int[i]),
                        .PROGEMPTY  (aempty_int[i]),
                        .FULL       (full_int[i]),
                        .PROGFULL   (afull_int[i])
                    );
                `else  
                    FIFO36E1 #(
                        .ALMOST_FULL_OFFSET         (13'h200 - ALMOST_FULL),
                        .ALMOST_EMPTY_OFFSET        (ALMOST_EMPTY),
                        .DATA_WIDTH                 (72),
                        .DO_REG                     (1),
                        .EN_SYN                     ("FALSE"),
                        .FIFO_MODE                  ("FIFO36_72"),
                        .FIRST_WORD_FALL_THROUGH    ("TRUE"),
                        .SIM_DEVICE                 ("7SERIES")
                    ) __fifo__ (
                        .WRCLK      (wr_clk_int),
                        .WREN       (wr_en_int),
                        .DI         (din_int[(i*72)+63:(i*72)]),
                        .DIP        (din_int[(i*72)+71:(i*72)+64]),
                        .RDCLK      (rd_clk_int),
                        .RDEN       (rd_en_int & ~empty_int[i]),
                        .REGCE      (1'b1),
                        .RST        (rst_int),
                        .RSTREG     (1'b0),
                        .DO         (dout_int[(i*72)+63:(i*72)]),
                        .DOP        (dout_int[(i*72)+71:(i*72)+64]),
                        .EMPTY      (empty_int[i]),
                        .ALMOSTEMPTY(aempty_int[i]),
                        .FULL       (full_int[i]),
                        .ALMOSTFULL (afull_int[i])
                    );
                `endif //XILINX_ULTRASCALE
            end
        end else begin: FIFO18
            `ifdef XILINX_ULTRASCALE
                 FIFO18E2 #(
                        .PROG_FULL_THRESH           (ALMOST_FULL),
                        .PROG_EMPTY_THRESH          (ALMOST_EMPTY),
                        .WRITE_WIDTH                (36),
                        .READ_WIDTH                 (36),
                        .REGISTER_MODE              ("REGISTERED"),
                        .CLOCK_DOMAINS              ("INDEPENDENT"),
                        .FIRST_WORD_FALL_THROUGH    ("TRUE")
                ) __fifo__ (
                    .WRCLK      (wr_clk_int),
                    .WREN       (wr_en_int),
                    .WRCOUNT    (),
                    .WRERR      (),
                    .WRRSTBUSY  (),
                    .DIN        (din_int[31:0]),
                    .DINP       (din_int[35:32]),
                    .RDCLK      (rd_clk_int),
                    .RDEN       (rd_en_int & ~empty_int[0]),
                    .RDCOUNT    (),
                    .RDERR      (),
                    .REGCE      (1'b1),
                    .RST        (rst_int),
                    .RSTREG     (1'b0),
                    .RDRSTBUSY  (),
                    .SLEEP      (1'b0),
                    .DOUT       (dout_int[31:0]),
                    .DOUTP      (dout_int[35:32]),
                    .EMPTY      (empty_int[0]),
                    .PROGEMPTY  (aempty_int[0]),
                    .FULL       (full_int[0]),
                    .PROGFULL   (afull_int[0])
                );
            `else
                FIFO18E1 #(
                    .ALMOST_FULL_OFFSET         (13'h200 - ALMOST_FULL),
                    .ALMOST_EMPTY_OFFSET        (ALMOST_EMPTY),
                    .DATA_WIDTH                 (36),
                    .DO_REG                     (1),
                    .EN_SYN                     ("FALSE"),
                    .FIFO_MODE                  ("FIFO18_36"),
                    .FIRST_WORD_FALL_THROUGH    ("TRUE"),
                    .SIM_DEVICE                 ("7SERIES")
                ) __fifo__ (
                    .WRCLK      (wr_clk_int),
                    .WREN       (wr_en_int),
                    .DI         (din_int[31:0]),
                    .DIP        (din_int[35:32]),
                    .RDCLK      (rd_clk_int),
                    .RDEN       (rd_en_int & ~empty_int[0]),
                    .REGCE      (1'b1),
                    .RST        (rst_int),
                    .RSTREG     (1'b0),
                    .DO         (dout_int[31:0]),
                    .DOP        (dout_int[35:32]),
                    .EMPTY      (empty_int[0]),
                    .ALMOSTEMPTY(aempty_int[0]),
                    .FULL       (full_int[0]),
                    .ALMOSTFULL (afull_int[0])
                );
            `endif //XILINX_ULTRASCALE
        end
    endgenerate
endmodule

