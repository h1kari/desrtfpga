/*
* File Name     : HMCTagManager.v
*
* Description   : This serves as a gatekeeper for issuing requests to the HMC
*                 controller.  We do not issue a new request if
*                 'rd_data_ready' is deasserted.  Also, we do not issue
*                 a request if we do not have a free tag for that request.
*
*                 We make the assumption that we only have to issue a command
*                 at most every other cycle.  This lets us easily register the 
*                 outputs in this module.
*
* Copyright     : 2015, Micron Inc.
*/

`include "PicoDefines.v"

module HMCTagManager #(
    parameter   ID_WIDTH            = 6,
    parameter   DATA_WIDTH          = 128
)
(
    input                           clk,
    input                           rst,

    input       [3:0]               cmd_in,
    input                           cmd_valid_in,
    output                          cmd_ready_in,
    input       [33:0]              addr_in,
    input       [ID_WIDTH-1:0]      tag_in,
    input       [3:0]               size_in,
    
    output  reg [3:0]               cmd_out,
    output  reg                     cmd_valid_out   = 0,
    input                           cmd_ready_out,
    output  reg [33:0]              addr_out,
    output  reg [ID_WIDTH-1:0]      tag_out,
    output  reg [3:0]               size_out,

    input       [5:0]               rd_data_tag,
    input                           rd_data_valid,
    input                           rd_data_ready
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

    //////////////////////
    // INTERNAL SIGNALS //
    //////////////////////
    
    // these are the most recent tags that we have seen on our output cmd bus
    // and our returned 'rd_data_tag' bus (respectively)
    reg         [ID_WIDTH-1:0]      last_req_tag        = 0;
    reg         [ID_WIDTH-1:0]      last_resp_tag       = 0;
    
    // when computing if we are out of tags, we need to make sure we are only
    // doing 6-bit comparisons. we use these intermediates to ensure that
    wire        [ID_WIDTH-1:0]      last_req_tag_p1     = last_req_tag + 1;
    wire        [ID_WIDTH-1:0]      last_req_tag_p2     = last_req_tag + 2;
    wire        [ID_WIDTH-1:0]      last_req_tag_p3     = last_req_tag + 3;

    // this is the next tag that we want to issue w/ our next command
    // Note: we issue tags in sequential order, unless we have commands that
    // do not generate a response.  in that case, we do not increment the tag
    reg         [ID_WIDTH-1:0]      next_tag            = 0;

    // this flag tries to signal if we are running low on tags 
    reg                             tags_almostempty    = 0;

    ///////////////////////////////////
    // DETERMINE THE NEXT TAG TO USE //
    ///////////////////////////////////

    // just use a counter to track this tag
    // since we really only use the tag to pair responses with commands, we
    // don't need to increment the tag for commands that do not produce
    // responses (i.e. GetResponseSize=0)
    always @ (posedge clk) begin
        if (rst) begin
            next_tag                <= 0;
        end else if (cmd_valid_in && cmd_ready_in) begin
            if (GetResponseSize(cmd_in, size_in) != 0) begin
                next_tag            <= next_tag + 1;
            end
        end
    end

    ////////////////
    // TRACK TAGS //
    ////////////////
    
    // remember the most recently issued and returned tags
    always @ (posedge clk) begin
        if (rst) begin
            last_req_tag            <= 0;
        end else if (cmd_valid_in && cmd_ready_in) begin
            last_req_tag            <= next_tag;
        end
        if (rst) begin
            last_resp_tag           <= 0;
        end else if (rd_data_valid) begin
            last_resp_tag           <= rd_data_tag;
        end
    end
    
    // compute if we are out of tags, or at least almost out of tags
    // remember, every time we isssued a request that generates a response, we
    // incremented the tag.  therefore, we can expect exactly 1 response for
    // each tag.  we therefore expect our last_req_tag to lead the
    // last_resp_tag register. if last_req_tag starts catching up to
    // last_rsp_tag, then we are starting to run out of tags and we should
    // really slow down
    always @ (posedge clk) begin    
        tags_almostempty            <= (last_req_tag_p3 == last_resp_tag) ||
                                       (last_req_tag_p2 == last_resp_tag) ||
                                       (last_req_tag_p1 == last_resp_tag);
    end

    ////////////////////////
    // APPLY BACKPRESSURE //
    ////////////////////////

    // if we don't have any tags free, or if the AXI response channel needs us
    // to slow down, then don't issue any new commands
    assign  cmd_ready_in            = ~cmd_valid_out && ~tags_almostempty && rd_data_ready;

    //////////////////////////////
    // REGISTER OUTPUT COMMANDS //
    //////////////////////////////
    
    // this uses a half-bandwidth approach to registering the output data
    // we do this to ease timing in this design
    // we also know that we shouldn't need to issue commands every single
    // cycle in order to get good performance in this system
    always @ (posedge clk) begin
        if (rst) begin
            cmd_valid_out           <= 0;
            cmd_out                 <= 'hX;
            addr_out                <= 'hX;
            tag_out                 <= 'hX;
            size_out                <= 'hX;
        end else if (cmd_ready_in) begin
            cmd_valid_out           <= cmd_valid_in;
            cmd_out                 <= cmd_in;
            addr_out                <= addr_in;
            tag_out                 <= next_tag;
            size_out                <= size_in;
        end else if (cmd_ready_out) begin
            cmd_valid_out           <= 0;
            cmd_out                 <= 'hX;
            addr_out                <= 'hX;
            tag_out                 <= 'hX;
            size_out                <= 'hX;
        end
    end

    ///////////
    // DEBUG //
    ///////////

    /*
    initial begin
        $dumpvars(1, clk, rst);
        $dumpvars(1, cmd_in, cmd_valid_in, cmd_ready_in, addr_in, tag_in, size_in);
        $dumpvars(1, cmd_out, cmd_valid_out, cmd_ready_out, addr_out, tag_out, size_out);
        $dumpvars(1, rd_data_tag, rd_data_valid, rd_data_ready);
        $dumpvars(1, last_req_tag, last_resp_tag);
        $dumpvars(1, last_req_tag_p1, last_req_tag_p2, last_req_tag_p3);
        $dumpvars(1, next_tag, tags_almostempty);
    end
    */
endmodule

