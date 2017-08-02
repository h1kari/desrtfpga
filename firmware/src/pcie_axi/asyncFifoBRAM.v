/*
* File Name : asyncFifoBRAM.v
*
* Description :  Asynchronous fifo implemented using Xilinx primitives (FIFO36E1).  
*                This module has a parameterizeable width and supports the
*                generation of FIFOs up to 360 bits wide.  Since these are
*                implemented in BRAM, the depth is a fixed number of entries
*                (512). 
*
* Creation Date : Tue 23 Aug 2011 01:54:35 PM PDT
*
* Author : Corey Olson
*
* Last Modified : Thu 23 Feb 2012 03:49:41 PM PST
*
* Copyright 2011 Pico Computing, Inc.
*/
module asyncFifoBRAM #(
        parameter WIDTH         = 128,      // range = 1 - 360
        parameter OFFSET        = 13'h10    // valid range = 4 to 507
    )
    (
    // ports
    input                   wr_clk,
    input                   wr_rst,
    input                   rd_clk,
    input                   rd_rst,
    input       [WIDTH-1:0] din,
    input                   wr_en,
    input                   rd_en,
    output  reg [WIDTH-1:0] dout=0,
    output  reg             full=1,
    output  reg             empty=1
    );

    //////////////////////
    // internal signals //
    //////////////////////
    reg     [WIDTH-1:0] din_q;
    reg     [WIDTH-1:0] middleDin;
    wire    [359:0]     dataIn;
    wire    [359:0]     dataOut;
    
    reg                 middleFull;
    wire                fifoFull;
    wire    [4:0]       bramFifoFull;
    wire    [4:0]       bramFifoAFull;
    wire    [4:0]       bramFifoEmpty;
    wire    [4:0]       bramFifoAEmpty;
    wire                fifoEmpty;
    wire                fifoAlmostEmpty;

    reg                 validDin_q=0;
    reg                 validMiddleDin=0;

    reg                 readFifo=0;
    wire                writeFifo;
    
    reg                 rd_rst_q=0;
    
    reg                 wr_rst_q=0;

    // register both reset signals
    // delay the read reset by 4 clock cycles so the FIFO
    // will produce non-X data
    always @ (posedge rd_clk) begin
        rd_rst_q <= rd_rst;
    end
    always @ (posedge wr_clk) begin
        wr_rst_q <= wr_rst;
    end
    
    ///////////////////////////
    // buffer the input data //
    ///////////////////////////

    // these signals simply delay the almost full signal (from the BRAM) by
    // 2 clock cycles to the output of this FIFO module
    always @ (posedge wr_clk) begin
        if (wr_rst_q) begin
            full        <= 1;
            middleFull  <= 1;
        end else begin
            full        <= middleFull;
            middleFull  <= fifoFull;
        end
    end
    
    // buffer write data on the input to the fifo
    // notes: 
    // -the almost full flag (set to 3) is delayed by 2 clock cycles to the
    // output of this fifo (where it is used as the full signal)
    // -these input buffers only accept data from the inputs if full is
    // deasserted and wr_en is asserted at the input
    // -therefore, these input buffers should never have to stall with valid
    // data sitting in them
    always @ (posedge wr_clk) begin
        if (wr_rst_q) begin
            din_q           <= 0;
            validDin_q      <= 0;
            middleDin       <= 0;
            validMiddleDin  <= 0;
        end else begin
            din_q           <= din;
            validDin_q      <= wr_en & ~full;
            middleDin       <= din_q;
            validMiddleDin  <= validDin_q;
        end
    end

    ///////////
    // FIFOS //
    ///////////
    
    // write data from the middle input buffer (only when it holds valid data)
    assign writeFifo        = (validMiddleDin === 1'b1) & ~wr_rst_q;
    assign dataIn           = middleDin;
    
    // if any fifo is full, then all should be considered full
    //assign fifoFull         = |bramFifoFull;
    assign fifoFull         = |bramFifoAFull;

    // if any fifo is empty, then all should be considered empty
    assign fifoEmpty        = |bramFifoEmpty;
    assign fifoAlmostEmpty  = |bramFifoAEmpty;

    // this fifo is always used
    (* RLOC = "X0Y0" *)
    FIFO36E1 #(
        .ALMOST_FULL_OFFSET         (OFFSET),       // asserted when fifo has this many empty spaces left
        .ALMOST_EMPTY_OFFSET        (OFFSET),       // asserted when fifo has
                                                    //  less than this many full spaces
        
        .DATA_WIDTH                 (72),           // Sets data width to 4, 9, 18, 36, or 72
        .DO_REG                     (1),            // Enable output register (0 or 1) Must be 
                                                    //  1 if EN_SYN = "FALSE"
        .EN_ECC_READ                ("FALSE"),      // Enable ECC decoder, "TRUE" or "FALSE"
        .EN_ECC_WRITE               ("FALSE"),      // Enable ECC encoder, "TRUE" or "FALSE"
        .EN_SYN                     ("FALSE"),      // Specifies FIFO as Asynchronous ("FALSE") 
                                                    //  or Synchronous ("TRUE")
        .FIFO_MODE                  ("FIFO36_72"),  // Sets mode to FIFO36 or FIFO36_72
        .FIRST_WORD_FALL_THROUGH    ("TRUE")        // Sets the FIFO FWFT to "TRUE" or "FALSE"
    )
    fifo0
    (
        // Write Control Signals: 1-bit (each) Write clock and enable input signals
        .WRCLK      (wr_clk),           // 1-bit write clock input
        .WREN       (writeFifo),        // 1-bit write enable input
        
        // Write Data: 64-bit (each) Write input data
        .DI         (dataIn[63:0]),     // 64-bit data input
        .DIP        (dataIn[71:64]),    // 8-bit parity input
        
        // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
        .RDCLK      (rd_clk),           // 1-bit read clock input
        .RDEN       (readFifo),         // 1-bit read enable input
        .REGCE      (1'b1),             // 1-bit clock enable input
        .RST        (rd_rst_q),         // 1-bit reset input
        
        // Read Data: 64-bit (each) Read output data
        .DO         (dataOut[63:0]),    // 64-bit data output
        .DOP        (dataOut[71:64]),   // 8-bit parity data output
        
        // Status: 1-bit (each) Flags and other FIFO status outputs
        .EMPTY      (bramFifoEmpty[0]), // 1-bit empty output flag
        .ALMOSTEMPTY(bramFifoAEmpty[0]),// 1-bit almost empty flag
        .FULL       (bramFifoFull[0]),  // 1-bit full output flag
        .ALMOSTFULL (bramFifoAFull[0])  // 1-bit almost full output flag
    );

    generate
    genvar j;
    for(j=WIDTH; j<=WIDTH; j=j+1) begin: create_fifos
    
    // this fifo is only used if WIDTH > 72
    if (j > 72) begin
        (* RLOC = "X0Y1" *)
        FIFO36E1 #(
            .ALMOST_FULL_OFFSET         (OFFSET),       // asserted when fifo has this many empty spaces left
            .ALMOST_EMPTY_OFFSET        (OFFSET),       // asserted when fifo has
                                                        //  less than this many full spaces
            .DATA_WIDTH                 (72),           // Sets data width to 4, 9, 18, 36, or 72
            .DO_REG                     (1),            // Enable output register (0 or 1) Must be 
                                                        //  1 if EN_SYN = "FALSE"
            .EN_ECC_READ                ("FALSE"),      // Enable ECC decoder, "TRUE" or "FALSE"
            .EN_ECC_WRITE               ("FALSE"),      // Enable ECC encoder, "TRUE" or "FALSE"
            .EN_SYN                     ("FALSE"),      // Specifies FIFO as Asynchronous ("FALSE") 
                                                        //  or Synchronous ("TRUE")
            .FIFO_MODE                  ("FIFO36_72"),  // Sets mode to FIFO36 or FIFO36_72
            .FIRST_WORD_FALL_THROUGH    ("TRUE")        // Sets the FIFO FWFT to "TRUE" or "FALSE"
        )
        fifo1
        (
            // Write Control Signals: 1-bit (each) Write clock and enable input signals
            .WRCLK      (wr_clk),           // 1-bit write clock input
            .WREN       (writeFifo),        // 1-bit write enable input
        
            // Write Data: 64-bit (each) Write input data
            .DI         (dataIn[135:72]),   // 64-bit data input
            .DIP        (dataIn[143:136]),  // 8-bit parity input
        
            // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
            .RDCLK      (rd_clk),           // 1-bit read clock input
            .RDEN       (readFifo),         // 1-bit read enable input
            .REGCE      (1'b1),             // 1-bit clock enable input
            .RST        (rd_rst_q),         // 1-bit reset input
        
            // Read Data: 64-bit (each) Read output data
            .DO         (dataOut[135:72]),  // 64-bit data output
            .DOP        (dataOut[143:136]), // 8-bit parity data output
        
            // Status: 1-bit (each) Flags and other FIFO status outputs
            .EMPTY      (bramFifoEmpty[1]), // 1-bit empty output flag
            .ALMOSTEMPTY(bramFifoAEmpty[1]),// 1-bit almost empty flag
            .FULL       (bramFifoFull[1]),  // 1-bit full output flag
            .ALMOSTFULL (bramFifoAFull[1])  // 1-bit almost full output flag
        );
    end else begin
        assign bramFifoEmpty    [1] = 0;
        assign bramFifoAEmpty   [1] = 0;
        assign bramFifoFull     [1] = 0;
        assign bramFifoAFull    [1] = 0;
    end

    // this fifo is only used if WIDTH > 144
    if (j > 144) begin
        (* RLOC = "X0Y2" *)
        FIFO36E1 #(
            .ALMOST_FULL_OFFSET         (OFFSET),       // asserted when fifo has this many empty spaces left
            .ALMOST_EMPTY_OFFSET        (OFFSET),       // asserted when fifo has
                                                        //  less than this many full spaces
            .DATA_WIDTH                 (72),           // Sets data width to 4, 9, 18, 36, or 72
            .DO_REG                     (1),            // Enable output register (0 or 1) Must be 
                                                        //  1 if EN_SYN = "FALSE"
            .EN_ECC_READ                ("FALSE"),      // Enable ECC decoder, "TRUE" or "FALSE"
            .EN_ECC_WRITE               ("FALSE"),      // Enable ECC encoder, "TRUE" or "FALSE"
            .EN_SYN                     ("FALSE"),      // Specifies FIFO as Asynchronous ("FALSE") 
                                                        //  or Synchronous ("TRUE")
            .FIFO_MODE                  ("FIFO36_72"),  // Sets mode to FIFO36 or FIFO36_72
            .FIRST_WORD_FALL_THROUGH    ("TRUE")        // Sets the FIFO FWFT to "TRUE" or "FALSE"
        )
        fifo2
        (
            // Write Control Signals: 1-bit (each) Write clock and enable input signals
            .WRCLK      (wr_clk),           // 1-bit write clock input
            .WREN       (writeFifo),        // 1-bit write enable input
        
            // Write Data: 64-bit (each) Write input data
            .DI         (dataIn[207:144]),  // 64-bit data input
            .DIP        (dataIn[215:208]),  // 8-bit parity input
        
            // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
            .RDCLK      (rd_clk),           // 1-bit read clock input
            .RDEN       (readFifo),         // 1-bit read enable input
            .REGCE      (1'b1),             // 1-bit clock enable input
            .RST        (rd_rst_q),         // 1-bit reset input
        
            // Read Data: 64-bit (each) Read output data
            .DO         (dataOut[207:144]), // 64-bit data output
            .DOP        (dataOut[215:208]), // 8-bit parity data output
        
            // Status: 1-bit (each) Flags and other FIFO status outputs
            .EMPTY      (bramFifoEmpty[2]), // 1-bit empty output flag
            .ALMOSTEMPTY(bramFifoAEmpty[2]),// 1-bit almost empty flag
            .FULL       (bramFifoFull[2]),  // 1-bit full output flag
            .ALMOSTFULL (bramFifoAFull[2])  // 1-bit almost full output flag
        );
    end else begin
        assign bramFifoEmpty    [2] = 0;
        assign bramFifoAEmpty   [2] = 0;
        assign bramFifoFull     [2] = 0;
        assign bramFifoAFull    [2] = 0;
    end

    // this fifo is only used if WIDTH > 216
    if (j > 216) begin
        (* RLOC = "X0Y3" *)
        FIFO36E1 #(
            .ALMOST_FULL_OFFSET         (OFFSET),       // asserted when fifo has this many empty spaces left
            .ALMOST_EMPTY_OFFSET        (OFFSET),       // asserted when fifo has
                                                        //  less than this many full spaces
            .DATA_WIDTH                 (72),           // Sets data width to 4, 9, 18, 36, or 72
            .DO_REG                     (1),            // Enable output register (0 or 1) Must be 
                                                        //  1 if EN_SYN = "FALSE"
            .EN_ECC_READ                ("FALSE"),      // Enable ECC decoder, "TRUE" or "FALSE"
            .EN_ECC_WRITE               ("FALSE"),      // Enable ECC encoder, "TRUE" or "FALSE"
            .EN_SYN                     ("FALSE"),      // Specifies FIFO as Asynchronous ("FALSE") 
                                                        //  or Synchronous ("TRUE")
            .FIFO_MODE                  ("FIFO36_72"),  // Sets mode to FIFO36 or FIFO36_72
            .FIRST_WORD_FALL_THROUGH    ("TRUE")        // Sets the FIFO FWFT to "TRUE" or "FALSE"
        )
        fifo3
        (
            // Write Control Signals: 1-bit (each) Write clock and enable input signals
            .WRCLK      (wr_clk),           // 1-bit write clock input
            .WREN       (writeFifo),        // 1-bit write enable input
        
            // Write Data: 64-bit (each) Write input data
            .DI         (dataIn[279:216]),  // 64-bit data input
            .DIP        (dataIn[287:280]),  // 8-bit parity input
        
            // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
            .RDCLK      (rd_clk),           // 1-bit read clock input
            .RDEN       (readFifo),         // 1-bit read enable input
            .REGCE      (1'b1),             // 1-bit clock enable input
            .RST        (rd_rst_q),         // 1-bit reset input
        
            // Read Data: 64-bit (each) Read output data
            .DO         (dataOut[279:216]), // 64-bit data output
            .DOP        (dataOut[287:280]), // 8-bit parity data output
        
            // Status: 1-bit (each) Flags and other FIFO status outputs
            .EMPTY      (bramFifoEmpty[3]), // 1-bit empty output flag
            .ALMOSTEMPTY(bramFifoAEmpty[3]),// 1-bit almost empty flag
            .FULL       (bramFifoFull[3]),  // 1-bit full output flag
            .ALMOSTFULL (bramFifoAFull[3])  // 1-bit almost full output flag
        );
    end else begin
        assign bramFifoEmpty    [3] = 0;
        assign bramFifoAEmpty   [3] = 0;
        assign bramFifoFull     [3] = 0;
        assign bramFifoAFull    [3] = 0;
    end
    
    // this fifo is only used if WIDTH > 216
    if (j > 288) begin
        (* RLOC = "X0Y4" *)
        FIFO36E1 #(
            .ALMOST_FULL_OFFSET         (OFFSET),       // asserted when fifo has this many empty spaces left
            .ALMOST_EMPTY_OFFSET        (OFFSET),       // asserted when fifo has
                                                        //  less than this many full spaces
            .DATA_WIDTH                 (72),           // Sets data width to 4, 9, 18, 36, or 72
            .DO_REG                     (1),            // Enable output register (0 or 1) Must be 
                                                        //  1 if EN_SYN = "FALSE"
            .EN_ECC_READ                ("FALSE"),      // Enable ECC decoder, "TRUE" or "FALSE"
            .EN_ECC_WRITE               ("FALSE"),      // Enable ECC encoder, "TRUE" or "FALSE"
            .EN_SYN                     ("FALSE"),      // Specifies FIFO as Asynchronous ("FALSE") 
                                                        //  or Synchronous ("TRUE")
            .FIFO_MODE                  ("FIFO36_72"),  // Sets mode to FIFO36 or FIFO36_72
            .FIRST_WORD_FALL_THROUGH    ("TRUE")        // Sets the FIFO FWFT to "TRUE" or "FALSE"
        )
        fifo4
        (
            // Write Control Signals: 1-bit (each) Write clock and enable input signals
            .WRCLK      (wr_clk),           // 1-bit write clock input
            .WREN       (writeFifo),        // 1-bit write enable input
        
            // Write Data: 64-bit (each) Write input data
            .DI         (dataIn[351:288]),  // 64-bit data input
            .DIP        (dataIn[359:352]),  // 8-bit parity input
        
            // Read Control Signals: 1-bit (each) Read clock, enable and reset input signals
            .RDCLK      (rd_clk),           // 1-bit read clock input
            .RDEN       (readFifo),         // 1-bit read enable input
            .REGCE      (1'b1),             // 1-bit clock enable input
            .RST        (rd_rst_q),         // 1-bit reset input
        
            // Read Data: 64-bit (each) Read output data
            .DO         (dataOut[351:288]), // 64-bit data output
            .DOP        (dataOut[359:352]), // 8-bit parity data output
        
            // Status: 1-bit (each) Flags and other FIFO status outputs
            .EMPTY      (bramFifoEmpty[4]), // 1-bit empty output flag
            .ALMOSTEMPTY(bramFifoAEmpty[4]),// 1-bit almost empty flag
            .FULL       (bramFifoFull[4]),  // 1-bit full output flag
            .ALMOSTFULL (bramFifoAFull[4])  // 1-bit almost full output flag
        );
    end else begin
        assign bramFifoEmpty    [4] = 0;
        assign bramFifoAEmpty   [4] = 0;
        assign bramFifoFull     [4] = 0;
        assign bramFifoAFull    [4] = 0;
    end
    
    end // for(j=WIDTH; j<=WIDTH; j=j+1) begin: create_fifos
    endgenerate
   
    // data should come straight from the FIFO
    always @ (*) begin
        dout        = dataOut;
        readFifo    = rd_en & ~empty;
    end

    // empty signal looks at the empty from the FIFO and the almost empty
    // if almost empty is not asserted, then we never assert empty
    // if almost empty is asserted, we assert empty at least every other cycle
    always @ (posedge rd_clk) begin
        if (rd_rst_q) begin
            empty   <= 1;
        end else if (!fifoAlmostEmpty) begin
            empty   <= 0;
        end else if (rd_en && !empty) begin
            empty   <= 1;
        end else begin
            empty   <= fifoEmpty;
        end
    end

endmodule
