/*
* File Name : PicoStreamToAXI.v
*
* Description :  Module to convert streaming data to the AXI protocol and
*                vice-versa.  This module also handles the upsizing and 
*                downsizing required of the data due to the stream width 
*                versus memory width differences.
*
* Diagram       :
*                              input                       output
*                              stream                      stream
*
*                   +------------+----------------------------^----------------+
*                   |            |                            |                |
*                   |            |        PicoStreamToAXI     |                |
*                   |            |                            |                |
*                   |            |                            |                |
*                   |        +---v----------------------------+--+             |
*                   |        |          StreamAXICtrl            |             |
*                   |        |                                   |             |
*                   |        |receives commands from the stream  |             |
*                   |        |and converts this to AXI read/write|             |
*                   |        |commands                           |             |
*                   |        +-+---+---+--------------------^--^-+             |
*                   |          |   |   |                    |  |               |
*                   |          |   |   |                    |  |               |
*                   |          |   |   |                    |  |               |
*                   | +--------v---v---v------+    +--------+--+-------------+ |
*                   | |    PicoAXIUpsizer     |    |   PicoAXIDownSizer      | |
*                   | |                       |    |                         | |
*                   | |Converts 128-bit AXI   |    |Converts write and read  | |
*                   | |commands and write data|    |responses down to 128-bit| |
*                   | |to a wider or equally  |    |wide AXI bus             | |
*                   | |wide AXI bus           |    |                         | |
*                   | +--------+---+---+------+    +--------^--^-------------+ |
*                   |          |   |   |                    |  |               |
*                   |          |   |   |                    |  |               |
*                   |          |   |   |                    |  |               |
*                   +----------v---v---v--------------------+--+---------------+
*
*                                           AXI BUS
*
* Copyright 2011 Pico Computing, Inc.
*/
`include "axi_defines.v"
module PicoStreamToAXI #(
    parameter C_AXI_ID_WIDTH    = 8, 
    parameter C_AXI_ADDR_WIDTH  = 32, 
    parameter STREAM_DATA_WIDTH = 128,  // width of the streaming data
    parameter UPSIZE_RATIO      = 2,    // C_AXI_DATA_WIDTH = STREAM_DATA_WIDTH * UPSIZE_RATIO
    parameter LOG_UPSIZE_RATIO  = 1,    // = ceil(log(UPSIZE_RATIO))
    parameter MAX_LEN           = `MAX_AXI_LEN,

    // don't change parameters below this line
    parameter C_AXI_DATA_WIDTH  = UPSIZE_RATIO * STREAM_DATA_WIDTH
    ) 
    (
	//------------------------------------------------------
	// Pico Stream Interface
	//------------------------------------------------------
    input                                   clk,
    input                                   rst,
      
    input                                   si_valid,
    output                                  si_ready,
    input       [STREAM_DATA_WIDTH-1:0]     si_data,
      
    output                                  so_valid,
    input                                   so_ready,
    output      [STREAM_DATA_WIDTH-1:0]     so_data,

	//------------------------------------------------------
	// DDR3 - AXI ports
	//------------------------------------------------------

    // AXI write address channel signals
    input                                   s_axi_awready,  // Indicates slave is ready to accept a 
    output                                  s_axi_awvalid,  // Write address valid
    output      [C_AXI_ID_WIDTH-1:0]        s_axi_awid,     // Write ID
    output      [C_AXI_ADDR_WIDTH-1:0]      s_axi_awaddr,   // Write address
    output      [7:0]                       s_axi_awlen,    // Write Burst Length
    output      [2:0]                       s_axi_awsize,   // Write Burst size
    output      [1:0]                       s_axi_awburst,  // Write Burst type
    output                                  s_axi_awlock,   // Write lock type
    output      [3:0]                       s_axi_awcache,  // Write Cache type
    output      [2:0]                       s_axi_awprot,   // Write Protection type
    output      [3:0]                       s_axi_awqos,    // Write Quality of Service Signaling
     
    // AXI write data channel signals
    input                                   s_axi_wready,   // Write data ready
    output                                  s_axi_wvalid,   // Write valid
    output      [C_AXI_DATA_WIDTH-1:0]      s_axi_wdata,    // Write data
    output      [C_AXI_DATA_WIDTH/8-1:0]    s_axi_wstrb,    // Write strobes
    output                                  s_axi_wlast,    // Last write transaction   
     
    // AXI write response channel signals
    input       [C_AXI_ID_WIDTH-1:0]        s_axi_bid,      // Response ID
    input       [1:0]                       s_axi_bresp,    // Write response
    input                                   s_axi_bvalid,   // Write reponse valid
    output                                  s_axi_bready,   // Response ready
     
    // AXI read address channel signals
    input                                   s_axi_arready,  // Read address ready
    output                                  s_axi_arvalid,  // Read address valid
    output      [C_AXI_ID_WIDTH-1:0]        s_axi_arid,     // Read ID
    output      [C_AXI_ADDR_WIDTH-1:0]      s_axi_araddr,   // Read address
    output      [7:0]                       s_axi_arlen,    // Read Burst Length
    output      [2:0]                       s_axi_arsize,   // Read Burst size
    output      [1:0]                       s_axi_arburst,  // Read Burst type
    output                                  s_axi_arlock,   // Read lock type
    output      [3:0]                       s_axi_arcache,  // Read Cache type
    output      [2:0]                       s_axi_arprot,   // Read Protection type
    output      [3:0]                       s_axi_arqos,    // Read Quality of Service Signaling 
     
    // AXI read data channel signals   
    input       [C_AXI_ID_WIDTH-1:0]        s_axi_rid,      // Response ID
    input       [1:0]                       s_axi_rresp,    // Read response
    input                                   s_axi_rvalid,   // Read reponse valid
    input       [C_AXI_DATA_WIDTH-1:0]      s_axi_rdata,    // Read data
    input                                   s_axi_rlast,    // Read last
    output                                  s_axi_rready,   // Read Response ready
   
	//------------------------------------------------------
    // Signals to and from the DDR3
	//------------------------------------------------------
    output                                  ddr3_reset,
    input                                   init_cmptd
    );

    // LOCAL SIGNALS
    wire                                    axi_awready;
    wire                                    axi_awvalid;  
    wire        [C_AXI_ID_WIDTH-1:0]        axi_awid;   
    wire        [C_AXI_ADDR_WIDTH-1:0]      axi_awaddr;
    wire        [7:0]                       axi_awlen;   
    wire        [2:0]                       axi_awsize;  
    wire        [1:0]                       axi_awburst;
    wire                                    axi_awlock;   
    wire        [3:0]                       axi_awcache;  
    wire        [2:0]                       axi_awprot;   
    wire        [3:0]                       axi_awqos;  
    
    wire        [STREAM_DATA_WIDTH-1:0]     axi_wdata;
    wire        [STREAM_DATA_WIDTH/8-1:0]   axi_wstrb;
    wire                                    axi_wready;
    wire                                    axi_wvalid;
    wire                                    axi_wlast;
     
    wire                                    axi_arready;
    wire                                    axi_arvalid;
    wire        [C_AXI_ID_WIDTH-1:0]        axi_arid;
    wire        [C_AXI_ADDR_WIDTH-1:0]      axi_araddr;
    wire        [7:0]                       axi_arlen;
    wire        [2:0]                       axi_arsize;
    wire        [1:0]                       axi_arburst;
    wire                                    axi_arlock;
    wire        [3:0]                       axi_arcache;
    wire        [2:0]                       axi_arprot;
    wire        [3:0]                       axi_arqos;

    wire        [C_AXI_ID_WIDTH-1:0]        axi_rid;
    wire        [1:0]                       axi_rresp;
    wire        [STREAM_DATA_WIDTH-1:0]     axi_rdata;
    wire                                    axi_rlast;
    wire                                    axi_rvalid;
    wire                                    axi_rready;
    
    // host streaming interface sits on port 0 of the axi interconnect
    StreamAXICtrl #(
        .MAX_LEN            (MAX_LEN),
        .C_AXI_ID_WIDTH     (C_AXI_ID_WIDTH), 
        .C_AXI_ADDR_WIDTH   (C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH   (STREAM_DATA_WIDTH)
    ) 
    stream_control 
    (
         
        .ddr3_reset         (ddr3_reset),
        .init_cmptd         (init_cmptd),
        
        // streaming interface
        .clk                (clk),
        .rst                (rst),
        .si_ready           (si_ready),
        .si_valid           (si_valid),
        .si_data            (si_data),
        .so_ready           (so_ready),
        .so_valid           (so_valid),
        .so_data            (so_data),

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
        .s_axi_bid          (s_axi_bid),       
        .s_axi_bresp        (s_axi_bresp),     
        .s_axi_bvalid       (s_axi_bvalid),    
        .s_axi_bready       (s_axi_bready),    
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
    
    // convert the write data from 128 bits to whatever the memory system
    // requires
    PicoAXIUpsizer #(
        .C_AXI_ID_WIDTH         (C_AXI_ID_WIDTH), 
        .C_AXI_ADDR_WIDTH       (C_AXI_ADDR_WIDTH),
        .C_AXI_SLAVE_DATA_WIDTH (STREAM_DATA_WIDTH),
        .UPSIZE_RATIO           (UPSIZE_RATIO),
        .LOG_UPSIZE_RATIO       (LOG_UPSIZE_RATIO)
    )
    upsizer
    (
        // common signals
        .aclk               (clk),
        .aresetn            (~rst),

        // stream side
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

        // AXI interconnect side
        .m_axi_awid         (s_axi_awid),      
        .m_axi_awaddr       (s_axi_awaddr),    
        .m_axi_awlen        (s_axi_awlen),     
        .m_axi_awsize       (s_axi_awsize),    
        .m_axi_awburst      (s_axi_awburst),   
        .m_axi_awlock       (s_axi_awlock),    
        .m_axi_awcache      (s_axi_awcache),   
        .m_axi_awprot       (s_axi_awprot),    
        .m_axi_awqos        (s_axi_awqos),     
        .m_axi_awvalid      (s_axi_awvalid),   
        .m_axi_awready      (s_axi_awready),   
        
        .m_axi_wdata        (s_axi_wdata),     
        .m_axi_wstrb        (s_axi_wstrb),     
        .m_axi_wlast        (s_axi_wlast),     
        .m_axi_wvalid       (s_axi_wvalid),    
        .m_axi_wready       (s_axi_wready),
        
        .m_axi_arid         (s_axi_arid),      
        .m_axi_araddr       (s_axi_araddr),    
        .m_axi_arlen        (s_axi_arlen),     
        .m_axi_arsize       (s_axi_arsize),    
        .m_axi_arburst      (s_axi_arburst),   
        .m_axi_arlock       (s_axi_arlock),    
        .m_axi_arcache      (s_axi_arcache),   
        .m_axi_arprot       (s_axi_arprot),    
        .m_axi_arqos        (s_axi_arqos),     
        .m_axi_arvalid      (s_axi_arvalid),   
        .m_axi_arready      (s_axi_arready)   
    );

    // convert the larger memory data back into smaller blocks for streaming
    PicoAXIDownsizer #(
        .C_AXI_ID_WIDTH         (C_AXI_ID_WIDTH),
        .C_AXI_SLAVE_DATA_WIDTH (STREAM_DATA_WIDTH),
        .UPSIZE_RATIO           (UPSIZE_RATIO)
    ) 
    downsizer
    (
        // common signals
        .aclk               (clk),
        .aresetn            (~rst),

        // stream side
        .s_axi_rid          (axi_rid),
        .s_axi_rdata        (axi_rdata),     
        .s_axi_rresp        (axi_rresp),     
        .s_axi_rlast        (axi_rlast),     
        .s_axi_rvalid       (axi_rvalid),    
        .s_axi_rready       (axi_rready),    

        // AXI interconnect side
        .m_axi_rid          (s_axi_rid),
        .m_axi_rdata        (s_axi_rdata),
        .m_axi_rresp        (s_axi_rresp),     
        .m_axi_rlast        (s_axi_rlast),     
        .m_axi_rvalid       (s_axi_rvalid),    
        .m_axi_rready       (s_axi_rready)
    );

endmodule
