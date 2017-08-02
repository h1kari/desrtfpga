// CounterClkGen.v
// Copyright 2015, Pico Computing, Inc.

// A clock generator. It generates a new clock by using a counter to divide the
// input reference clock. Suitable for the scenario where a low quailty clock
// is sufficent for the task. Since it is counter based, the output frequency
// has to be at most half of the reference clock frequency. The possible
// output frequencies are the ones making C0 in the following equation a
// non-negative integer:
// C0 = REF_CLK_FREQ / (OUT_CLK_FREQ * 2) - 1


`include "PicoDefines.v"

module CounterClkGen # (
    parameter REF_CLK_FREQ = 250, // Reference clock frequency in MHz
    parameter OUT_CLK_FREQ = 10   // Output clock frequency in MHz
) (
    input  wire         refclk,
    input  wire         rst,
    output wire         clk_o
);
    
    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction

    // calculate the maximum counting value based on the parameters
    localparam C0 = (REF_CLK_FREQ / (OUT_CLK_FREQ * 2) - 1);
    // width of the counter
    localparam W = clogb2(C0)+1;
    reg clk_reg = 0;
    reg [W-1:0] counter = 0;

    always @ (posedge refclk) begin
        counter <= counter + 1;
        // toggle the clock if the counter hit the maximum value.
        if (counter == C0) begin
            counter <= 0;
            clk_reg <= ~clk_reg;
        end
    end

    // primitive for putting generated clock on clock network.
`ifdef ALTERA_FPGA
    GLOBAL inst (.in(clk_reg), .out(clk_o));
`else
    BUFG inst (.O(clk_o), .I(clk_reg));
`endif

endmodule

