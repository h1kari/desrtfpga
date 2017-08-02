/*
* File Name : PicoAXIUpsizer.v
*
* Description : This module is used to create a wider bus from a narrow bus by
*               joining consecutive transactions on the narrow bus to form
*               a single transaction on the larger bus.  This is done by
*               placing the transactions from the smaller bus into multiple
*               fifos (which act in parallel) in a round-robin fashion.  The
*               read side of the fifos reads from all fifos at the same time
*               once they all contain valid data.  This module uses
*               asynchronous FIFOs, so the narrow bus side can also operate on
*               a faster clock frequency than the wider bus (to achieve the
*               same throughput).
*               
*               Note: the master data width must be a multiple of the slave
*                     data width
*
* Creation Date : Wed 31 Aug 2011 01:49:56 PM PDT
*
* Author : Corey Olson
*
* Last Modified : Wed 31 Aug 2011 02:28:47 PM PDT
*
* Copyright 2011 Pico Computing, Inc.
*/
module PicoAXIUpsizer #(
    parameter C_AXI_ID_WIDTH                = 8,    // width of the AXI transaction ID
    parameter C_AXI_ADDR_WIDTH              = 32,   // width of the AXI address (byte addressable)
    parameter C_AXI_SLAVE_DATA_WIDTH        = 128,  // width of the slave port data width
    parameter UPSIZE_RATIO                  = 2,    // C_AXI_MASTER_DATA_WIDTH = C_AXI_SLAVE_DATA_WIDTH * UPSIZE_RATIO
                                                    //  NOTE: UPSIZE_RATIO must be a power of 2
    parameter LOG_UPSIZE_RATIO              = 1     // = ceil(log(UPSIZE_RATIO))
    )
    (
    // COMMON SIGNALS
    input                                                   aclk,
    input                                                   aresetn,
    
    // SLAVE PORT
    output                                                  s_axi_awready,
    input                                                   s_axi_awvalid,
    input       [C_AXI_ID_WIDTH-1:0]                        s_axi_awid,
    input       [C_AXI_ADDR_WIDTH-1:0]                      s_axi_awaddr,
    input       [7:0]                                       s_axi_awlen,
    input       [2:0]                                       s_axi_awsize,
    input       [1:0]                                       s_axi_awburst,
    input                                                   s_axi_awlock,
    input       [3:0]                                       s_axi_awcache,
    input       [2:0]                                       s_axi_awprot,
    input       [3:0]                                       s_axi_awqos,
    
    input       [C_AXI_SLAVE_DATA_WIDTH-1:0]                s_axi_wdata,
    input       [C_AXI_SLAVE_DATA_WIDTH/8-1:0]              s_axi_wstrb,
    input                                                   s_axi_wlast,
    input                                                   s_axi_wvalid,
    output                                                  s_axi_wready,
    
    output                                                  s_axi_arready,
    input                                                   s_axi_arvalid,
    input       [C_AXI_ID_WIDTH-1:0]                        s_axi_arid,
    input       [C_AXI_ADDR_WIDTH-1:0]                      s_axi_araddr,
    input       [7:0]                                       s_axi_arlen,
    input       [2:0]                                       s_axi_arsize,
    input       [1:0]                                       s_axi_arburst,
    input                                                   s_axi_arlock,
    input       [3:0]                                       s_axi_arcache,
    input       [2:0]                                       s_axi_arprot,
    input       [3:0]                                       s_axi_arqos,
    
    // MASTER PORT
    input                                                   m_axi_awready,
    output  reg                                             m_axi_awvalid,
    output  reg [C_AXI_ID_WIDTH-1:0]                        m_axi_awid,
    output  reg [C_AXI_ADDR_WIDTH-1:0]                      m_axi_awaddr,
    output  reg [7:0]                                       m_axi_awlen,
    output  reg [2:0]                                       m_axi_awsize,
    output  reg [1:0]                                       m_axi_awburst,
    output  reg                                             m_axi_awlock,
    output  reg [3:0]                                       m_axi_awcache,
    output  reg [2:0]                                       m_axi_awprot,
    output  reg [3:0]                                       m_axi_awqos,
    
    output  reg [UPSIZE_RATIO*C_AXI_SLAVE_DATA_WIDTH-1:0]   m_axi_wdata,
    output  reg [UPSIZE_RATIO*C_AXI_SLAVE_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output  reg                                             m_axi_wlast,
    output                                                  m_axi_wvalid,
    input                                                   m_axi_wready,
    
    input                                                   m_axi_arready,
    output  reg                                             m_axi_arvalid,
    output  reg [C_AXI_ID_WIDTH-1:0]                        m_axi_arid,
    output  reg [C_AXI_ADDR_WIDTH-1:0]                      m_axi_araddr,
    output  reg [7:0]                                       m_axi_arlen,
    output  reg [2:0]                                       m_axi_arsize,
    output  reg [1:0]                                       m_axi_arburst,
    output  reg                                             m_axi_arlock,
    output  reg [3:0]                                       m_axi_arcache,
    output  reg [2:0]                                       m_axi_arprot,
    output  reg [3:0]                                       m_axi_arqos
    );

generate
// only do the complicated upsizing if we need to
if (UPSIZE_RATIO > 1) begin   
    //////////////////////
    // INTERNAL SIGNALS //
    //////////////////////
    reg                                 aresetn_q;
    reg [UPSIZE_RATIO-1:0]              validData;
    reg [UPSIZE_RATIO-1:0]              writePtr;
    reg [C_AXI_SLAVE_DATA_WIDTH-1:0]    masterData          [0:UPSIZE_RATIO-1];
    reg [C_AXI_SLAVE_DATA_WIDTH/8-1:0]  masterStrobe        [0:UPSIZE_RATIO-1];
    
    wire                                loadSlaveWaddr;
    wire                                sendMasterWaddr;
    
    wire                                loadSlaveData;
    wire                                sendMasterData;
    
    wire                                loadSlaveRaddr;
    wire                                sendMasterRaddr;

    integer                             i;

    // register the reset
    always @ (posedge aclk) begin
        aresetn_q <= aresetn;
    end
    
    ///////////
    // WADDR //
    ///////////
    assign loadSlaveWaddr = s_axi_awvalid & s_axi_awready;
    assign sendMasterWaddr = m_axi_awvalid & m_axi_awready;
    assign s_axi_awready = (~m_axi_awvalid) || sendMasterWaddr;

    // need to buffer the write address and modify the awsize and awlen
    // accordingly
    always @ (posedge aclk) begin
        if (!aresetn_q) begin
            m_axi_awid      <= 0;
            m_axi_awaddr    <= 0;
            m_axi_awlen     <= 0;
            m_axi_awsize    <= 0;
            m_axi_awburst   <= 0;
            m_axi_awlock    <= 0;
            m_axi_awcache   <= 0;
            m_axi_awprot    <= 0;
            m_axi_awqos     <= 0;
            m_axi_awvalid   <= 0;
        end else if (loadSlaveWaddr) begin
            m_axi_awid      <= s_axi_awid;
            m_axi_awaddr    <= s_axi_awaddr;
            m_axi_awlen     <= s_axi_awlen / UPSIZE_RATIO;
            m_axi_awsize    <= s_axi_awsize + LOG_UPSIZE_RATIO;
            m_axi_awburst   <= s_axi_awburst;
            m_axi_awlock    <= s_axi_awlock;
            m_axi_awcache   <= s_axi_awcache;
            m_axi_awprot    <= s_axi_awprot;
            m_axi_awqos     <= s_axi_awqos;
            m_axi_awvalid   <= s_axi_awvalid;
        end else if (sendMasterWaddr) begin
            m_axi_awvalid   <= 0;
        end
    end

    ///////////
    // WDATA //
    ///////////
    // demux incoming data into one of 'UPSIZE_RATIO' registers
    always @ (posedge aclk) begin
        if (!aresetn_q) begin
            validData                   <= 0;
            m_axi_wlast                 <= 0;
            for(i=0; i<UPSIZE_RATIO; i=i+1) begin
                masterData  [i]         <= 0;
                masterStrobe[i]         <= 0;
            end
        end else begin
            // when the master takes the data, all the valid signals should be
            // reset
            if (sendMasterData) begin
                validData               <= 0;
            end
            // when data is loaded into one of the registers, its valid signal
            // should also be set
            if (loadSlaveData) begin
                masterData  [writePtr]  <= s_axi_wdata;
                masterStrobe[writePtr]  <= s_axi_wstrb;
                validData   [writePtr]  <= 1'b1;
                m_axi_wlast             <= s_axi_wlast;
            end
        end
    end
    
    // only load data into a register from the slave port if the register is
    // currently free or will be free due to the master taking the current
    // data
    assign s_axi_wready = (~validData[writePtr]) | sendMasterData;

    // round-robin controller: rotate through the registers 
    always @ (posedge aclk) begin
        if (!aresetn_q) begin
            writePtr <= 0;
        end 
        // increment the write pointer when new data is written into one of
        // the registers
        else if (loadSlaveData) begin
            if (writePtr < (UPSIZE_RATIO-1)) begin
                writePtr <= writePtr + 1;
            end else begin
                writePtr <= 0;
            end
        end
    end

    // signals to describe when the master port is sending data and when the
    // slave port is receiving data
    assign sendMasterData = m_axi_wvalid & m_axi_wready;
    assign loadSlaveData = s_axi_wvalid & s_axi_wready;
    
    // data should be outputted in little-endian notation
    // i.e. first transmission should be in LS location of output data
    always @ (*) begin
        m_axi_wdata = 0;
        m_axi_wstrb = 0;
        for (i=UPSIZE_RATIO-1; i>=0; i=i-1) begin
            m_axi_wdata = (m_axi_wdata << C_AXI_SLAVE_DATA_WIDTH) | masterData[i];
            m_axi_wstrb = (m_axi_wstrb << C_AXI_SLAVE_DATA_WIDTH/8) | masterStrobe[i];
        end
    end
    
    // all registers must be valid before output data can be valid
    assign m_axi_wvalid = &validData;
    
    ///////////
    // RADDR //
    ///////////
    assign loadSlaveRaddr = s_axi_arvalid & s_axi_arready;
    assign sendMasterRaddr = m_axi_arvalid & m_axi_arready;
    assign s_axi_arready = (~m_axi_arvalid) || sendMasterRaddr;

    // need to buffer the read address and modify the arsize and arlen
    // accordingly
    always @ (posedge aclk) begin
        if (!aresetn_q) begin
            m_axi_arid      <= 0;
            m_axi_araddr    <= 0;
            m_axi_arlen     <= 0;
            m_axi_arsize    <= 0;
            m_axi_arburst   <= 0;
            m_axi_arlock    <= 0;
            m_axi_arcache   <= 0;
            m_axi_arprot    <= 0;
            m_axi_arqos     <= 0;
            m_axi_arvalid   <= 0;
        end else if (loadSlaveRaddr) begin
            m_axi_arid      <= s_axi_arid;
            m_axi_araddr    <= s_axi_araddr;
            m_axi_arlen     <= s_axi_arlen / UPSIZE_RATIO;
            m_axi_arsize    <= s_axi_arsize + LOG_UPSIZE_RATIO;
            m_axi_arburst   <= s_axi_arburst;
            m_axi_arlock    <= s_axi_arlock;
            m_axi_arcache   <= s_axi_arcache;
            m_axi_arprot    <= s_axi_arprot;
            m_axi_arqos     <= s_axi_arqos;
            m_axi_arvalid   <= s_axi_arvalid;
        end else if (sendMasterRaddr) begin
            m_axi_arvalid   <= 0;
        end
    end
end 
// UPSIZE_RATIO == 1
// this becomes a wired connection if we don't need to do any downsizing
else begin
    
    assign s_axi_awready = m_axi_awready;
    assign s_axi_wready = m_axi_wready;
    assign s_axi_arready = m_axi_arready;
    assign m_axi_wvalid = s_axi_wvalid;

    always @ (*) begin
        m_axi_awvalid = s_axi_awvalid;
        m_axi_awid = s_axi_awid;
        m_axi_awaddr = s_axi_awaddr;
        m_axi_awlen = s_axi_awlen;
        m_axi_awsize = s_axi_awsize;
        m_axi_awburst = s_axi_awburst;
        m_axi_awlock = s_axi_awlock;
        m_axi_awcache = s_axi_awcache;
        m_axi_awprot = s_axi_awprot;
        m_axi_awqos = s_axi_awqos;
        
        m_axi_wdata = s_axi_wdata;
        m_axi_wstrb = s_axi_wstrb;
        m_axi_wlast = s_axi_wlast;
        
        m_axi_arvalid = s_axi_arvalid;
        m_axi_arid = s_axi_arid;
        m_axi_araddr = s_axi_araddr;
        m_axi_arlen = s_axi_arlen;
        m_axi_arsize = s_axi_arsize;
        m_axi_arburst = s_axi_arburst;
        m_axi_arlock = s_axi_arlock;
        m_axi_arcache = s_axi_arcache;
        m_axi_arprot = s_axi_arprot;
        m_axi_arqos = s_axi_arqos;
    end
end
endgenerate
endmodule

