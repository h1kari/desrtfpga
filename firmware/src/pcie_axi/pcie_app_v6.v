//-----------------------------------------------------------------------------
//
// (c) Copyright 2009-2010 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Virtex-6 Integrated Block for PCI Express
// File       : pcie_app_v6.v
// Version    : 2.1
//--
//-- Description:  PCI Express Endpoint sample application
//--               design.
//--
//------------------------------------------------------------------------------
`include "PicoDefines.v"
`timescale 1ns / 1ps

`define PCI_EXP_EP_OUI                           24'h000A35
`define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2                         32'h00000001

module  pcie_app_v6#(
  parameter C_DATA_WIDTH = 128,            // RX/TX interface data width

  // Do not override parameters below this line
  parameter STRB_WIDTH = C_DATA_WIDTH / 8               // TSTRB width
)(
    
    // stream signals we're taking to the toplevel for the user
    output                      s_clk,
    output                      s_rst,
    
    output                      s_out_en,
    output         [8:0]        s_out_id,
    input     [127:0]           s_out_data,
    
    output                      s_in_valid,
    output [8:0]                s_in_id,
    output [127:0]              s_in_data,
    
    output       [8:0]          s_poll_id,
    input      [31:0]           s_poll_seq,
    input      [127:0]          s_poll_next_desc,
    input                       s_poll_next_desc_valid,
    
    output          [8:0]       s_next_desc_rd_id,
    output                      s_next_desc_rd_en,
  
    // user-direct writes
    input [127:0]               user_pci_wr_q_data,
    input                       user_pci_wr_q_valid,
    output                      user_pci_wr_q_en,

    input [127:0]               user_pci_wr_data_q_data,
    input                       user_pci_wr_data_q_valid,
    output                      user_pci_wr_data_q_en,
    
    output                      direct_rx_valid,
     
    input  [7:0]                UserPBWidth,

    input                         user_clk,
    input                         user_reset,
    input                         user_lnk_up,

    // Tx
    input  [5:0]                  tx_buf_av,
    input                         tx_cfg_req,
    input                         tx_err_drop,
    output                        tx_cfg_gnt,

    input                         s_axis_tx_tready,
    output  [C_DATA_WIDTH-1:0]    s_axis_tx_tdata,
    output  [STRB_WIDTH-1:0]      s_axis_tx_tstrb,
    output  [3:0]                 s_axis_tx_tuser,
    output                        s_axis_tx_tlast,
    output                        s_axis_tx_tvalid,

    // Rx
    output                        rx_np_ok,
    input  [C_DATA_WIDTH-1:0]     m_axis_rx_tdata,
    input  [STRB_WIDTH-1:0]       m_axis_rx_tstrb,
    input                         m_axis_rx_tlast,
    input                         m_axis_rx_tvalid,
    output                        m_axis_rx_tready,
    input  [21:0]                 m_axis_rx_tuser,

    // Flow Control
    input  [11:0]                 fc_cpld,
    input  [7:0]                  fc_cplh,
    input  [11:0]                 fc_npd,
    input  [7:0]                  fc_nph,
    input  [11:0]                 fc_pd,
    input  [7:0]                  fc_ph,
    output [2:0]                  fc_sel,

    // CFG
    input  [31:0]                 cfg_do,
    input                         cfg_rd_wr_done,
    output [31:0]                 cfg_di,
    output [3:0]                  cfg_byte_en,
    output [9:0]                  cfg_dwaddr,
    output                        cfg_wr_en,
    output                        cfg_rd_en,

    output                        cfg_err_cor,
    output                        cfg_err_ur,
    output                        cfg_err_ecrc,
    output                        cfg_err_cpl_timeout,
    output                        cfg_err_cpl_abort,
    output                        cfg_err_cpl_unexpect,
    output                        cfg_err_posted,
    output                        cfg_err_locked,
    output [47:0]                 cfg_err_tlp_cpl_header,
    input                         cfg_err_cpl_rdy,
    output                        cfg_interrupt,
    input                         cfg_interrupt_rdy,
    output                        cfg_interrupt_assert,
    output [7:0]                  cfg_interrupt_di,
    input  [7:0]                  cfg_interrupt_do,
    input  [2:0]                  cfg_interrupt_mmenable,
    input                         cfg_interrupt_msienable,
    input                         cfg_interrupt_msixenable,
    input                         cfg_interrupt_msixfm,
    output                        cfg_turnoff_ok,
    input                         cfg_to_turnoff,
    output                        cfg_trn_pending,
    output                        cfg_pm_wake,
    input   [7:0]                 cfg_bus_number,
    input   [4:0]                 cfg_device_number,
    input   [2:0]                 cfg_function_number,
    input  [15:0]                 cfg_status,
    input  [15:0]                 cfg_command,
    input  [15:0]                 cfg_dstatus,
    input  [15:0]                 cfg_dcommand,
    input  [15:0]                 cfg_lstatus,
    input  [15:0]                 cfg_lcommand,
    input  [15:0]                 cfg_dcommand2,
    input   [2:0]                 cfg_pcie_link_state,

    output [1:0]                  pl_directed_link_change,
    input  [5:0]                  pl_ltssm_state,
    output [1:0]                  pl_directed_link_width,
    output                        pl_directed_link_speed,
    output                        pl_directed_link_auton,
    output                        pl_upstream_prefer_deemph,
    input  [1:0]                  pl_sel_link_width,
    input                         pl_sel_link_rate,
    input                         pl_link_gen2_capable,
    input                         pl_link_partner_gen2_supported,
    input  [2:0]                  pl_initial_link_width,
    input                         pl_link_upcfg_capable,
    input  [1:0]                  pl_lane_reversal_mode,
    input                         pl_received_hot_rst,

    output [63:0]                 cfg_dsn,

    // temperature from the system monitor
    output [9:0]                  temp
);


    //
    // Core input tie-offs
    //

    assign fc_sel = 3'b0;

    assign rx_np_ok = 1'b1;
    assign s_axis_tx_tuser[0] = 1'b0; // Unused for V6
    assign s_axis_tx_tuser[1] = 1'b0; // Error forward packet
    assign s_axis_tx_tuser[2] = 1'b1; // Stream packet

    assign tx_cfg_gnt = 1'b1;

    assign cfg_err_cor = 1'b0;
    assign cfg_err_ur = 1'b0;
    assign cfg_err_ecrc = 1'b0;
    assign cfg_err_cpl_timeout = 1'b0;
    assign cfg_err_cpl_abort = 1'b0;
    assign cfg_err_cpl_unexpect = 1'b0;
    assign cfg_err_posted = 1'b0;
    assign cfg_err_locked = 1'b0;
    assign cfg_pm_wake = 1'b0;
    assign cfg_trn_pending = 1'b0;

    assign cfg_interrupt_assert = 1'b0;
    //assign cfg_interrupt = 1'b0;
    assign cfg_dwaddr = 0;
    assign cfg_rd_en = 0;

    assign pl_directed_link_change = 0;
    assign pl_directed_link_width = 0;
    assign pl_directed_link_speed = 0;
    assign pl_directed_link_auton = 0;
    assign pl_upstream_prefer_deemph = 1'b1;

    assign cfg_interrupt_di = 8'b0;

    assign cfg_err_tlp_cpl_header = 47'h0;
    assign cfg_di = 0;
    assign cfg_byte_en = 4'h0;
    assign cfg_wr_en = 0;
    assign cfg_dsn = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};

    wire [15:0] cfg_completer_id      = { cfg_bus_number, cfg_device_number, cfg_function_number };
    wire        cfg_bus_mstr_enable   = cfg_command[2]; //TODO is this a lie? do we care?

    assign cfg_turnoff_ok = cfg_to_turnoff;
    reg pio_reset_n;
    always @(posedge user_clk)
        pio_reset_n <= user_lnk_up && !user_reset;
    
    
    
    /////////////////////////////////
    // System PicoBus
    /////////////////////////////////
    // This is the "system" PicoBus that's used for internal (non-user) stuff.
    
    wire [127:0]    s_out_data_systempb, s_poll_next_desc_systempb;
    wire [31:0]     s_poll_seq_systempb;
    wire            s_poll_next_desc_valid_systempb;
    
    wire [31:0] PicoDataIn, PicoDataOut;
    //wire [31:0] PicoAddr, PicoAddr;
    wire [31:0] PicoAddr;
    wire        PicoClk, PicoRst, PicoRd, PicoWr;
    
    Stream2PicoBus #(.STREAM_ID(126), .W(32)) FrameworkPicoBus (
        .s_clk(s_clk),
        .s_rst(s_rst),
        
        .s_out_en(s_out_en),
        .s_out_id(s_out_id),
        .s_out_data(s_out_data_systempb),

        .s_in_valid(s_in_valid),
        .s_in_id(s_in_id[8:0]),
        .s_in_data(s_in_data[127:0]),

        .s_poll_id(s_poll_id[8:0]),
        .s_poll_seq(s_poll_seq_systempb[31:0]),
        .s_poll_next_desc(s_poll_next_desc_systempb[127:0]),
        .s_poll_next_desc_valid(s_poll_next_desc_valid_systempb),

        .s_next_desc_rd_en(s_next_desc_rd_en),
        .s_next_desc_rd_id(s_next_desc_rd_id[8:0]),
        
        .PicoClk(PicoClk),
        .PicoRst(PicoRst),
        .PicoWr(PicoWr),
        //.PicoAddr(PicoAddr),
        .PicoDataIn(PicoDataIn),
        .PicoRd(PicoRd),
        .PicoAddr(PicoAddr),
        .PicoDataOut(PicoDataOut)
    );

    // System PicoBus modules
        wire [31:0] CardInfoDataOut;
        CardInfo32 CardInfo (
            .PicoClk(PicoClk),
            .PicoRst(PicoRst),
            .PicoAddr(PicoAddr[31:0]),
            .PicoDataIn(PicoDataIn[31:0]),
            .PicoRd(PicoRd),
            .PicoWr(PicoWr),
            .PicoDataOut(CardInfoDataOut[31:0]),
				.UserPBWidth(UserPBWidth));
    
    `ifdef ALTERA_FPGA `undef ENABLE_SYSTEM_MONITOR `endif // SYSTEM MONITOR DOES NOT EXIST ON ALTERA FPGA
    `ifdef SIMULATION `undef ENABLE_SYSTEM_MONITOR `endif       // If simulation don't ever enable sys_mon
        `ifdef ENABLE_SYSTEM_MONITOR
            wire [31:0] SystemMonitorDataOut;
            
            SystemMonitor32 SystemMonitor (
		.s_clk(s_clk),
		.s_rst(s_rst),
                .PicoClk(PicoClk),
                .PicoRst(PicoRst),
                .PicoAddr(PicoAddr[31:0]),
                .PicoDataIn(PicoDataIn[31:0]),
                .PicoRd(PicoRd),
                .PicoWr(PicoWr),
                .PicoDataOut(SystemMonitorDataOut[31:0]),
                .temp(temp));
        `endif //ENABLE_SYSTEM_MONITOR
    



        // user module instantiation used to be here. moved to toplevel.





        wire [31:0] TestCounterDataOut;
        TestCounter32 TestCounter32 (
            .PicoRst(PicoRst),
            .PicoClk(PicoClk),
            .PicoAddr(PicoAddr[31:0]),
            .PicoDataIn(PicoDataIn[31:0]),
            .PicoDataOut(TestCounterDataOut[31:0]),
            .PicoRd(PicoRd),
            .PicoWr(PicoWr)
        );
        assign PicoDataOut[31:0] =
           `ifdef ENABLE_SYSTEM_MONITOR SystemMonitorDataOut[31:0]  | `endif
                                        TestCounterDataOut[31:0]  |
                                        CardInfoDataOut[31:0]       |
                                        32'h0;
    PIO_EP  #(

        .C_DATA_WIDTH( C_DATA_WIDTH ),
        .STRB_WIDTH( STRB_WIDTH )

    ) PIO_EP (

        .clk ( user_clk ),                         // I
        .rst_n ( pio_reset_n ),                     // I

        .s_axis_tx_tready ( s_axis_tx_tready ),         // I
        .s_axis_tx_tdata ( s_axis_tx_tdata ),           // O
        .s_axis_tx_tstrb ( s_axis_tx_tstrb ),           // O
        .s_axis_tx_tlast ( s_axis_tx_tlast ),           // O
        .s_axis_tx_tvalid ( s_axis_tx_tvalid ),         // O
        .tx_src_dsc ( s_axis_tx_tuser[3] ),             // O

        .m_axis_rx_tdata( m_axis_rx_tdata ),            // I
        .m_axis_rx_tstrb( m_axis_rx_tstrb ),            // I
        .m_axis_rx_tlast( m_axis_rx_tlast ),            // I
        .m_axis_rx_tvalid( m_axis_rx_tvalid ),          // I
        .m_axis_rx_tready( m_axis_rx_tready ),          // O
        .m_axis_rx_tuser ( m_axis_rx_tuser ),           // I
        
        .cfg_interrupt ( cfg_interrupt ), // O
        .cfg_interrupt_rdy ( cfg_interrupt_rdy ), // I

        .cfg_completer_id ( cfg_completer_id ),         // I [15:0]
        .cfg_bus_mstr_enable (cfg_bus_mstr_enable ),     // I
        .cfg_dcommand ( cfg_dcommand ),                 // I [15:0]
  
        // user-direct writes
        .user_pci_wr_q_data(user_pci_wr_q_data),
        .user_pci_wr_q_valid(user_pci_wr_q_valid),
        .user_pci_wr_q_en(user_pci_wr_q_en),

        .user_pci_wr_data_q_data(user_pci_wr_data_q_data),
        .user_pci_wr_data_q_valid(user_pci_wr_data_q_valid),
        .user_pci_wr_data_q_en(user_pci_wr_data_q_en),
        .direct_rx_valid(direct_rx_valid),
        
        // stream signals we're taking to the toplevel for the user
        .s_clk(s_clk),
        .s_rst(s_rst),

        .s_out_en(s_out_en),
        .s_out_id(s_out_id),
        .s_out_data(s_out_data | s_out_data_systempb),

        .s_in_valid(s_in_valid),
        .s_in_id(s_in_id[8:0]),
        .s_in_data(s_in_data[127:0]),

        .s_poll_id(s_poll_id[8:0]),
        .s_poll_seq(s_poll_seq[31:0] | s_poll_seq_systempb[31:0]),
        .s_poll_next_desc(s_poll_next_desc[127:0] | s_poll_next_desc_systempb[127:0]),
        .s_poll_next_desc_valid(s_poll_next_desc_valid | s_poll_next_desc_valid_systempb),

        .s_next_desc_rd_en(s_next_desc_rd_en),
        .s_next_desc_rd_id(s_next_desc_rd_id[8:0])
    );

endmodule // pcie_app

