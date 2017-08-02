/*
* File Name     : AXIToHMCWrapper.v
*
* Description   : This wrapper instantiates the AXIToHMC module, but it also
*                 instantiates the following:
*                 1) HMCTagManager 
*                   - prevents the AXIToHMC module from issuing a read request
*                   unless we have a tag available
*                 2) HMCReorder
*                   - response data reordering buffer
*
*                 Note: we assume that STREAM_DATA_WIDTH=128, which is the HMC
*                 data width, so we don't have to do any size conversions.
*
* Copyright     : 2015, Micron Inc.
*/
module AXIToHMCWrapper #(
    parameter C_AXI_ID_WIDTH    = 6, 
    parameter C_AXI_ADDR_WIDTH  = 32, 
    
    // don't change parameters below this line
    parameter STREAM_DATA_WIDTH = 128,
    parameter UPSIZE_RATIO      = 1,
    parameter LOG_UPSIZE_RATIO  = 0,
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
    input       [6:0]               hmc_errstat,
    input                           hmc_dinv
);

    ///////////////////////
    // INTERNALS SIGNALS //
    ///////////////////////
    
    // signals going into the tag manager
    wire                            cmd_valid;
    wire                            cmd_ready;
    wire        [3:0]               cmd;
    wire        [33:0]              addr;
    wire        [3:0]               size;
    wire        [5:0]               tag;

    // signals coming out of the response buffer
    wire        [127:0]             rd_data;
    wire        [5:0]               rd_data_tag;
    wire                            rd_data_valid;
    wire                            rd_data_ready;
    wire        [6:0]               errstat;
    wire                            dinv;

    ///////////////////////
    // INTERNALS MODULES //
    ///////////////////////

    // Convers the AXI input bus to the HMC protocol
    AXIToHMC #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH), 
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .STREAM_DATA_WIDTH  (C_AXI_DATA_WIDTH),
        .UPSIZE_RATIO       (UPSIZE_RATIO),
        .LOG_UPSIZE_RATIO   (LOG_UPSIZE_RATIO)
    ) axi_to_hmc (
        .clk                (clk),
        .rst                (rst),

        .axi_awid           (axi_awid),
        .axi_awaddr         (axi_awaddr), 
        .axi_awlen          (axi_awlen),  
        .axi_awsize         (axi_awsize), 
        .axi_awburst        (axi_awburst),
        .axi_awlock         (axi_awlock), 
        .axi_awcache        (axi_awcache),
        .axi_awprot         (axi_awprot), 
        .axi_awqos          (axi_awqos),  
        .axi_awvalid        (axi_awvalid),
        .axi_awready        (axi_awready),
        .axi_wdata          (axi_wdata),  
        .axi_wstrb          (axi_wstrb),  
        .axi_wlast          (axi_wlast),  
        .axi_wvalid         (axi_wvalid), 
        .axi_wready         (axi_wready), 
        .axi_bid            (axi_bid),    
        .axi_bresp          (axi_bresp),  
        .axi_bvalid         (axi_bvalid), 
        .axi_bready         (axi_bready), 
        .axi_arid           (axi_arid),   
        .axi_araddr         (axi_araddr), 
        .axi_arlen          (axi_arlen),  
        .axi_arsize         (axi_arsize), 
        .axi_arburst        (axi_arburst),
        .axi_arlock         (axi_arlock), 
        .axi_arcache        (axi_arcache),
        .axi_arprot         (axi_arprot), 
        .axi_arqos          (axi_arqos),  
        .axi_arvalid        (axi_arvalid),
        .axi_arready        (axi_arready),
        .axi_rid            (axi_rid),    
        .axi_rdata          (axi_rdata),  
        .axi_rresp          (axi_rresp),  
        .axi_rlast          (axi_rlast),  
        .axi_rvalid         (axi_rvalid), 
        .axi_rready         (axi_rready),

        .hmc_clk            (hmc_clk),
        .hmc_cmd_valid      (cmd_valid),
        .hmc_cmd_ready      (cmd_ready),
        .hmc_cmd            (cmd),
        .hmc_addr           (addr),
        .hmc_size           (size),
        .hmc_tag            (tag),
        .hmc_wr_data        (hmc_wr_data),
        .hmc_wr_data_valid  (hmc_wr_data_valid),
        .hmc_wr_data_ready  (hmc_wr_data_ready),
        .hmc_rd_data        (rd_data),
        .hmc_rd_data_tag    (rd_data_tag),
        .hmc_rd_data_valid  (rd_data_valid),
        .hmc_rd_data_ready  (rd_data_ready),
        .hmc_errstat        (errstat),
        .hmc_dinv           (dinv)
    );
    
    // manages the tags and ensures that we don't re-use a tag before we are
    // ready
    // Note: we limit the tags (i.e. max size of outstanding read data) in
    // order to ensure we don't drop read data on the floor in the event that
    // our output stream applies backpressure
    HMCTagManager #(
        .ID_WIDTH           (5),
        .DATA_WIDTH         (128)
    ) tag_manager (
        .clk                (hmc_clk),
        .rst                (rst),

        .cmd_in             (cmd),
        .cmd_valid_in       (cmd_valid),
        .cmd_ready_in       (cmd_ready),
        .addr_in            (addr),
        .tag_in             (tag),
        .size_in            (size),
        
        .cmd_out            (hmc_cmd),
        .cmd_valid_out      (hmc_cmd_valid),
        .cmd_ready_out      (hmc_cmd_ready),
        .addr_out           (hmc_addr),
        .tag_out            (hmc_tag),
        .size_out           (hmc_size),

        .rd_data_tag        (rd_data_tag),
        .rd_data_valid      (rd_data_valid),
        .rd_data_ready      (rd_data_ready)
    );
    assign  hmc_tag [5]     = 1'b0;

    // reorders response data
    HMCReorder #(
        .ID_WIDTH           (6),
        .DATA_WIDTH         (128)
    ) hmc_reorder (
        .clk                (hmc_clk),
        .rst                (rst),

        .cmd                (hmc_cmd),
        .cmd_valid          (hmc_cmd_valid),
        .cmd_ready          (hmc_cmd_ready),
        .tag                (hmc_tag),
        .size               (hmc_size),

        .rd_data_in         (hmc_rd_data),
        .rd_data_tag_in     (hmc_rd_data_tag),
        .rd_data_valid_in   (hmc_rd_data_valid),
        .errstat_in         (hmc_errstat),
        .dinv_in            (hmc_dinv),

        .rd_data_out        (rd_data),
        .rd_data_tag_out    (rd_data_tag),
        .rd_data_valid_out  (rd_data_valid),
        .errstat_out        (errstat),
        .dinv_out           (dinv)
    );

endmodule
