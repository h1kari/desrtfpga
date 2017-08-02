/*
* File Name     : PicoStreamToHMC.v
*
* Description   : Module to convert streaming data to the HMC protocol and
*                 vice-versa.  This assumes we have 128-bit streams and
*                 a 128-bit HMC interface.
*                 
* Diagram       :
*                        input                      output
*                        stream                     stream
*
*                   +------+--------------------------^-----+
*                   |      |                          |     |
*                   |      |     PicoStreamToHMC      |     |
*                   |      |                          |     |
*                   | +----v--------------------------+---+ |
*                   | |          PicoStreamToAXI          | |
*                   | |                                   | |
*                   | |receives commands from the stream  | |
*                   | |and converts this to AXI read/write| |
*                   | |commands                           | |
*                   | +----+--+--+----------------^--^----+ |
*                   |      |  |  |                |  |      |
*                   |      |  |  |                |  |      |
*                   |      |  |  |                |  |      |
*                   | +----v--v--v----------------+--+----+ |
*                   | |          AXIToHMC                 | |
*                   | |                                   | |
*                   | |Converts AXI protocol to the HMC   | |
*                   | |protocol                           | |
*                   | +------------+----+----^------------+ |
*                   |              |    |    |              |
*                   |              |    |    |              |
*                   +--------------v----v----+--------------+
*
*                               HMC User Interface
*
* Copyright     : 2015, Micron Inc.
*/
module PicoStreamToHMC #(
    parameter C_AXI_ID_WIDTH       = 6,
    parameter C_AXI_ADDR_WIDTH     = 32,
    parameter C_AXI_DATA_WIDTH     = 128
)
(
	//------------------------------------------------------
	// Pico Stream Interface
	//------------------------------------------------------
    input                           clk,
    input                           rst,
      
    input                           si_valid,
    output                          si_ready,
    input       [127:0]             si_data,
      
    output                          so_valid,
    input                           so_ready,
    output      [127:0]             so_data,
	
    //------------------------------------------------------
	// HMC
	//------------------------------------------------------
    input                           hmc_tx_clk,
    input                           hmc_rx_clk,
    input                           hmc_rst,
    input                           hmc_trained,

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
  
    // AXI signals
    // Stream Clock Domain
    wire    [C_AXI_ID_WIDTH-1:0]            axi_awid;
    wire    [C_AXI_ADDR_WIDTH-1:0]          axi_awaddr;
    wire    [7:0]                           axi_awlen;
    wire    [2:0]                           axi_awsize;
    wire    [1:0]                           axi_awburst;
    wire    [0:0]                           axi_awlock;
    wire    [3:0]                           axi_awcache;
    wire    [2:0]                           axi_awprot;
    wire    [3:0]                           axi_awqos;
    wire                                    axi_awvalid;
    wire                                    axi_awready;
    
    wire    [C_AXI_DATA_WIDTH-1:0]          axi_wdata;
    wire    [C_AXI_DATA_WIDTH/8-1:0]        axi_wstrb;
    wire                                    axi_wlast;
    wire                                    axi_wvalid;
    wire                                    axi_wready;
    
    wire    [C_AXI_ID_WIDTH-1:0]            axi_bid;
    wire    [1:0]                           axi_bresp;
    wire                                    axi_bvalid;
    wire                                    axi_bready;
    
    wire    [C_AXI_ID_WIDTH-1:0]            axi_arid;
    wire    [C_AXI_ADDR_WIDTH-1:0]          axi_araddr;
    wire    [7:0]                           axi_arlen;
    wire    [2:0]                           axi_arsize;
    wire    [1:0]                           axi_arburst;
    wire    [0:0]                           axi_arlock;
    wire    [3:0]                           axi_arcache;
    wire    [2:0]                           axi_arprot;
    wire    [3:0]                           axi_arqos;
    wire                                    axi_arvalid;
    wire                                    axi_arready;
    
    wire    [C_AXI_ID_WIDTH-1:0]            axi_rid;
    wire    [C_AXI_DATA_WIDTH-1:0]          axi_rdata;
    wire    [1:0]                           axi_rresp;
    wire                                    axi_rlast;
    wire                                    axi_rvalid;
    wire                                    axi_rready;
   
    // Handles the stream interface and creates AXI signals
    PicoStreamToAXI #(
        .MAX_LEN            (8),
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH), 
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .STREAM_DATA_WIDTH  (C_AXI_DATA_WIDTH),
        .UPSIZE_RATIO       (1),
        .LOG_UPSIZE_RATIO   (0)
    ) 
    stream_to_mem_0
    (
        // streaming interface
        .clk                (clk),
        .rst                (rst),

        .si_ready           (si_ready),
        .si_valid           (si_valid),
        .si_data            (si_data),
        .so_ready           (so_ready),
        .so_valid           (so_valid),
        .so_data            (so_data),

        // ddr3 signals
        .ddr3_reset         (),
        .init_cmptd         (hmc_trained),

        // axi interface
        .s_axi_awid         (axi_awid),
        .s_axi_awaddr       (axi_awaddr), 
        .s_axi_awlen        (axi_awlen),  
        .s_axi_awsize       (axi_awsize), 
        .s_axi_awburst      (axi_awburst),
        .s_axi_awlock       (axi_awlock), 
        .s_axi_awcache      (axi_awcache),
        .s_axi_awprot       (axi_awprot), 
        .s_axi_awqos        (axi_awqos),  
        .s_axi_awvalid      (axi_awvalid),
        .s_axi_awready      (axi_awready),
        .s_axi_wdata        (axi_wdata),  
        .s_axi_wstrb        (axi_wstrb),  
        .s_axi_wlast        (axi_wlast),  
        .s_axi_wvalid       (axi_wvalid), 
        .s_axi_wready       (axi_wready), 
        .s_axi_bid          (axi_bid),    
        .s_axi_bresp        (axi_bresp),  
        .s_axi_bvalid       (axi_bvalid), 
        .s_axi_bready       (axi_bready), 
        .s_axi_arid         (axi_arid),   
        .s_axi_araddr       (axi_araddr), 
        .s_axi_arlen        (axi_arlen),  
        .s_axi_arsize       (axi_arsize), 
        .s_axi_arburst      (axi_arburst),
        .s_axi_arlock       (axi_arlock), 
        .s_axi_arcache      (axi_arcache),
        .s_axi_arprot       (axi_arprot), 
        .s_axi_arqos        (axi_arqos),  
        .s_axi_arvalid      (axi_arvalid),
        .s_axi_arready      (axi_arready),
        .s_axi_rid          (axi_rid),    
        .s_axi_rdata        (axi_rdata),  
        .s_axi_rresp        (axi_rresp),  
        .s_axi_rlast        (axi_rlast),  
        .s_axi_rvalid       (axi_rvalid), 
        .s_axi_rready       (axi_rready)    
    );

    // Converts AXI protocol traffic to the HMC protocol
    AXIToHMCWrapper #(
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH), 
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .STREAM_DATA_WIDTH  (C_AXI_DATA_WIDTH),
        .UPSIZE_RATIO       (1),
        .LOG_UPSIZE_RATIO   (0)
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
        .hmc_cmd_valid      (hmc_cmd_valid),
        .hmc_cmd_ready      (hmc_cmd_ready),
        .hmc_cmd            (hmc_cmd),
        .hmc_addr           (hmc_addr),
        .hmc_size           (hmc_size),
        .hmc_tag            (hmc_tag),
        .hmc_wr_data        (hmc_wr_data),
        .hmc_wr_data_valid  (hmc_wr_data_valid),
        .hmc_wr_data_ready  (hmc_wr_data_ready),
        .hmc_rd_data        (hmc_rd_data),
        .hmc_rd_data_tag    (hmc_rd_data_tag),
        .hmc_rd_data_valid  (hmc_rd_data_valid),
        .hmc_errstat        (hmc_errstat),
        .hmc_dinv           (hmc_dinv)
    );
    
endmodule
