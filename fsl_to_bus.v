`timescale 1ns / 1ps

`include "PicoDefines.v"

module fsl_to_bus #(
    parameter CORE = 0
) (
    // input fsl control
    input fsl_clk,
    
    // fsl input
    input fsl_rst_i,
    input [31:0] fsl_data_i,
    input fsl_valid_i,
    
    // fsl output
    output reg fsl_rst_o = 0,
    output reg [31:0] fsl_data_o = 0,
    output reg fsl_valid_o = 0,
    
    // bus to receive vectors from fsl bus
    // descrack module provides bus clock (probably des_clk)
    // when !vec_empty, valid new vector is available on vec_dout and should toggle vec_rd when using value
    input  vec_clk,
    output [159:0] vec_dout,
    input  vec_rd,
    output vec_empty,
    
    // bus to xmit vector results to fsl bus
    // when !vec_full, provide vec_din and toggle vec_wr to send data out on bus
    // ideally this module will steal a vec from the ring and insert this result as data is passing through
    input  [159:0] vec_din,
    input  vec_wr,
    output vec_full,
    
    input des_rst,
    output reg full_latch = 0
);

// where data is stored before being inserted into ring
reg fsl_fifo_out_rd = 0;
wire [159:0] fsl_fifo_out_data;
wire fsl_fifo_out_full;
wire fsl_fifo_out_empty;
fsl_fifo_async fsl_fifo_out (
    .rd_clk(fsl_clk),
    .wr_clk(vec_clk),
    .rst(fsl_rst_i),
    .din(vec_din),
    .wr_en(vec_wr & ~fsl_rst_i),
    .rd_en(fsl_fifo_out_rd),
    .dout(fsl_fifo_out_data),
    .full(fsl_fifo_out_full),
    .empty(fsl_fifo_out_empty)
);
assign vec_full = fsl_fifo_out_full;

// make sure we always have one ring value stored in here
reg [159:0] fsl_ring_in_data;
reg fsl_ring_in_wr;
fsl_ring_async fsl_ring_in (
    .rd_clk(vec_clk),
    .wr_clk(fsl_clk),
    .rst(fsl_rst_i),
    .din(fsl_ring_in_data),
    .wr_en(fsl_ring_in_wr & ~fsl_rst_i),
    .rd_en(vec_rd),
    .dout(vec_dout),
    .full(),
    .empty(vec_empty)
);

always @(posedge vec_clk) begin
    if(fsl_rst_i) begin
        full_latch <= 0;
    end else begin
        if(fsl_fifo_out_full & !des_rst)
            full_latch <= 1;
    end
end

wire [6:0] CORE_wire = CORE;
reg steal, steal_0, ro_empty;
reg [2:0] fsl_ring_state;
reg [159:0] fsl_fifo_out_data_0;
wire steal_cmp = steal && (fsl_data_i[31] == `RING_DIN || !fsl_valid_i);
wire fsl_ring_in_wr_cmp = steal_0 && fsl_valid_i && fsl_ring_in_data[159] == `RING_DIN;
always @(posedge fsl_clk) begin
    fsl_fifo_out_rd <= 0;
    fsl_ring_in_wr  <= 0;
    fsl_rst_o       <= fsl_rst_i;
    fsl_data_o      <= fsl_data_i;
    fsl_valid_o     <= fsl_valid_i;

    if(fsl_rst_i) begin
        fsl_ring_in_data <= 0;
        fsl_ring_state   <= 0;
        steal            <= 0;
        steal_0          <= 0;
        ro_empty         <= 0;
    end else begin
        case(fsl_ring_state)
        0: begin
            steal_0 <= steal_cmp;
            
            // if we're supposed to steal the next value and it's a RING_DIN type, then steal
            if(steal_cmp) begin
                if(!ro_empty) begin
                    fsl_data_o  <= {`RING_DOUT, fsl_fifo_out_data_0[158:128]};
                    fsl_valid_o <= 1;
                    fsl_fifo_out_rd <= 1; // toggle read so empty flag is available later
                end else
                    fsl_valid_o <= 0;
            end
            
            fsl_ring_in_data[159:128] <= fsl_data_i;
        end
        1: begin
            if(steal_0) begin
                if(!ro_empty) begin
                    fsl_data_o  <= fsl_fifo_out_data_0[127:96];
                    fsl_valid_o <= 1;
                end else
                    fsl_valid_o <= 0;
            end
            
            fsl_ring_in_data[127:96] <= fsl_data_i;
        end
        2: begin
            if(steal_0) begin
                if(!ro_empty) begin
                    fsl_data_o  <= fsl_fifo_out_data_0[95:64];
                    fsl_valid_o <= 1;
                end else
                    fsl_valid_o <= 0;
            end
             
            fsl_ring_in_data[95:64] <= fsl_data_i;
        end
        3: begin
            if(steal_0) begin
                if(!ro_empty) begin
                    fsl_data_o  <= fsl_fifo_out_data_0[63:32];
                    fsl_valid_o <= 1;
                end else
                    fsl_valid_o <= 0;
            end
            
            fsl_ring_in_data[63:32] <= fsl_data_i;
        end
        4: begin
            if(steal_0) begin
                if(!ro_empty) begin
                    fsl_data_o  <= fsl_fifo_out_data_0[31:0];
                    fsl_valid_o <= 1;
                    $display("fsl_to_bus_%1d: inserted %x into ring", CORE, fsl_fifo_out_data_0);
                end else
                    fsl_valid_o <= 0;
            end
            
            fsl_ring_in_data[31:0] <= fsl_data_i;
            
            // if we're stealing a din value, then toggle write
            if(fsl_ring_in_wr_cmp) begin
                fsl_ring_in_wr <= 1;
                $display("fsl_to_bus_%1d: stole %x from ring", CORE, {fsl_ring_in_data[159:32], fsl_data_i});
            end
            
            // steal a value if there's data available to send out on the ring or if our input is empty
            steal <= !fsl_fifo_out_empty | (vec_empty & !fsl_ring_in_wr_cmp);
            
            // save our ring output empty signal so it's valid for whole next fsl cycle
            ro_empty <= fsl_fifo_out_empty;
            
            // save our ring output data for next cycle
            fsl_fifo_out_data_0 <= fsl_fifo_out_data;
        end
        endcase
        
        if(fsl_ring_state == 4)
            fsl_ring_state <= 0;
        else
            fsl_ring_state <= fsl_ring_state + 1;
    end
end


endmodule
