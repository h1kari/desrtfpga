/*
* File Name     : AXIToHMC.v
*
* Description   : This is a communication bridge that converts an AXI protocol
*                 (driven by user logic) over to the HMC protocol.  Note that
*                 this does not do any clock crossing.
*                 
*                 We also buffer some response data in this module, in case
*                 that axi_rready is de-asserted.  This would likely only
*                 happen if the PCIe bus backs up, which is entirely possible.
*                                  
*                 Note: our standard arbitration for read/write commands is
*                 fixed with the reads having the priority
*                 Note: we send the write response immediately after sending
*                 the write command.
*                 Note: we do not do any read response re-ordering.  Reads may
*                 come back out of order.
*                 Note: we do not create the 'axi_rlast' signal
*                 Note: we do not pay attention to the axi_bready signal
*                 Note: we have cooked up a new signal called
*                 'hmc_rd_data_ready'.  when this is asserted, whatever is
*                 feeding the hmc_rd_data_valid signal should slow down
*
* Copyright     : 2015, Micron Inc.
*/

`include "PicoDefines.v"

// Need HMC_CMD_RD and HMC_CMD_WR from hmc_def
`ifdef ENABLE_HMC
    `include "hmc_def.vh"
`else
    `define HMC_CMD_RD      0
    `define HMC_CMD_WR      0
    `define HMC_CMD_BW      0
`endif

module AXIToHMC #(
    parameter C_AXI_ID_WIDTH    = 6, 
    parameter C_AXI_ADDR_WIDTH  = 32, 
    parameter STREAM_DATA_WIDTH = 128,
    parameter UPSIZE_RATIO      = 1,
    parameter LOG_UPSIZE_RATIO  = 0,
    // When SUPPORT_SUB16BWR == 1, allow axi_wstrb signal to indicate when
    // a hmc bitwrite operation is needed in order to perform a sub-16 byte
    // memory operation
    parameter SUPPORT_SUB16BWR = 1 , // turn on by default
    
    // don't change parameters below this line
    parameter C_AXI_DATA_WIDTH  = UPSIZE_RATIO * STREAM_DATA_WIDTH
)
(
    input                                   clk,
    input                                   rst,

    output                                  axi_awready,
    input                                   axi_awvalid,  
    input       [C_AXI_ID_WIDTH-1:0]        axi_awid,   
    input       [C_AXI_ADDR_WIDTH-1:0]      axi_awaddr,
    input       [7:0]                       axi_awlen,   
    input       [2:0]                       axi_awsize,  
    input       [1:0]                       axi_awburst,
    input                                   axi_awlock,   
    input       [3:0]                       axi_awcache,  
    input       [2:0]                       axi_awprot,   
    input       [3:0]                       axi_awqos,  
    
    input       [STREAM_DATA_WIDTH-1:0]     axi_wdata,
    input       [STREAM_DATA_WIDTH/8-1:0]   axi_wstrb,
    output                                  axi_wready,
    input                                   axi_wvalid,
    input                                   axi_wlast,
    
    output      [C_AXI_ID_WIDTH-1:0]        axi_bid,
    output      [1:0]                       axi_bresp,
    output                                  axi_bvalid,
    input                                   axi_bready,
     
    output                                  axi_arready,
    input                                   axi_arvalid,
    input       [C_AXI_ID_WIDTH-1:0]        axi_arid,
    input       [C_AXI_ADDR_WIDTH-1:0]      axi_araddr,
    input       [7:0]                       axi_arlen,
    input       [2:0]                       axi_arsize,
    input       [1:0]                       axi_arburst,
    input                                   axi_arlock,
    input       [3:0]                       axi_arcache,
    input       [2:0]                       axi_arprot,
    input       [3:0]                       axi_arqos,

    output      [C_AXI_ID_WIDTH-1:0]        axi_rid,
    output      [1:0]                       axi_rresp,
    output      [STREAM_DATA_WIDTH-1:0]     axi_rdata,
    output                                  axi_rlast,
    output                                  axi_rvalid,
    input                                   axi_rready,

    // Standard HMC Interface
    output                          hmc_clk,
    output                          hmc_cmd_valid,
    input                           hmc_cmd_ready,
    output      [3:0]               hmc_cmd,
    output      [33:0]              hmc_addr,
    output      [3:0]               hmc_size,
    output      [5:0]               hmc_tag,

    output      [127:0]             hmc_wr_data,
    output                          hmc_wr_data_valid,
    input                           hmc_wr_data_ready,
                                        
    input       [127:0]             hmc_rd_data,
    input       [5:0]               hmc_rd_data_tag,
    input                           hmc_rd_data_valid,
    output                          hmc_rd_data_ready,
    input       [6:0]               hmc_errstat,
    input                           hmc_dinv
);
    
    //////////////////////
    // INTERNAL SIGNALS //
    //////////////////////
    
    // these are all around the response buffer
    wire                            hmc_rd_data_almostfull;
    wire                            axi_rempty;
    
    wire                            dinv;
    wire        [6:0]               errstat;

    //////////////////////
    // AXI TO HMC LOGIC //
    //////////////////////

    // just use the AXI 'clk' as the clock for our HMC interface
    assign  hmc_clk                 = clk;

    wire [STREAM_DATA_WIDTH-1:0] c_hmc_wr_data;
    // write data is a really easy interface
    assign  hmc_wr_data             = c_hmc_wr_data;
    assign  hmc_wr_data_valid       = axi_wvalid;
    assign  axi_wready              = hmc_wr_data_ready;

    // read data is handled in the response buffer (below)
    // TODO: do I need to handle the axi_rlast signal?
    assign  axi_rlast               = 0;
    assign  axi_rresp               = {1'b0, |errstat};
    
    // write response is sent back to the input AXI interface as soon as we
    // accept a write command
    assign  axi_bvalid              = axi_awvalid & axi_awready;
    assign  axi_bresp               = 'h0;
    assign  axi_bid                 = axi_awid;

    // When SUPPORT_SUB16BWR == 1, allow axi_wstrb signal to indicate when
    // a hmc bitwrite operation is needed in order to perform a sub-16 byte
    // memory operation
    // Only coded to add that support when STREAM_DATA_WIDTH == 128 bits.
    wire [3:0] hmc_wr_cmd;
    generate if (SUPPORT_SUB16BWR && (STREAM_DATA_WIDTH == 128)) begin : g_allow_bw
       wire wr16 = axi_wstrb[15:0] == 16'hffff;
       wire [7:0] wstrb = (axi_wstrb[15:8] == 8'h0) ? axi_wstrb[7:0] : axi_wstrb[15:8];
       assign hmc_wr_cmd = (axi_awsize >= 3'h4 /* 16 or more bytes */) ? `HMC_CMD_WR : `HMC_CMD_BW;
       assign c_hmc_wr_data[63:0] = axi_wdata[63:0];			// wr_data
       assign c_hmc_wr_data[71:64] = wr16 ? axi_wdata[71:64] : wstrb[0] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[79:72] = wr16 ? axi_wdata[79:72] : wstrb[1] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[87:80] = wr16 ? axi_wdata[87:80] : wstrb[2] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[95:88] = wr16 ? axi_wdata[95:88] : wstrb[3] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[103:96] = wr16 ? axi_wdata[103:96] : wstrb[4] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[111:104] = wr16 ? axi_wdata[111:104] : wstrb[5] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[119:112] = wr16 ? axi_wdata[119:112] : wstrb[6] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
       assign c_hmc_wr_data[127:120] = wr16 ? axi_wdata[127:120] : wstrb[7] ? 8'h00 : 8'hff;	// wr_data or bitwrite mask
    end else begin : g_only_wr
       assign hmc_wr_cmd = `HMC_CMD_WR;
       assign c_hmc_wr_data = axi_wdata;
    end endgenerate // if (SUPPORT_SUB16BWR && (STREAM_DATA_WIDTH == 128))

    // now we just have to arbitrate our AXI commands onto the HMC interface
    // to make things easy, we always give priority to the reads
    assign  axi_arready             = hmc_cmd_ready;
    assign  axi_awready             = hmc_cmd_ready & ~axi_arvalid;
    assign  hmc_cmd_valid           = axi_arvalid | axi_awvalid;
    assign  hmc_cmd                 = axi_arvalid ? `HMC_CMD_RD     : hmc_wr_cmd;
    assign  hmc_addr                = axi_arvalid ? axi_araddr      : axi_awaddr;
    assign  hmc_size                = axi_arvalid ? axi_arlen + 1   : axi_awlen + 1;
    assign  hmc_tag                 = axi_arvalid ? axi_arid        : axi_awid;
    
    //////////////////////
    // BUFFER RESPONSES //
    //////////////////////

    FIFO #(
        .SYNC                       (1),
        .DATA_WIDTH                 (1+7+C_AXI_ID_WIDTH+C_AXI_DATA_WIDTH)
    ) response_buffer (
        .clk                        (hmc_clk),
        .rst                        (rst),

        .wr_en                      (hmc_rd_data_valid),
        .din                        ({
                                        hmc_dinv,
                                        hmc_errstat,
                                        hmc_rd_data_tag,
                                        hmc_rd_data
                                    }),
        .almostfull                 (hmc_rd_data_almostfull),

        .rd_en                      (axi_rready),
        .dout                       ({
                                        dinv,
                                        errstat,
                                        axi_rid,
                                        axi_rdata
                                    }),
        .empty                      (axi_rempty)
    );
    assign  hmc_rd_data_ready       = ~hmc_rd_data_almostfull;
    assign  axi_rvalid              = ~axi_rempty;

endmodule
