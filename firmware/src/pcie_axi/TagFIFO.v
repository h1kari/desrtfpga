/* TagFIFO - maintain a pool of unique tags for protocols such as PCIe Copyright
 * 2014 Pico Computing, Inc.
 *
 * <almost_empty> is an early warning that the number of tags is "low." If it's
 * low, you may assume there are at least 8 tags available.  There may be more.
 *
 * Note that there's no tag_in_rdy signal, since there's a fixed number of tags
 * in existence, and thus we know we won't overflow.  (As long as only tags that
 * were handed out are handed back. If something external is creating more tags,
 * you've got bigger problems.)
 *
 */


`timescale 1ns/1ns

`include "PicoDefines.v"

module TagFIFO # (
  parameter TAG_WIDTH = 8
) 
(
  input                      clk ,
  input                      rst ,
  // fifo input
  input  [TAG_WIDTH-1:0]     tag_in ,               // last_cpld_tag
  input                      tag_in_valid ,         // last_cpld_tag_valid 
  // fifo output
  output [TAG_WIDTH-1:0]     tag_out ,
  output                     tag_out_valid ,
  // flow control
  input                      tag_out_rdy ,          // read signal
  output                     tag_almost_empty,

  output reg                 tag_init_done          // register output

);

  localparam                   verbose = 0;
  localparam                   TAG_INIT_ST = 'b001 ;
  localparam                   TAG_DONE_ST = 'b010 ;
  localparam                   TAG_IDLE_ST = 'b100 ;
  `ifdef ALTERA_FPGA
  localparam                   MAX_TAG    =  8'h3f;
  `elsif XILINX_ULTRASCALE
  localparam                   MAX_TAG    =  8'h3f;
  `else
  localparam                   MAX_TAG    = {TAG_WIDTH{1'b1}} ;
  `endif
  reg        [2:0]             istream_state        = TAG_IDLE_ST ;
  reg        [TAG_WIDTH-1:0]   istream_table_inx = 8'h0 ;
  reg                          tag_init_en    ;
  reg        [TAG_WIDTH-1:0]   tag_init_din   ;
  reg                          tag_fifo_wr_en ;
  reg        [TAG_WIDTH-1:0]   tag_fifo_din   ;
  wire       [31:0]            tag_fifo_dout  ;
  wire                         tag_fifo_empty ;
//  reg        [3:0]             tag_rst_ct  = 'h0 ;
  reg                          tag_rst_done = 'b0 ;
 
  // ===========================================================================
  // we have to use the tags rather than simply count the requests and cplds,
  // since we don't know how many cplds the completer will use to fill
  // a request.  beware the latency in this signal. it takes at least a few
  // cycles for us to know the tx engine sent a new request, and it can make
  // requests back to back, so leave enough slack in the read_log to absorb the
  // few cycles it takes for us to stop to tx engine.  tx_rd_req_ok    <=
  // cpld_outstanding <= max_cpld_outstanding; this is the new, fifo-based way
  // of doing this
  // ===========================================================================


  // ===========================================================================
  // on startup, we actually go into the ISTREAM_STATE_CLEAR state before seeing
  // reset.  thus it's critical to clear the rd_tag_fifo enable when we go into
  // reset so that we don't write the first tag (0) twice.
  // make sure we don't write to the fifo when we temporarily jump into the
  // "clear" state prior to getting the reset.
  // also, when we finally hit the ISTREAM_STATE_CLEAR state "for real,"
  // istream_table_inx will start at 2, rather than 0.  that means we'll miss
  // adding the tags "0" and "1", but that's probably better than stressing the
  // istream_table_inx with a reset, which is the only straightforward
  // alternative.  this line makes us able to handle repeated resets. for
  // example, if we come up at power-on, and then the bios POST does a reset.
  // (this is why we used to have problems with putting 5.x firmware on the
  // cards, and they required a reload before they were sane.)
  // ===========================================================================


      
  always @(posedge clk) begin
    if (rst) begin
      istream_table_inx     <= 8'h0 ;
      istream_state         <= TAG_IDLE_ST ;

      tag_init_en           <= 0 ;
      tag_init_done         <= 0 ;
      tag_init_din          <= 8'h0 ;

      tag_fifo_wr_en        <= 1'h0 ;              // fifo
      tag_fifo_din          <= 8'h0 ;              // fifo
//      tag_rst_ct            <= 4'h0 ;
      tag_rst_done          <= 1'h1 ;
    end else begin
      istream_table_inx     <= istream_table_inx ; // default
      istream_state         <= istream_state ;     // default

      tag_init_en           <= 1'h0 ;              // default no write
      tag_init_done         <= 0 ;                 // default
      tag_init_din          <= 8'h0 ;              // default 0x00

      tag_fifo_wr_en        <= 1'h0 ;
      tag_fifo_din          <= 8'h0 ;
//      tag_rst_ct            <= 4'h0 ;
      case (istream_state)
//
        TAG_IDLE_ST : begin
//          tag_rst_ct        <= tag_rst_ct + 1 ;
          if (tag_rst_done == 'b1) begin
            istream_state   <= TAG_INIT_ST ;
          end 
        end

        TAG_INIT_ST : begin
          istream_table_inx <= istream_table_inx + 1 ;
          // stuff the read tag fifo with all possible tags
          tag_init_din      <= istream_table_inx[TAG_WIDTH-1:0] ;
          tag_init_en       <= 1 ;
          if (istream_table_inx == MAX_TAG) begin
            tag_init_done   <= 1 ;                  // init done
            istream_state   <= TAG_DONE_ST ; // state xfer
          end
          tag_fifo_wr_en    <= tag_init_en;
          tag_fifo_din      <= tag_init_din;
        end

        TAG_DONE_ST : begin
          tag_init_done     <= 1 ;                  // done!
          tag_fifo_wr_en    <= tag_in_valid ;
          tag_fifo_din      <= tag_in ;
          
        end
      endcase
    end
  end

  assign   tag_out = tag_fifo_dout[TAG_WIDTH-1:0] ;
  assign   tag_almost_empty = tag_fifo_almost_empty ;
  assign   tag_out_valid    = ~tag_fifo_empty & tag_out_rdy ;

`ifndef ALTERA_FPGA
    `ifdef XILINX_ULTRASCALE
        FIFO18E2 #(
            .PROG_FULL_THRESH           ('h180),
            .PROG_EMPTY_THRESH          ('h010),
            .WRITE_WIDTH                (36),
            .READ_WIDTH                 (36),
            .REGISTER_MODE              ("REGISTERED"),
            .CLOCK_DOMAINS              ("INDEPENDENT"),
            .FIRST_WORD_FALL_THROUGH    ("TRUE")
        ) rd_tag_fifo (
          .RDCLK                    (clk),
          .WRCLK                    (clk),
          .RST                      (rst),
          .REGCE                    (1'b1),
          .RSTREG                   (1'b0),
          .SLEEP                    (1'b0),
          .WREN                     (tag_fifo_wr_en),
          .DIN                      ({24'h0, tag_fifo_din}),
          .RDEN                     (tag_out_rdy),
          .DOUT                     (tag_fifo_dout),
          .PROGEMPTY                (tag_fifo_almost_empty),
          .EMPTY                    (tag_fifo_empty)
          //.FULL                     (tag_full),
          //.ALMOSTFULL(ALMOSTFULL)//1,-bitoutputalmostfull
          //.RDCOUNT(RDCOUNT),
          //.RDERR(RDERR),
          //.WRCOUNT(WRCOUNT),
          //.WRERR(WRERR),
          );
    `else
        FIFO18E1 #(
          .ALMOST_EMPTY_OFFSET      ('h010),
          .ALMOST_FULL_OFFSET       ('h080),
          .DATA_WIDTH               (9),
          .DO_REG                   (1),        //  Must be 1 if EN_SYN = "FALSE"
          //.EN_ECC_READ("FALSE"), // Enable ECC decoder, "TRUE" or "FALSE"
          //.EN_ECC_WRITE("FALSE"), // Enable ECC encoder, "TRUE" or "FALSE"
          .EN_SYN                   ("FALSE"),  // Async ("FALSE") or Sync ("TRUE")
          .FIFO_MODE                ("FIFO18"), // FIFO36 or FIFO36_72
          .FIRST_WORD_FALL_THROUGH  ("TRUE")    
        ) rd_tag_fifo (
          .RDCLK                    (clk),
          .WRCLK                    (clk),
          .RST                      (rst),
          .WREN                     (tag_fifo_wr_en),
          .DI                       ({24'h0, tag_fifo_din}),
          .RDEN                     (tag_out_rdy),
          .DO                       (tag_fifo_dout),
          .ALMOSTEMPTY              (tag_fifo_almost_empty),
          .EMPTY                    (tag_fifo_empty)
          //.FULL                     (tag_full),
          //.ALMOSTFULL(ALMOSTFULL)//1,-bitoutputalmostfull
          //.RDCOUNT(RDCOUNT),
          //.RDERR(RDERR),
          //.WRCOUNT(WRCOUNT),
          //.WRERR(WRERR),
          );
    `endif
      
`else
    FIFO #(
        .DATA_WIDTH     (TAG_WIDTH),
        .ALMOST_EMPTY   (16)
    ) rd_tag_fifo (
        .clk            (clk),
        .rst            (rst),
        .wr_en          (tag_fifo_wr_en),
        .din            (tag_fifo_din),
        .rd_en          (tag_out_rdy),
        .dout           (tag_fifo_dout),
        .almostempty    (tag_fifo_almost_empty),
        .empty          (tag_fifo_empty)
    );
`endif
endmodule // TagFIFO
