// Copyright 2009-2016 Micron Technology, Inc. All Rights Reserved.  This
// software contains confidential information and trade secrets of Micron
// Technology, Inc. Use, disclosure, or reproduction is prohibited without the
// prior express written permission of Micron Technology, Inc.

`include "PicoDefines.v"

// *********************************************************
// M510 PicoFramework.v 
// *********************************************************

module PicoFrameworkM510_KU060
# (
  parameter PCIE_EXT_CLK      = "TRUE",  // Use External Clocking Module
  parameter C_DATA_WIDTH = 128,            // RX/TX interface data width
  // Do not override parameters below this line
  parameter STRB_WIDTH = C_DATA_WIDTH / 8,               // TSTRB width
  parameter KEEP_WIDTH        = C_DATA_WIDTH / 8 // TSTRB width
)
(
    
    // stream signals we're taking to the toplevel for the user
    output                      s_clk,
    output                      s_rst,
    
    output                      s_out_en,
    output [8:0]                s_out_id,
    input  [127:0]              s_out_data,
    
    output                      s_in_valid,
    output [8:0]                s_in_id,
    output [127:0]              s_in_data,
    
    output [8:0]                s_poll_id,
    input  [31:0]               s_poll_seq,
    input  [127:0]              s_poll_next_desc,
    input                       s_poll_next_desc_valid,
    
    output [8:0]                s_next_desc_rd_id,
    output                      s_next_desc_rd_en,

    input  [7:0]                UserPBWidth,
  
    // user-direct writes
    input  [127:0]              user_pci_wr_q_data,
    input                       user_pci_wr_q_valid,
    output                      user_pci_wr_q_en,

    input  [127:0]              user_pci_wr_data_q_data,
    input                       user_pci_wr_data_q_valid,
    output                      user_pci_wr_data_q_en,
    
    output                      direct_rx_valid,
    

    output  [7:0]    pci_exp_txp,
    output  [7:0]    pci_exp_txn,
    input   [7:0]    pci_exp_rxp,
    input   [7:0]    pci_exp_rxn,
    
    input  extra_clk_p,
    input  extra_clk_n,
    output extra_clk,

    input                                        sys_clk_p,
    input                                        sys_clk_n,
    input                                        sys_reset_n,

    // temperature output from the System Monitor
    output  [9:0]                   temp
);

  localparam        PL_FAST_TRAIN	        = "FALSE";

  wire                                        user_clk;
  wire                                        user_half_clk;
  wire                                        user_reset;
  wire                                        user_lnk_up;

  // Tx
  wire [5:0]                                  tx_buf_av;
  wire                                        tx_cfg_req;
  wire                                        tx_err_drop;
  wire                                        tx_cfg_gnt;
  wire                                        s_axis_tx_tready;
  wire [3:0]                                  s_axis_tx_tuser;
  wire [C_DATA_WIDTH-1:0]                     s_axis_tx_tdata;
  wire [STRB_WIDTH-1:0]                       s_axis_tx_tstrb;
  wire                                        s_axis_tx_tlast;
  wire                                        s_axis_tx_tvalid;


  // Rx
  wire [C_DATA_WIDTH-1:0]                     m_axis_rx_tdata;
  wire [STRB_WIDTH-1:0]                       m_axis_rx_tstrb;
  wire                                        m_axis_rx_tlast;
  wire                                        m_axis_rx_tvalid;
  wire                                        m_axis_rx_tready;
  wire  [21:0]                                m_axis_rx_tuser;
  wire                                        rx_np_ok;

  // Flow Control
  wire [11:0]                                 fc_cpld;
  wire [7:0]                                  fc_cplh;
  wire [11:0]                                 fc_npd;
  wire [7:0]                                  fc_nph;
  wire [11:0]                                 fc_pd;
  wire [7:0]                                  fc_ph;
  wire [2:0]                                  fc_sel;
  

  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------

  wire [31:0]                                 cfg_do;
  wire                                        cfg_rd_wr_done;
  wire  [31:0]                                cfg_di;
  wire   [3:0]                                cfg_byte_en;
  wire   [9:0]                                cfg_dwaddr;
  wire                                        cfg_wr_en;
  wire                                        cfg_rd_en;

  wire                                        cfg_err_cor;
  wire                                        cfg_err_ur;
  wire                                        cfg_err_ecrc;
  wire                                        cfg_err_cpl_timeout;
  wire                                        cfg_err_cpl_abort;
  wire                                        cfg_err_cpl_unexpect;
  wire                                        cfg_err_posted;
  wire                                        cfg_err_locked;
  wire [47:0]                                 cfg_err_tlp_cpl_header;
  wire                                        cfg_err_cpl_rdy;
  wire                                        cfg_interrupt;
  wire                                        cfg_interrupt_rdy;
  wire                                        cfg_interrupt_assert;
  wire [7:0]                                  cfg_interrupt_di;
  wire [7:0]                                  cfg_interrupt_do;
  wire [2:0]                                  cfg_interrupt_mmenable;
  wire                                        cfg_interrupt_msienable;
  wire                                        cfg_interrupt_msixenable;
  wire                                        cfg_interrupt_msixfm;
  wire                                        cfg_turnoff_ok;
  wire                                        cfg_to_turnoff;
  wire                                        cfg_trn_pending;
  wire                                        cfg_pm_wake;
  wire  [7:0]                                 cfg_bus_number;
  wire  [4:0]                                 cfg_device_number;
  wire  [2:0]                                 cfg_function_number;
  wire [15:0]                                 cfg_status;
  wire [15:0]                                 cfg_command;
  wire [15:0]                                 cfg_dstatus;
  wire [15:0]                                 cfg_dcommand;
  wire [15:0]                                 cfg_lstatus;
  wire [15:0]                                 cfg_lcommand;
  wire [15:0]                                 cfg_dcommand2;
  wire  [2:0]                                 cfg_pcie_link_state;
  wire [63:0]                                 cfg_dsn;

  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  wire [2:0]                                  pl_initial_link_width;
  wire [1:0]                                  pl_lane_reversal_mode;
  wire                                        pl_link_gen2_capable;
  wire                                        pl_link_partner_gen2_supported;
  wire                                        pl_link_upcfg_capable;
  wire [5:0]                                  pl_ltssm_state;
  wire                                        pl_received_hot_rst;
  wire                                        pl_sel_link_rate;
  wire [1:0]                                  pl_sel_link_width;
  wire                                        pl_directed_link_auton;
  wire [1:0]                                  pl_directed_link_change;
  wire                                        pl_directed_link_speed;
  wire [1:0]                                  pl_directed_link_width;
  wire                                        pl_upstream_prefer_deemph;
  
  wire sys_clk_c;

  reg user_reset_q;
  reg user_reset_q_n;
  reg user_lnk_up_q;
  always @(posedge user_clk) begin
    user_reset_q <= user_reset;
    user_lnk_up_q <= user_lnk_up;
  end
  
  wire flash_wp; // tied in hardware on the E18

(* TIG = "TRUE" *) wire sys_reset_n_c_vio;
(* TIG = "TRUE" *) wire sys_reset_n_c_por;

IBUFGDS extra_clk_ibuf (.I(extra_clk_p), .IB(extra_clk_n), .O(extra_clk));
reg [3:0] extra_cnt; always @(posedge extra_clk) extra_cnt <= extra_cnt + 1;




    // in simulation, we drive the PCIe core signals from the testbench, rather
    // than driving the real PCIe pins and simulation the whole hard core.

    xilinx_pcie_3_0_7vx #(
        // Leave the M510 with a X8 PCIe
        //`ifdef PICO_MODEL_M510
        //    `ifdef PICO_FPGA_KU060
        //        .PL_LINK_CAP_MAX_LINK_WIDTH     (4),
        //    `endif //PICO_FPGA_KU060
        //`endif //PICO_MODEL_M510
        .C_DATA_WIDTH (C_DATA_WIDTH)
    ) core (
        .user_clk                       ( user_clk              ),
        .user_reset                     ( user_reset            ),
        .user_lnk_up                    ( user_lnk_up           ),

        // Tx
        .pci_exp_txp                    ( pci_exp_txp ),
        .pci_exp_txn                    ( pci_exp_txn ),

        // Rx
        .pci_exp_rxp                    ( pci_exp_rxp ),
        .pci_exp_rxn                    ( pci_exp_rxn ),

        // Tx
        .s_axis_tx_tready               ( s_axis_tx_tready      ),
        .s_axis_tx_tdata                ( s_axis_tx_tdata       ),
        .s_axis_tx_tstrb                ( s_axis_tx_tstrb       ),
        .s_axis_tx_tuser                ( s_axis_tx_tuser       ),
        .s_axis_tx_tlast                ( s_axis_tx_tlast       ),
        .s_axis_tx_tvalid               ( s_axis_tx_tvalid      ),
    
        // Rx
        .m_axis_rx_tdata                ( m_axis_rx_tdata       ),
        .m_axis_rx_tstrb                ( m_axis_rx_tstrb       ),
        .m_axis_rx_tlast                ( m_axis_rx_tlast       ),
        .m_axis_rx_tvalid               ( m_axis_rx_tvalid      ),
        .m_axis_rx_tready               ( m_axis_rx_tready      ),
        .m_axis_rx_tuser                ( m_axis_rx_tuser       ),

        .cfg_interrupt                  ( cfg_interrupt         ),
        .cfg_interrupt_rdy              ( cfg_interrupt_rdy     ),

        .cfg_dsn                        ( cfg_dsn               ),
        .cfg_bus_number                 ( cfg_bus_number        ),
        .cfg_device_number              ( cfg_device_number     ),
        .cfg_function_number            ( cfg_function_number   ),
        .cfg_dcommand                   ( cfg_dcommand          ),

        .sys_clk_p                      ( sys_clk_p             ),
        .sys_clk_n                      ( sys_clk_n             ),
        .sys_reset_n                    ( sys_reset_n           )
    ); 



    pcie_app_v6  #(
        .C_DATA_WIDTH( C_DATA_WIDTH ),
        .STRB_WIDTH( STRB_WIDTH )
    
        )app (
    
        //-------------------------------------------------------
        // 1. AXI-S Interface
        //-------------------------------------------------------
    
        // Common
        .user_clk( user_clk ),
    
        .user_reset( user_reset_q),
        .user_lnk_up( user_lnk_up ),
    
        // Tx
        .tx_buf_av( tx_buf_av ),
        .tx_cfg_req( tx_cfg_req ),
        .tx_err_drop( tx_err_drop ),
        .s_axis_tx_tready( s_axis_tx_tready ),
        .s_axis_tx_tdata( s_axis_tx_tdata ),
        .s_axis_tx_tstrb( s_axis_tx_tstrb ),
        .s_axis_tx_tuser( s_axis_tx_tuser ),
        .s_axis_tx_tlast( s_axis_tx_tlast ),
        .s_axis_tx_tvalid( s_axis_tx_tvalid ),
        .tx_cfg_gnt( tx_cfg_gnt ),
      
        // Rx
        .m_axis_rx_tdata( m_axis_rx_tdata ),
        .m_axis_rx_tstrb( m_axis_rx_tstrb ),
        .m_axis_rx_tlast( m_axis_rx_tlast ),
        .m_axis_rx_tvalid( m_axis_rx_tvalid ),
        .m_axis_rx_tready( m_axis_rx_tready ),
        .m_axis_rx_tuser ( m_axis_rx_tuser ),
        .rx_np_ok( rx_np_ok ),
      
        // Flow Control
        .fc_cpld( fc_cpld ),
        .fc_cplh( fc_cplh ),
        .fc_npd( fc_npd ),
        .fc_nph( fc_nph ),
        .fc_pd( fc_pd ),
        .fc_ph( fc_ph ),
        .fc_sel( fc_sel ),
            
        // stream signals we're taking to the toplevel for the user
        .s_clk(s_clk),
        .s_rst(s_rst),
    
        .s_out_en(s_out_en),
        .s_out_id(s_out_id[8:0]),
        .s_out_data(s_out_data[127:0]),
    
        .s_in_valid(s_in_valid),
        .s_in_id(s_in_id[8:0]),
        .s_in_data(s_in_data[127:0]),
    
        .s_poll_id(s_poll_id[8:0]),
        .s_poll_seq(s_poll_seq[31:0]),
        .s_poll_next_desc(s_poll_next_desc[127:0]),
        .s_poll_next_desc_valid(s_poll_next_desc_valid),
    
        .s_next_desc_rd_en(s_next_desc_rd_en),
        .s_next_desc_rd_id(s_next_desc_rd_id[8:0]),
    
        .UserPBWidth(UserPBWidth),
      
        // user-direct writes
        .user_pci_wr_q_data(user_pci_wr_q_data),
        .user_pci_wr_q_valid(user_pci_wr_q_valid),
        .user_pci_wr_q_en(user_pci_wr_q_en),
    
        .user_pci_wr_data_q_data(user_pci_wr_data_q_data),
        .user_pci_wr_data_q_valid(user_pci_wr_data_q_valid),
        .user_pci_wr_data_q_en(user_pci_wr_data_q_en),
        .direct_rx_valid(direct_rx_valid),
    
        // temperature status
        .temp(temp),

        //-------------------------------------------------------
        // 2. Configuration (CFG) Interface
        //-------------------------------------------------------
      
        .cfg_do( cfg_do ),
        .cfg_rd_wr_done( cfg_rd_wr_done),
        .cfg_di( cfg_di ),
        .cfg_byte_en( cfg_byte_en ),
        .cfg_dwaddr( cfg_dwaddr ),
        .cfg_wr_en( cfg_wr_en ),
        .cfg_rd_en( cfg_rd_en ),
      
        .cfg_err_cor( cfg_err_cor ),
        .cfg_err_ur( cfg_err_ur ),
        .cfg_err_ecrc( cfg_err_ecrc ),
        .cfg_err_cpl_timeout( cfg_err_cpl_timeout ),
        .cfg_err_cpl_abort( cfg_err_cpl_abort ),
        .cfg_err_cpl_unexpect( cfg_err_cpl_unexpect ),
        .cfg_err_posted( cfg_err_posted ),
        .cfg_err_locked( cfg_err_locked ),
        .cfg_err_tlp_cpl_header( cfg_err_tlp_cpl_header ),
        .cfg_err_cpl_rdy( cfg_err_cpl_rdy ),
        .cfg_interrupt( cfg_interrupt ),
        .cfg_interrupt_rdy( cfg_interrupt_rdy ),
        .cfg_interrupt_assert( cfg_interrupt_assert ),
        .cfg_interrupt_di( cfg_interrupt_di ),
        .cfg_interrupt_do( cfg_interrupt_do ),
        .cfg_interrupt_mmenable( cfg_interrupt_mmenable ),
        .cfg_interrupt_msienable( cfg_interrupt_msienable ),
        .cfg_interrupt_msixenable( cfg_interrupt_msixenable ),
        .cfg_interrupt_msixfm( cfg_interrupt_msixfm ),
        .cfg_turnoff_ok( cfg_turnoff_ok ),
        .cfg_to_turnoff( cfg_to_turnoff ),
        .cfg_trn_pending( cfg_trn_pending ),
        .cfg_pm_wake( cfg_pm_wake ),
        .cfg_bus_number( cfg_bus_number ),
        .cfg_device_number( cfg_device_number ),
        .cfg_function_number( cfg_function_number ),
        .cfg_status( cfg_status ),
        .cfg_command( cfg_command ),
        .cfg_dstatus( cfg_dstatus ),
        .cfg_dcommand( cfg_dcommand ),
        .cfg_lstatus( cfg_lstatus ),
        .cfg_lcommand( cfg_lcommand ),
        .cfg_dcommand2( cfg_dcommand2 ),
        .cfg_pcie_link_state( cfg_pcie_link_state ),
        .cfg_dsn( cfg_dsn ),
      
        //-------------------------------------------------------
        // 3. Physical Layer Control and Status (PL) Interface
        //-------------------------------------------------------
      
        .pl_initial_link_width( pl_initial_link_width ),
        .pl_lane_reversal_mode( pl_lane_reversal_mode ),
        .pl_link_gen2_capable( pl_link_gen2_capable ),
        .pl_link_partner_gen2_supported( pl_link_partner_gen2_supported ),
        .pl_link_upcfg_capable( pl_link_upcfg_capable ),
        .pl_ltssm_state( pl_ltssm_state ),
        .pl_received_hot_rst( pl_received_hot_rst ),
        .pl_sel_link_rate( pl_sel_link_rate ),
        .pl_sel_link_width( pl_sel_link_width ),
        .pl_directed_link_auton( pl_directed_link_auton ),
        .pl_directed_link_change( pl_directed_link_change ),
        .pl_directed_link_speed( pl_directed_link_speed ),
        .pl_directed_link_width( pl_directed_link_width ),
        .pl_upstream_prefer_deemph( pl_upstream_prefer_deemph )
      
    );

endmodule

