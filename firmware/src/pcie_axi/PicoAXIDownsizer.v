/*
* File Name : PicoAXIDownsizer.v
*
* Description :  Converts large AXI data to smaller AXI data by registering
*                the incoming data and muxing small blocks of the data onto
*                the output port.
*
* Creation Date : Wed 31 Aug 2011 01:50:04 PM PDT
*
* Author : Corey Olson
*
* Last Modified : Fri 16 Sep 2011 05:16:25 PM PDT
*
* Copyright 2011 Pico Computing, Inc.
*/
module PicoAXIDownsizer #(
    parameter C_AXI_ID_WIDTH                = 8,    // width of the id throughout this module
    parameter C_AXI_SLAVE_DATA_WIDTH        = 128,  // width of the slave port data width
    parameter UPSIZE_RATIO                  = 2     // C_AXI_MASTER_DATA_WIDTH = C_AXI_SLAVE_DATA_WIDTH * UPSIZE_RATIO
)
(    
    // COMMON SIGNALS
    input                                                   aclk,
    input                                                   aresetn,
    
    // SLAVE PORT
    output  reg [C_AXI_ID_WIDTH-1:0]                        s_axi_rid,
    output      [C_AXI_SLAVE_DATA_WIDTH-1:0]                s_axi_rdata,
    output  reg [1:0]                                       s_axi_rresp,
    output                                                  s_axi_rlast,
    output                                                  s_axi_rvalid,
    input                                                   s_axi_rready,
    
    // MASTER PORT
    input       [C_AXI_ID_WIDTH-1:0]                        m_axi_rid,
    input       [UPSIZE_RATIO*C_AXI_SLAVE_DATA_WIDTH-1:0]   m_axi_rdata,
    input       [1:0]                                       m_axi_rresp,
    input                                                   m_axi_rlast,
    input                                                   m_axi_rvalid,
    output                                                  m_axi_rready
);

generate
if (UPSIZE_RATIO > 1) begin
    // LOCAL SIGNALS
    reg         [UPSIZE_RATIO-1:0]                          readPtr;
    reg         [UPSIZE_RATIO*C_AXI_SLAVE_DATA_WIDTH-1:0]   m_axi_rdata_q;
    reg                                                     m_axi_rlast_q;
    reg         [UPSIZE_RATIO-1:0]                          validData;
    
    wire                                                    loadMasterData;
    wire                                                    sendSlaveData;

    integer                                                 i;

    // register incoming data
    always @ (posedge aclk) begin
        if (!aresetn) begin
            s_axi_rid       <= 0;
            s_axi_rresp     <= 0;
            m_axi_rdata_q   <= 0;
            m_axi_rlast_q   <= 0;
            validData       <= 0;
        end else begin
            // mark data as sent once the transaction completes
            if (sendSlaveData) begin
                validData[readPtr] <= 1'b0;
            end
            // all data chunks are valid if you are loading new data from the
            // master port
            if (loadMasterData) begin
                s_axi_rid       <= m_axi_rid;
                s_axi_rresp     <= m_axi_rresp;
                m_axi_rdata_q   <= m_axi_rdata;
                m_axi_rlast_q   <= m_axi_rlast;
                validData       <= {UPSIZE_RATIO{1'b1}};
            end
        end
    end

    // track which portion of the registered data should be muxed onto the
    // slave port
    always @ (posedge aclk) begin
        if (!aresetn) begin
            readPtr <= 0;
        end
        // reset the read pointer to the LS 128-bit entry when new data is
        // loaded from the master port
        else if (loadMasterData) begin
            readPtr <= 0;
        end
        // increment the read pointer to select which register should be muxed
        // to the output
        else if (sendSlaveData) begin
            readPtr <= readPtr + 1;
        end
    end

    // only assert the rlast signal for the very last transmission
    assign s_axi_rlast = m_axi_rlast_q & (readPtr == (UPSIZE_RATIO-1));

    // mux the registered data onto the slave port
    assign s_axi_rdata = m_axi_rdata_q >> (readPtr * C_AXI_SLAVE_DATA_WIDTH);

    // data is ready to be transmitted if it hasn't been marked as having
    // already been processed
    assign s_axi_rvalid = (validData != 0);

    // can accept new data from the master port if all of the current data has
    // been processed or is about to be processed
    assign m_axi_rready = (validData == 0);

    // data transfers happen when ready and valid are asserted
    assign loadMasterData = m_axi_rvalid & m_axi_rready;
    assign sendSlaveData = s_axi_rvalid & s_axi_rready;
end 
// UPSIZE_RATIO == 1
// this becomes a wired connection if we don't need to do any downsizing
else begin
    assign s_axi_rlast = m_axi_rlast;
    assign s_axi_rdata = m_axi_rdata;
    assign s_axi_rvalid = m_axi_rvalid;
    always @ (*) begin
        s_axi_rid = m_axi_rid;
        s_axi_rresp = m_axi_rresp;
    end
    assign m_axi_rready = s_axi_rready;
end
endgenerate
endmodule
