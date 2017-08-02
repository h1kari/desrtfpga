`timescale 1ns / 1ps


`define DES_PIPE_STAGES 19
module descrack #(
    parameter PT = 64'h1122334455667788
) (
    input  clk,
    input  clken,
    input  rst,
    
    // fwft fifo input
    input  [63:0] in_ct,
    input  [63:0] in_r,
    input  [19:0] in_t,
    input  [11:0] in_id,
    output reg in_rd = 0,
    input  in_empty,
    
    // fwft fifo output
    output reg [55:0] out_k = 0,
    output reg [19:0] out_t = 0,
    output reg [11:0] out_id = 0,
    output reg out_wr = 0
);

wire [63:0] out;
reg  [55:0] curKeyIn = 0;
des desblock(.desOut(out), .desIn(PT), .key(curKeyIn), .decrypt(1'b0), .clk(clk), .clken(clken));

wire [63:0] redux_in;
wire [63:0] redux_out;
redux_lfsr redux_lfsr (
    .redux_in(redux_in),
    .redux_out(redux_out)
);

reg [4:0] pipe, pipe_1, pipe_2;
reg [63:0] r  [18:0];
reg [19:0] t  [18:0];
reg [19:0] s  [18:0];
reg [11:0] id [18:0];
reg [18:0] occupied;
reg [63:0] redux, redux_0;
reg [19:0] t_i, t_i_0;
reg [19:0] s_i, s_i_0;
reg [11:0] id_i, id_i_0;
always @(posedge clk) begin
    out_k  <= 0;
    out_wr <= 0;
    in_rd  <= 0;

    if(rst) begin
        pipe_1   <= 0;
        pipe_2   <= 0;
        occupied <= 0;
        redux    <= 0;
        t_i      <= 0;
        s_i      <= 0;
    end else if(clken) begin
        // generate pipe + 1, use pipe for current cycle
        if(pipe_2 == 18) pipe_2 <= 0;
        else             pipe_2 <= pipe_2 + 1;
        
        // grab a job for pipeline if it's unoccupied
        if(!occupied[pipe] && !in_empty && !in_rd) begin
            curKeyIn <= in_ct ^ in_r;
            r[pipe]  <= in_r;
            t[pipe]  <= in_t;
            s[pipe]  <= in_t;
            id[pipe] <= in_id;
            occupied[pipe] <= 1;
            in_rd          <= 1;
        // otherwise if we're occupied, process links in chain until end
        end else if(occupied[pipe]) begin
            if(t_i != 0) begin
                curKeyIn <= out ^ redux_out;
                r[pipe]  <= redux_out;
                t[pipe]  <= t_i - 1;
            // at end of chain, return last key
            end else begin
                out_k    <= out[55:0] ^ redux_out[55:0];
                out_t    <= s_i;
                out_id   <= id_i;
                out_wr   <= 1;
                occupied[pipe] <= 0;
            end
        end
 
        // lookup so value is available on pipe clock cycle
        redux_0 <= r[pipe_2];
        redux   <= redux_0;
        t_i_0   <= t[pipe_2];
        t_i     <= t_i_0;
        s_i_0   <= s[pipe_2];
        s_i     <= s_i_0;
        id_i_0  <= id[pipe_2];
        id_i    <= id_i_0;
        
        pipe_1 <= pipe_2;
        pipe   <= pipe_1;
    end
    
    //if(pipe == 'h0c) $display("%x", curKeyIn);
end

assign redux_in = redux;

endmodule
