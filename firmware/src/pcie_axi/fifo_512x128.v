// FIFO_512x128.v
// Copyright 2011, Pico Computing, Inc.

// This is designed for a single clock domain. If you modify it for asynchronous use, be sure to handle empty/full flags correctly. (ie - consider all of them.)

//TODO the hard fifos don't support fwft in sync mode. wtf? might want to rewrite this with our own fwft in sync mode to avoid or-ing full/empty together.

// JBC 8/23/2012 - add relative loc constraint to help ease timing

`include "PicoDefines.v"

module fifo_512x128 #(
    parameter ALMOST_FULL_OFFSET = 13'h10
    ) (
    input           clk,
    input           rst,
    input [127:0]   din,
    input [15:0]    dinp,
    input           wr_en,
    input           rd_en,
    output [127:0]  dout,
    output [15:0]   doutp,
    output reg      full,
    output          empty_direct,
    output reg      empty,
    output          prog_full,
    output          prog_empty);
    
    wire [1:0] full_wire, empty_wire;

    assign empty_direct = |empty_wire;
    
    always @(posedge clk) begin
        full        <= |full_wire;
        empty       <= prog_empty && (|empty_wire || rd_en);
    end

        `ifdef XILINX_ULTRASCALE
        // we pull the counts and some other stuff from the first fifo, but not the others.
        //   the wonderfully flexible generate syntax doesn't let us push the 'if' into the instantiation, so here goes:
            FIFO36E2 #(
                    .PROG_FULL_THRESH           (13'h200 - ALMOST_FULL_OFFSET),
                    .PROG_EMPTY_THRESH          (13'h10),
                    .WRITE_WIDTH                (72),
                    .READ_WIDTH                 (72),
                    .REGISTER_MODE              ("REGISTERED"),
                    .CLOCK_DOMAINS              ("INDEPENDENT"),
                    .FIRST_WORD_FALL_THROUGH    ("TRUE")
            )
            fifo1 (
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.DBITERR(DBITERR), // 1-bit double bit error status output
                //.ECCPARITY(ECCPARITY), // 8-bit generated error correction parity
                //.SBITERR(SBITERR), // 1-bit single bit error status output
                // Read Data: 64-bit (each) Read output data
                .DOUT(dout[63:0]), // 64-bit data output
                .DOUTP(doutp[7:0]), // 8-bit parity data output
                // Status: 1-bit (each) Flags and other FIFO status outputs
                .PROGEMPTY(prog_empty), // 1-bit almost empty output flag
                .PROGFULL(prog_full), // 1-bit almost full output flag
                .EMPTY(empty_wire[0]), // 1-bit empty output flag
                .FULL(full_wire[0]), // 1-bit full output flag
                //.RDCOUNT(FifoReadCount[8:0]), // 9-bit read count output
                //.RDERR(RDERR), // 1-bit read error output
                //.WRCOUNT(FifoWriteCount[8:0]), // 9-bit write count output
                //.WRERR(WRERR), // 1-bit write error
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.INJECTDBITERR(INJECTDBITERR),
                //.INJECTSBITERR(INJECTSBITERR),
                // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
                .RDCLK(clk), // 1-bit read clock input
                .RDEN(rd_en), // 1-bit read enable input
                .REGCE(1'b1), // 1-bit clock enable input
                .RST(rst), // 1-bit reset input
                //.RSTREG(RSTREG), // 1-bit output register set/reset
                // Write Control Signals: 1-bit (each) Write clock and enable input signals
                .WRCLK(clk), // 1-bit write clock input
                .WREN(wr_en), // 1-bit write enable input
                // Write Data: 64-bit (each) Write input data
                .DIN(din[63:0]), // 64-bit data input
                .DINP(dinp[7:0]) // 8-bit parity input
            );
            
            FIFO36E2 #(
                    .PROG_FULL_THRESH           (13'h200 - ALMOST_FULL_OFFSET),
                    .PROG_EMPTY_THRESH          (13'h10),
                    .WRITE_WIDTH                (72),
                    .READ_WIDTH                 (72),
                    .REGISTER_MODE              ("REGISTERED"),
                    .CLOCK_DOMAINS              ("INDEPENDENT"),
                    .FIRST_WORD_FALL_THROUGH    ("TRUE")
            )
            fifo2 (
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.DBITERR(DBITERR), // 1-bit double bit error status output
                //.ECCPARITY(ECCPARITY), // 8-bit generated error correction parity
                //.SBITERR(SBITERR), // 1-bit single bit error status output
                // Read Data: 64-bit (each) Read output data
                .DOUT(dout[127:64]), // 64-bit data output
                .DOUTP(doutp[15:8]), // 8-bit parity data output
                // Status: 1-bit (each) Flags and other FIFO status outputs
                //.ALMOSTEMPTY(FifoAlmostEmpty[i]), // 1-bit almost empty output flag
                //.ALMOSTFULL(FifoAlmostFull[i]), // 1-bit almost full output flag
                .EMPTY(empty_wire[1]), // 1-bit empty output flag
                .FULL(full_wire[1]), // 1-bit full output flag
                //.RDCOUNT(FifoReadCount[i][8:0]), // 9-bit read count output
                //.RDERR(RDERR), // 1-bit read error output
                //.WRCOUNT(FifoWriteCount[i][8:0]), // 9-bit write count output
                //.WRERR(WRERR), // 1-bit write error
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.INJECTDBITERR(INJECTDBITERR),
                //.INJECTSBITERR(INJECTSBITERR),
                // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
                .RDCLK(clk), // 1-bit read clock input
                .RDEN(rd_en), // 1-bit read enable input
                .REGCE(1'b1), // 1-bit clock enable input
                .RST(rst), // 1-bit reset input
                //.RSTREG(RSTREG), // 1-bit output register set/reset
                // Write Control Signals: 1-bit (each) Write clock and enable input signals
                .WRCLK(clk), // 1-bit write clock input
                .WREN(wr_en), // 1-bit write enable input
                // Write Data: 64-bit (each) Write input data
                .DIN(din[127:64]), // 64-bit data input
                .DINP(dinp[15:8]) // 8-bit parity input
            );
        `else
        // we pull the counts and some other stuff from the first fifo, but not the others.
        //   the wonderfully flexible generate syntax doesn't let us push the 'if' into the instantiation, so here goes:
            (* RLOC = "X0Y0" *)
            FIFO36E1 #(
                .ALMOST_EMPTY_OFFSET(13'h10), // Sets the almost empty threshold
                .ALMOST_FULL_OFFSET(ALMOST_FULL_OFFSET), // Sets almost full threshold
                .DATA_WIDTH(72), // Sets data width to 4, 9, 18, 36, or 72
                .DO_REG(1), // Enable output register (0 or 1) Must be 1 if EN_SYN = "FALSE"
                .EN_ECC_READ("FALSE"), // Enable ECC decoder, "TRUE" or "FALSE"
                .EN_ECC_WRITE("FALSE"), // Enable ECC encoder, "TRUE" or "FALSE"
                .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE") or Synchronous ("TRUE")
                .FIFO_MODE("FIFO36_72"), // Sets mode to FIFO36 or FIFO36_72
                .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
            )
            fifo1 (
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.DBITERR(DBITERR), // 1-bit double bit error status output
                //.ECCPARITY(ECCPARITY), // 8-bit generated error correction parity
                //.SBITERR(SBITERR), // 1-bit single bit error status output
                // Read Data: 64-bit (each) Read output data
                .DO(dout[63:0]), // 64-bit data output
                .DOP(doutp[7:0]), // 8-bit parity data output
                // Status: 1-bit (each) Flags and other FIFO status outputs
                .ALMOSTEMPTY(prog_empty), // 1-bit almost empty output flag
                .ALMOSTFULL(prog_full), // 1-bit almost full output flag
                .EMPTY(empty_wire[0]), // 1-bit empty output flag
                .FULL(full_wire[0]), // 1-bit full output flag
                //.RDCOUNT(FifoReadCount[8:0]), // 9-bit read count output
                //.RDERR(RDERR), // 1-bit read error output
                //.WRCOUNT(FifoWriteCount[8:0]), // 9-bit write count output
                //.WRERR(WRERR), // 1-bit write error
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.INJECTDBITERR(INJECTDBITERR),
                //.INJECTSBITERR(INJECTSBITERR),
                // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
                .RDCLK(clk), // 1-bit read clock input
                .RDEN(rd_en), // 1-bit read enable input
                .REGCE(1'b1), // 1-bit clock enable input
                .RST(rst), // 1-bit reset input
                //.RSTREG(RSTREG), // 1-bit output register set/reset
                // Write Control Signals: 1-bit (each) Write clock and enable input signals
                .WRCLK(clk), // 1-bit write clock input
                .WREN(wr_en), // 1-bit write enable input
                // Write Data: 64-bit (each) Write input data
                .DI(din[63:0]), // 64-bit data input
                .DIP(dinp[7:0]) // 8-bit parity input
            );
            
            (* RLOC = "X0Y1" *)
            FIFO36E1 #(
                .ALMOST_EMPTY_OFFSET(13'h10), // Sets the almost empty threshold
                .ALMOST_FULL_OFFSET(13'h10), // Sets almost full threshold
                .DATA_WIDTH(72), // Sets data width to 4, 9, 18, 36, or 72
                .DO_REG(1), // Enable output register (0 or 1) Must be 1 if EN_SYN = "FALSE"
                .EN_ECC_READ("FALSE"), // Enable ECC decoder, "TRUE" or "FALSE"
                .EN_ECC_WRITE("FALSE"), // Enable ECC encoder, "TRUE" or "FALSE"
                .EN_SYN("FALSE"), // Specifies FIFO as Asynchronous ("FALSE") or Synchronous ("TRUE")
                .FIFO_MODE("FIFO36_72"), // Sets mode to FIFO36 or FIFO36_72
                .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
            )
            fifo2 (
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.DBITERR(DBITERR), // 1-bit double bit error status output
                //.ECCPARITY(ECCPARITY), // 8-bit generated error correction parity
                //.SBITERR(SBITERR), // 1-bit single bit error status output
                // Read Data: 64-bit (each) Read output data
                .DO(dout[127:64]), // 64-bit data output
                .DOP(doutp[15:8]), // 8-bit parity data output
                // Status: 1-bit (each) Flags and other FIFO status outputs
                //.ALMOSTEMPTY(FifoAlmostEmpty[i]), // 1-bit almost empty output flag
                //.ALMOSTFULL(FifoAlmostFull[i]), // 1-bit almost full output flag
                .EMPTY(empty_wire[1]), // 1-bit empty output flag
                .FULL(full_wire[1]), // 1-bit full output flag
                //.RDCOUNT(FifoReadCount[i][8:0]), // 9-bit read count output
                //.RDERR(RDERR), // 1-bit read error output
                //.WRCOUNT(FifoWriteCount[i][8:0]), // 9-bit write count output
                //.WRERR(WRERR), // 1-bit write error
                // ECC Signals: 1-bit (each) Error Correction Circuitry ports
                //.INJECTDBITERR(INJECTDBITERR),
                //.INJECTSBITERR(INJECTSBITERR),
                // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
                .RDCLK(clk), // 1-bit read clock input
                .RDEN(rd_en), // 1-bit read enable input
                .REGCE(1'b1), // 1-bit clock enable input
                .RST(rst), // 1-bit reset input
                //.RSTREG(RSTREG), // 1-bit output register set/reset
                // Write Control Signals: 1-bit (each) Write clock and enable input signals
                .WRCLK(clk), // 1-bit write clock input
                .WREN(wr_en), // 1-bit write enable input
                // Write Data: 64-bit (each) Write input data
                .DI(din[127:64]), // 64-bit data input
                .DIP(dinp[15:8]) // 8-bit parity input
            );
        `endif //XILINX_ULTRASCALE
endmodule

