/*
* File Name     : HMCReorder.v
*
* Description   : Reorders response data coming back from the HMC controller.
*                 Assumes:
*                 1) Responses can come back in any order
*                 2) Responses can be between 1 and 8 data beats in length
*                 3) Responses should go out (on our output) in the order in
*                 which they were issued
*                 4) Latency is not a big concern
*
*                 We piggyback off the Reorder.v module here, because we know
*                 that to be tried and true.
*                 
*                 TODO: how to reset this module? What if we get into a bad
*                 state, due to dinv being asserted or something?
*                 
* Copyright     : 2015, Micron Inc.
*/

`include "PicoDefines.v"

module HMCReorder #(
    parameter   ID_WIDTH            = 6,
    parameter   DATA_WIDTH          = 128
)
(
    input                           clk,
    input                           rst,

    input       [3:0]               cmd,
    input                           cmd_valid,
    input                           cmd_ready,
    input       [ID_WIDTH-1:0]      tag,
    input       [3:0]               size,

    input       [DATA_WIDTH-1:0]    rd_data_in,
    input       [ID_WIDTH-1:0]      rd_data_tag_in,
    input                           rd_data_valid_in,
    input       [6:0]               errstat_in,
    input                           dinv_in,
    
    output      [DATA_WIDTH-1:0]    rd_data_out,
    output      [ID_WIDTH-1:0]      rd_data_tag_out,
    output                          rd_data_valid_out,
    output      [6:0]               errstat_out,
    output                          dinv_out
);

    ///////////////
    // FUNCTIONS //
    ///////////////

    // use a function in the HMC source to find our expected response size
`ifdef ENABLE_HMC
    `include "hmc_func.h.v"
`else
    function    [3:0]               GetResponseSize;
        input   [3:0]               cmd;
        input   [3:0]               size;
        begin
            GetResponseSize         = 0;
        end
    endfunction
`endif

    ////////////////////////
    // LISTEN TO REQUESTS //
    ////////////////////////

    // we listen to the outgoing commands and do the following:
    
    // 1) compute and store the anticipated response size (range = 1:8)
    reg         [3:0]               resp_size           = 0;
    reg         [ID_WIDTH-1:0]      tag_1               = 0;
    reg                             cmd_valid_1         = 0;
    reg         [3:0]               size_mem            [0:(1<<ID_WIDTH)-1];
    
    // compute the expected response size
    always @ (posedge clk) begin
        if (rst) begin
           cmd_valid_1              <= 0;
       end else begin
           cmd_valid_1              <= cmd_valid & cmd_ready;
       end
       resp_size                    <= GetResponseSize(cmd, size);
       tag_1                        <= tag;
    end

    // stores the response size
    always @ (posedge clk) begin
        if (cmd_valid_1) begin
            size_mem    [tag_1]     <= resp_size;
        end
    end

    // 2) compute the anticipated entry of the memory in the Reorder module
    // where the last data beat for the next response will go. this is
    // basically just a write pointer that we need to remember from one
    // request to the next.  Note that we cannot simply compute this from the
    // size of the memory, an ID, and a tag.  We need the previous value for
    // tag_seq_en_in that we passed to the Reorder module.
    reg         [9:0]               tag_seq_end         = {10{1'b1}};
    reg                             tag_seq_end_valid   = 0;
    reg         [ID_WIDTH-1:0]      tag_2               = 0;

    // Note: we must reset tag_seq_end to -1, because range(size)=1:8. if
    // size=1 for the first request, we must set our first tag_seq_end=0
    always @ (posedge clk) begin
        if (rst) begin
            tag_seq_end             <= {10{1'b1}};
            tag_seq_end_valid       <= 0;
        end else if (cmd_valid_1) begin
            tag_seq_end             <= tag_seq_end + resp_size;
            tag_seq_end_valid       <= (resp_size != 0);
        end else begin
            tag_seq_end_valid       <= 0;
        end
        tag_2                       <= tag_1;
    end

    ///////////////////////////////////
    // LOOK UP THE SIZE FOR THIS TAG //
    ///////////////////////////////////

    // we have a tag coming on on rd_data_tag_in
    // we should use that to lookup the size in 'size_mem'
    reg                             tag_valid_in_1      = 0;
    reg         [ID_WIDTH-1:0]      rd_data_tag_in_1    = 0;
    reg         [7:0]               rd_data_size_1      = 0;
    reg         [ID_WIDTH-1:0]      prev_tag            = {ID_WIDTH{1'b1}};

    // Note: we only want to assert tag_valid_in_1 for the first data beat of
    // a new tag
    always @ (posedge clk) begin
        if (rst) begin
            tag_valid_in_1          <= 0;
            prev_tag                <= {ID_WIDTH{1'b1}};
        end else if (rd_data_valid_in) begin
            tag_valid_in_1          <= rd_data_tag_in != prev_tag;
            prev_tag                <= rd_data_tag_in;
        end else begin
            tag_valid_in_1          <= 0;
        end
        rd_data_tag_in_1            <= rd_data_tag_in;
        rd_data_size_1              <= {4'h0, size_mem [rd_data_tag_in]};
    end

    /////////////////////
    // DELAY READ DATA //
    /////////////////////

    // according to the reorder module, the rd data needs to be delayed by
    // exactly 1 cycle w.r.t. the tag
    reg                             rd_data_valid_in_1  = 0;
    reg         [DATA_WIDTH-1:0]    rd_data_in_1        = 0;
    reg         [6:0]               errstat_in_1        = 0;
    reg                             dinv_in_1           = 0;
    
    reg                             rd_data_valid_in_2  = 0;
    reg         [DATA_WIDTH-1:0]    rd_data_in_2        = 0;
    reg         [6:0]               errstat_in_2        = 0;
    reg                             dinv_in_2           = 0;

    always @ (posedge clk) begin
        rd_data_valid_in_1          <= rd_data_valid_in;
        rd_data_in_1                <= rd_data_in;
        errstat_in_1                <= errstat_in;
        dinv_in_1                   <= dinv_in;
        
        rd_data_valid_in_2          <= rd_data_valid_in_1;
        rd_data_in_2                <= rd_data_in_1;
        errstat_in_2                <= errstat_in_1;
        dinv_in_2                   <= dinv_in_1;
    end

    /////////////
    // REORDER //
    /////////////

    // this is the ever so slightly modified version of the reorder module
    Reorder #(
        .W                          (1+7+DATA_WIDTH)
    ) reorder (
        .clk                        (clk),
        .rst                        (rst),

        .tag_in                     ({{(8-ID_WIDTH){1'b0}}, rd_data_tag_in_1}),
        .tag_en                     (tag_valid_in_1),
        .rem_count                  (rd_data_size_1-1),

        .data_in                    ({
                                        dinv_in_2,
                                        errstat_in_2,
                                        rd_data_in_2
                                    }),
        .data_in_en                 (rd_data_valid_in_2),

        .tag_seq_end_in_en          (tag_seq_end_valid),
        .tag_seq_end_in             ({22'b0, tag_seq_end}),
        .tag_seq_end_in_tag         ({{(8-ID_WIDTH){1'b0}}, tag_2}),

        .data_out_en                (rd_data_valid_out),
        .data_out                   ({
                                        dinv_out,
                                        errstat_out,
                                        rd_data_out
                                    }),
        .tag_out                    (rd_data_tag_out)
    );
    
    ///////////
    // DEBUG //
    ///////////

    /*
    initial begin
        $dumpvars(1, clk, rst);
        $dumpvars(1, cmd, cmd_valid, cmd_ready, tag, size);
        $dumpvars(1, rd_data_in, rd_data_tag_in, rd_data_valid_in, errstat_in, dinv_in);
        $dumpvars(1, rd_data_out, rd_data_tag_out, rd_data_valid_out, errstat_out, dinv_out);
        $dumpvars(1, resp_size, tag_1, cmd_valid_1); 
        $dumpvars(1, tag_seq_end, tag_seq_end_valid, tag_2); 
        $dumpvars(1, tag_valid_in_1, rd_data_tag_in_1, rd_data_size_1, prev_tag);
        $dumpvars(1, rd_data_in_1, rd_data_valid_in_1, errstat_in_1, dinv_in_1);
        $dumpvars(1, rd_data_in_2, rd_data_valid_in_2, errstat_in_2, dinv_in_2);
    end
    */
endmodule

