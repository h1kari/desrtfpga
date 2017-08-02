// PicoInterfaces.sv
// Copyright 2014 Pico Computing, Inc.

interface axi_if #(
    C_AXI_ID_WIDTH        = 12,
    C_AXI_ADDR_WIDTH      = 33,
    C_AXI_DATA_WIDTH      = 256
    );

    wire                                    rst;
    wire                                    clk;
   

    logic   [C_AXI_ID_WIDTH-1:0]            awid;
    logic   [C_AXI_ADDR_WIDTH-1:0]          awaddr;
    logic   [7:0]                           awlen;
    logic   [2:0]                           awsize;
    logic   [1:0]                           awburst;
    logic                                   awlock;
    logic   [3:0]                           awcache;
    logic   [2:0]                           awprot;
    logic   [3:0]                           awqos;
    logic                                   awvalid;
    logic                                   awready;

    logic   [C_AXI_DATA_WIDTH-1:0]          wdata;
    logic   [C_AXI_DATA_WIDTH/8-1:0]        wstrb;
    logic                                   wlast;
    logic                                   wvalid;
    logic                                   wready;

    logic   [C_AXI_ID_WIDTH-1:0]            bid;
    logic   [1:0]                           bresp;
    logic                                   bvalid;
    logic                                   bready;

    logic   [C_AXI_ID_WIDTH-1:0]            arid;
    logic   [C_AXI_ADDR_WIDTH-1:0]          araddr;
    logic   [7:0]                           arlen;
    logic   [2:0]                           arsize;
    logic   [1:0]                           arburst;
    logic                                   arlock;
    logic   [3:0]                           arcache;
    logic   [2:0]                           arprot;
    logic   [3:0]                           arqos;
    logic                                   arvalid;
    logic                                   arready;

    logic   [C_AXI_ID_WIDTH-1:0]            rid;
    logic   [C_AXI_DATA_WIDTH-1:0]          rdata;
    logic   [1:0]                           rresp;
    logic                                   rlast;
    logic                                   rvalid;
    logic                                   rready;

    modport slave (
        inout   rst, clk,

        output  awready,
        input   awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid,

        output  wready,
        input   wdata, wstrb, wlast, wvalid,

        output  bid, bresp, bvalid, 
        input   bready,

        output  arready,
        input   arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid,

        output  rid, rdata, rresp, rlast, rvalid,
        input   rready
    );

    modport master (
        inout   rst, clk,

        input   awready,
        output  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid,

        input   wready,
        output  wdata, wstrb, wlast, wvalid,

        input   bid, bresp, bvalid, 
        output  bready,

        input   arready,
        output  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid,

        input   rid, rdata, rresp, rlast, rvalid,
        output  rready
    );

endinterface

/* the sv package is not defined
import PicoModelParams::PCIE_CORE_DATA_ENDIAN;

interface pico_pcie_tx_if;
    logic            [127:0]        hdr;
    logic            [127:0]        data_i;
    logic            [127:0]        data_o;
    logic                           sof;
    logic                           eof;
    logic                           valid;
    logic              [2:0]        data_dw_len;
    logic                           ready;

    modport i (
        input       hdr,
        input      .data(data_i),
        input       sof,
        input       eof,
        input       valid,
        input       data_dw_len,
        output      ready
    );

    modport o (
        output      hdr,
        output     .data(data_o),
        output      sof,
        output      eof,
        output      valid,
        output      data_dw_len,
        input       ready
    );

    generate
        if (PCIE_CORE_DATA_ENDIAN == "BIG") begin
            assign data_i = {
                data_o[96+7:0+96], data_o[96+15:8+96], data_o[96+23:16+96], data_o[96+31:24+96],
                data_o[64+7:0+64], data_o[64+15:8+64], data_o[64+23:16+64], data_o[64+31:24+64],
                data_o[32+7:0+32], data_o[32+15:8+32], data_o[32+23:16+32], data_o[32+31:24+32],
                data_o[7:0], data_o[15:8], data_o[23:16], data_o[31:24]
            };
        end else begin
            assign data_i = data_o;
        end
    endgenerate

endinterface

interface pico_pcie_rx_if;
    logic            [127:0]        hdr;
    logic            [127:0]        data_i;
    logic            [127:0]        data_o;
    logic                           sof;
    logic                           eof;
    logic                           valid;
    logic [7:0]                     bar_hit;

    modport i (
        input       hdr,
        input      .data(data_i),
        input       sof,
        input       eof,
        input       valid,
        input       bar_hit
    );

    modport o (
        output      hdr,
        output     .data(data_o),
        output      sof,
        output      eof,
        output      valid,
        output      bar_hit
    );

    generate
        if (PCIE_CORE_DATA_ENDIAN == "BIG") begin
            assign data_i = {
                data_o[96+7:0+96], data_o[96+15:8+96], data_o[96+23:16+96], data_o[96+31:24+96],
                data_o[64+7:0+64], data_o[64+15:8+64], data_o[64+23:16+64], data_o[64+31:24+64],
                data_o[32+7:0+32], data_o[32+15:8+32], data_o[32+23:16+32], data_o[32+31:24+32],
                data_o[7:0], data_o[15:8], data_o[23:16], data_o[31:24]
            };
        end else begin
            assign data_i = data_o;
        end
    endgenerate

endinterface
*/

interface pico_stream_if #(WIDTH = 128);
    wire clk;
    wire rst;
    logic [WIDTH-1:0] data;
    logic valid, ready;

    modport in (
        input       clk,
        input       rst,
        input       data,
        input       valid,
        output      ready
    );

    modport out (
        input       clk,
        input       rst,
        output      data,
        output      valid,
        input       ready
    );
endinterface

interface pico_bus_if #(WIDTH=32, N_SLAVES=1);

    logic [WIDTH-1:0] din, dout_master;
    logic [WIDTH-1:0] dout_slave [N_SLAVES-1:0];
    logic [31:0] addr;
    wire clk;
    logic rst;
    logic rden, wren;

    modport master (
        output din,
        output addr,
        input clk,
        output rst,
        output rden,
        output wren,
        input .dout(dout_master)
    );

    modport slave (
        input din,
        input addr,
        input clk,
        input rst,
        input rden,
        input wren,
        output .dout(dout_slave[0])
    );

    genvar g;
    generate for (g=0; g<N_SLAVES; g++) begin: gen_slave
        modport p (
            input din,
            input addr,
            input clk,
            input rst,
            input rden,
            input wren,
            output .dout(dout_slave[g])
        );
    end endgenerate

    integer i;
    always_comb begin
        dout_master = 'h0;
        for (i=0; i<N_SLAVES; i++) begin
            dout_master |= dout_slave[i];
        end
    end

endinterface


interface pico_dma_if;
    wire                                s_clk;
    wire                                s_rst;
    logic [127:0]                       s_in_data;
    logic [8:0]                         s_in_id;
    logic                               s_in_valid;

    logic                               s_out_en;
    logic [8:0]                         s_out_id;

    logic [127:0]                       s_out_data;

    logic [8:0]                         s_poll_id;
    logic [31:0]                        s_poll_seq;
    logic                               s_poll_next_desc_valid;
    logic [127:0]                       s_poll_next_desc;


    logic                               s_next_desc_rd_en;
    logic [8:0]                         s_next_desc_rd_id;

    modport master (
        output      s_clk,
        output      s_rst,
        output      s_out_en,
        output      s_out_id,
        input       s_out_data,

        output      s_in_valid,
        output      s_in_id,
        output      s_in_data,

        output      s_poll_id,
        input       s_poll_seq,
        input       s_poll_next_desc,
        input       s_poll_next_desc_valid,

        output      s_next_desc_rd_id,
        output      s_next_desc_rd_en
    );

    modport slave (
        input       s_clk,
        input       s_rst,
        input       s_out_en,
        input       s_out_id,
        output      s_out_data,

        input       s_in_valid,
        input       s_in_id,
        input       s_in_data,

        input       s_poll_id,
        output      s_poll_seq,
        output      s_poll_next_desc,
        output      s_poll_next_desc_valid,

        input       s_next_desc_rd_id,
        input       s_next_desc_rd_en
    );
endinterface

module pico_dma_interconnect # (
    parameter N_SLAVES = 1
) (
    pico_dma_if.slave master,
    pico_dma_if.master slaves [N_SLAVES-1:0]
);
    
    // quartus can't resolve reference to object "slaves" when it appears
    // in "always_comb". need this work around
    logic [127:0]                       s_out_data [N_SLAVES-1:0];
    logic [31:0]                        s_poll_seq [N_SLAVES-1:0];
    logic                               s_poll_next_desc_valid [N_SLAVES-1:0];
    logic [127:0]                       s_poll_next_desc [N_SLAVES-1:0];

    genvar j;
    generate for (j=0; j<N_SLAVES;j++) begin: BLK0
        assign s_out_data[j] = slaves[j].s_out_data;
        assign s_poll_seq[j] = slaves[j].s_poll_seq;
        assign s_poll_next_desc[j] = slaves[j].s_poll_next_desc;
        assign s_poll_next_desc_valid[j] = slaves[j].s_poll_next_desc_valid;
    end endgenerate

    integer i;
    always_comb begin
        master.s_out_data = 128'h0;
        master.s_poll_seq = 32'h0;
        master.s_poll_next_desc = 128'h0;
        master.s_poll_next_desc_valid = 0;

        for (i=0; i<N_SLAVES; i++) begin
            master.s_out_data |= s_out_data[i];
            master.s_poll_seq |= s_poll_seq[i];
            master.s_poll_next_desc |= s_poll_next_desc[i];
            master.s_poll_next_desc_valid |= s_poll_next_desc_valid[i];
        end
    end
    

    generate for (j=0; j<N_SLAVES;j++) begin: BLK
        assign slaves[j].s_clk = master.s_clk;
        assign slaves[j].s_rst = master.s_rst;

        assign slaves[j].s_out_en = master.s_out_en;
        assign slaves[j].s_out_id = master.s_out_id;

        assign slaves[j].s_in_valid = master.s_in_valid;
        assign slaves[j].s_in_id = master.s_in_id;
        assign slaves[j].s_in_data = master.s_in_data;

        assign slaves[j].s_poll_id = master.s_poll_id;

        assign slaves[j].s_next_desc_rd_id = master.s_next_desc_rd_id;
        assign slaves[j].s_next_desc_rd_en = master.s_next_desc_rd_en;
    end endgenerate

endmodule

interface pico_card_info ();
    logic [7:0] PBWidth;
    modport in (
        input PBWidth
    );
    modport out (
        output PBWidth
    );
endinterface

