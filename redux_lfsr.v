`timescale 1ns / 1ps

// compute one stage of the 64-bit maximal LFSR
module lfsr64 (
    input  [63:0] state_in,
    output [63:0] state_out
);

assign state_out[63:1] = state_in[62:0];
assign state_out[0]    = state_in[63] ^ state_in[62] ^ state_in[60] ^ state_in[59];

endmodule


// when load is high, store seed into state
// when en is high, clock LFSR forward 64 stages and output new state
module redux_lfsr(
    input  [63:0] redux_in,
    output [63:0] redux_out
);

// extend out LFSR to compute 64 stages in one clock cycle
wire [63:0] state_ [64:0];
assign state_[0] = redux_in;

genvar i;
generate for(i = 0; i < 64; i = i + 1) begin : lfsr64
    lfsr64 lfsr64 (
        .state_in(state_[i]),
        .state_out(state_[i+1])
    );
end endgenerate
assign redux_out = state_[64];

endmodule
