// xilinx_pcie_3_0_7vx.v
// Copyright 2014 Pico Computing, Inc.

module xilinx_pcie_3_0_7vx # (
    parameter          PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
    parameter          PCIE_EXT_CLK                        = "TRUE", // Use External Clocking Module
    parameter          PCIE_EXT_GT_COMMON                  = "FALSE", // Use External GT COMMON Module
    parameter          C_DATA_WIDTH                        = 128,         // RX/TX interface data width
    parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,
    parameter          STRB_WIDTH                          = C_DATA_WIDTH / 8,
    parameter          PL_LINK_CAP_MAX_LINK_SPEED          = 2,  // 1- GEN1, 2 - GEN2, 4 - GEN3
    parameter          PL_LINK_CAP_MAX_LINK_WIDTH          = 8,  // 1- X1, 2 - X2, 4 - X4, 8 - X8
    // USER_CLK2_FREQ = AXI Interface Frequency
    //   0: Disable User Clock
    //   1: 31.25 MHz
    //   2: 62.50 MHz  (default)
    //   3: 125.00 MHz
    //   4: 250.00 MHz
    //   5: 500.00 MHz
    parameter  integer USER_CLK2_FREQ                 = 4,
    parameter          REF_CLK_FREQ                   = 0,           // 0 - 100 MHz, 1 - 125 MHz,  2 - 250 MHz
    parameter          AXISTEN_IF_RQ_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_CQ_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_RC_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_ENABLE_CLIENT_TAG   = 0,
    parameter          AXISTEN_IF_RQ_PARITY_CHECK     = 0,
    parameter          AXISTEN_IF_CC_PARITY_CHECK     = 0,
    parameter          AXISTEN_IF_MC_RX_STRADDLE      = 0,
    parameter          AXISTEN_IF_ENABLE_RX_MSG_INTFC = 0,
    parameter   [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE    = 18'h2FFFF
) (
    output wire                                         user_clk,
    output wire                                         user_reset,
    output wire                                         user_lnk_up,

    output wire                                         s_axis_tx_tready,
    input  wire [C_DATA_WIDTH-1:0]                      s_axis_tx_tdata,
    input  wire [STRB_WIDTH-1:0]                        s_axis_tx_tstrb,
    input  wire [3:0]                                   s_axis_tx_tuser,
    input  wire                                         s_axis_tx_tlast,
    input  wire                                         s_axis_tx_tvalid,
 
    output wire [C_DATA_WIDTH-1:0]                      m_axis_rx_tdata,
    output wire [STRB_WIDTH-1:0]                        m_axis_rx_tstrb,
    output wire                                         m_axis_rx_tlast,
    output wire                                         m_axis_rx_tvalid,
    input  wire                                         m_axis_rx_tready,
    output wire [21:0]                                  m_axis_rx_tuser,

    input  wire                                         cfg_interrupt,
    output wire                                         cfg_interrupt_rdy,

    input  wire [63:0]                                  cfg_dsn,
    output wire [15:0]                                  cfg_completer_id,
    output wire [7:0]                                   cfg_bus_number,
    output wire [4:0]                                   cfg_device_number,
    output wire [2:0]                                   cfg_function_number,
    output wire [15:0]                                  cfg_dcommand,

    output wire [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txp,
    output wire [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txn,
    input  wire [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
    input  wire [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,

    input  wire                                         sys_clk_p,
    input  wire                                         sys_clk_n,
    input  wire                                         sys_reset_n
);

    // Local Parameters derived from user selection
    localparam integer USER_CLK_FREQ         = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
    localparam        TCQ = 1;
    
    // Assign Statements
    assign cfg_bus_number[7:0]          = cfg_ds_bus_number[7:0];
    assign cfg_device_number[4:0]       = cfg_ds_device_number[4:0];
    assign cfg_function_number[2:0]     = cfg_ds_function_number[2:0];
 
    // Wire Declarations
 
    //----------------------------------------------------------------------------------------------------------------//
    //  AXI Interface                                                                                                 //
    //----------------------------------------------------------------------------------------------------------------//
 
     wire                                       s_axis_rq_tlast;
     wire                 [C_DATA_WIDTH-1:0]    s_axis_rq_tdata;
     wire                             [59:0]    s_axis_rq_tuser;
     wire                   [KEEP_WIDTH-1:0]    s_axis_rq_tkeep;
     wire                              [3:0]    s_axis_rq_tready;
     wire                                       s_axis_rq_tvalid;

     wire                 [C_DATA_WIDTH-1:0]    m_axis_rc_tdata;
     wire                             [74:0]    m_axis_rc_tuser;
     wire                                       m_axis_rc_tlast;
     wire                   [KEEP_WIDTH-1:0]    m_axis_rc_tkeep;
     wire                                       m_axis_rc_tvalid;
     wire                             [21:0]    m_axis_rc_tready;

     wire                 [C_DATA_WIDTH-1:0]    m_axis_cq_tdata;
     wire                             [84:0]    m_axis_cq_tuser;
     wire                                       m_axis_cq_tlast;
     wire                   [KEEP_WIDTH-1:0]    m_axis_cq_tkeep;
     wire                                       m_axis_cq_tvalid;
     wire                             [21:0]    m_axis_cq_tready;

     wire                 [C_DATA_WIDTH-1:0]    s_axis_cc_tdata;
     wire                             [32:0]    s_axis_cc_tuser;
     wire                                       s_axis_cc_tlast;
     wire                   [KEEP_WIDTH-1:0]    s_axis_cc_tkeep;
     wire                                       s_axis_cc_tvalid;
     wire                              [3:0]    s_axis_cc_tready;
 
 
    //----------------------------------------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                                                 //
    //----------------------------------------------------------------------------------------------------------------//
 
 
    wire                              [1:0]    pcie_tfc_nph_av;
    wire                              [1:0]    pcie_tfc_npd_av;
 
    wire                              [3:0]    pcie_rq_seq_num;
    wire                                       pcie_rq_seq_num_vld;
    wire                              [5:0]    pcie_rq_tag;
    wire                                       pcie_rq_tag_vld;
    wire                                       pcie_cq_np_req;
    wire                              [5:0]    pcie_cq_np_req_count;
 
    wire                                       cfg_phy_link_down;
    wire                              [3:0]    cfg_negotiated_width;
    wire                              [2:0]    cfg_current_speed;
    wire                              [2:0]    cfg_max_payload;
    wire                              [2:0]    cfg_max_read_req;
    wire                              [7:0]    cfg_function_status;
    wire                              [5:0]    cfg_function_power_state;
    wire                             [11:0]    cfg_vf_status;
    wire                             [17:0]    cfg_vf_power_state;
    wire                              [1:0]    cfg_link_power_state;
 
    // Error Reporting Interface
    wire                                       cfg_err_cor_out;
    wire                                       cfg_err_nonfatal_out;
    wire                                       cfg_err_fatal_out;
 
    wire                                       cfg_ltr_enable;
    wire                              [5:0]    cfg_ltssm_state;
    wire                              [1:0]    cfg_rcb_status;
    wire                              [1:0]    cfg_dpa_substate_change;
    wire                              [1:0]    cfg_obff_enable;
    wire                                       cfg_pl_status_change;
 
    wire                              [1:0]    cfg_tph_requester_enable;
    wire                              [5:0]    cfg_tph_st_mode;
    wire                              [5:0]    cfg_vf_tph_requester_enable;
    wire                             [17:0]    cfg_vf_tph_st_mode;
    // Management Interface
    wire                             [18:0]    cfg_mgmt_addr;
    wire                                       cfg_mgmt_write;
    wire                             [31:0]    cfg_mgmt_write_data;
    wire                              [3:0]    cfg_mgmt_byte_enable;
    wire                                       cfg_mgmt_read;
    wire                             [31:0]    cfg_mgmt_read_data;
    wire                                       cfg_mgmt_read_write_done;
    wire                                       cfg_mgmt_type1_cfg_reg_access;
    wire                                       cfg_msg_received;
    wire                              [7:0]    cfg_msg_received_data;
    wire                              [4:0]    cfg_msg_received_type;
    wire                                       cfg_msg_transmit;
    wire                              [2:0]    cfg_msg_transmit_type;
    wire                             [31:0]    cfg_msg_transmit_data;
    wire                                       cfg_msg_transmit_done;
    wire                              [7:0]    cfg_fc_ph;
    wire                             [11:0]    cfg_fc_pd;
    wire                              [7:0]    cfg_fc_nph;
    wire                             [11:0]    cfg_fc_npd;
    wire                              [7:0]    cfg_fc_cplh;
    wire                             [11:0]    cfg_fc_cpld;
    wire                              [2:0]    cfg_fc_sel;
    wire                              [2:0]    cfg_per_func_status_control;
    wire                             [15:0]    cfg_per_func_status_data;
    wire                                       cfg_config_space_enable;
    wire                              [7:0]    cfg_ds_port_number;
    wire                              [7:0]    cfg_ds_bus_number;
    wire                              [4:0]    cfg_ds_device_number;
    wire                              [2:0]    cfg_ds_function_number;
    wire                                       cfg_err_cor_in;
    wire                                       cfg_err_uncor_in;
    wire                              [1:0]    cfg_flr_in_process;
    wire                              [1:0]    cfg_flr_done;
    wire                                       cfg_hot_reset_out;
    wire                                       cfg_hot_reset_in;
    wire                                       cfg_link_training_enable;
    wire                              [2:0]    cfg_per_function_number;
    wire                                       cfg_per_function_output_request;
    wire                                       cfg_per_function_update_done;
    wire                                       cfg_power_state_change_interrupt;
    wire                                       cfg_req_pm_transition_l23_ready;
    wire                              [5:0]    cfg_vf_flr_in_process;
    wire                              [5:0]    cfg_vf_flr_done;
    wire                                       cfg_power_state_change_ack;
 
    wire                                       cfg_ext_read_received;
    wire                                       cfg_ext_write_received;
    wire                              [9:0]    cfg_ext_register_number;
    wire                              [7:0]    cfg_ext_function_number;
    wire                             [31:0]    cfg_ext_write_data;
    wire                              [3:0]    cfg_ext_write_byte_enable;
    wire                             [31:0]    cfg_ext_read_data;
    wire                                       cfg_ext_read_data_valid;
    //----------------------------------------------------------------------------------------------------------------//
    // EP Only                                                                                                        //
    //----------------------------------------------------------------------------------------------------------------//
 
    // Interrupt Interface Signals
    wire                              [3:0]    cfg_interrupt_int;
    wire                              [1:0]    cfg_interrupt_pending;
    wire                                       cfg_interrupt_sent;
    wire                              [1:0]    cfg_interrupt_msi_enable;
    wire                              [5:0]    cfg_interrupt_msi_vf_enable;
    wire                              [5:0]    cfg_interrupt_msi_mmenable;
    wire                                       cfg_interrupt_msi_mask_update;
    wire                             [31:0]    cfg_interrupt_msi_data;
    wire                              [3:0]    cfg_interrupt_msi_select;
    wire                             [31:0]    cfg_interrupt_msi_int;
    wire                             [63:0]    cfg_interrupt_msi_pending_status;
    wire                                       cfg_interrupt_msi_sent;
    wire                                       cfg_interrupt_msi_fail;
    wire                              [2:0]    cfg_interrupt_msi_attr;
    wire                                       cfg_interrupt_msi_tph_present;
    wire                              [1:0]    cfg_interrupt_msi_tph_type;
    wire                              [8:0]    cfg_interrupt_msi_tph_st_tag;
    wire                              [2:0]    cfg_interrupt_msi_function_number;
 
 
 
 
 
    //----------------------------------------------------------------------------------------------------------------//
    //    System(SYS) Interface                                                                                       //
    //----------------------------------------------------------------------------------------------------------------//
    wire                                               sys_clk;
    wire                                               sys_clk_gt;
    wire                                               sys_reset_n_c;

    //-----------------------------------------------------------------------------------------------------------------------

    IBUF   sys_reset_n_ibuf (.O(sys_reset_n_c), .I(sys_reset_n));
  
    // ref_clk IBUFDS from the edge connector
    IBUFDS_GTE3 refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
 
 
  //wire [15:0]  cfg_vend_id        = 16'h19DE;   
  wire [15:0]  cfg_subsys_vend_id = 16'h19DE;                                  
  //wire [15:0]  cfg_dev_id         = 16'h0850;   
  //wire [15:0]  cfg_subsys_id      = 16'h2095;                                
  //wire [7:0]   cfg_rev_id         = 8'h05; 
 
 
    // Support Level Wrapper
    pcie3_ultrascale_0 pcie3_ultrascale_0_i (
 
    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//

    // Tx
    .pci_exp_txn                                    ( pci_exp_txn ),
    .pci_exp_txp                                    ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                                    ( pci_exp_rxn ),
    .pci_exp_rxp                                    ( pci_exp_rxp ),

    //---------------------------------------------------------------------------------------//
    //  AXI Interface                                                                        //
    //---------------------------------------------------------------------------------------//

    .user_clk                                       ( user_clk ),
    .user_reset                                     ( user_reset ),
    .user_lnk_up                                    ( user_lnk_up ),
  
    .s_axis_rq_tlast                                ( s_axis_rq_tlast ),
    .s_axis_rq_tdata                                ( s_axis_rq_tdata ),
    .s_axis_rq_tuser                                ( s_axis_rq_tuser ),
    .s_axis_rq_tkeep                                ( s_axis_rq_tkeep ),
    .s_axis_rq_tready                               ( s_axis_rq_tready ),
    .s_axis_rq_tvalid                               ( s_axis_rq_tvalid ),

    .m_axis_rc_tdata                                ( m_axis_rc_tdata ),
    .m_axis_rc_tuser                                ( m_axis_rc_tuser ),
    .m_axis_rc_tlast                                ( m_axis_rc_tlast ),
    .m_axis_rc_tkeep                                ( m_axis_rc_tkeep ),
    .m_axis_rc_tvalid                               ( m_axis_rc_tvalid ),
    .m_axis_rc_tready                               ( m_axis_rc_tready ),

    .m_axis_cq_tdata                                ( m_axis_cq_tdata ),
    .m_axis_cq_tuser                                ( m_axis_cq_tuser ),
    .m_axis_cq_tlast                                ( m_axis_cq_tlast ),
    .m_axis_cq_tkeep                                ( m_axis_cq_tkeep ),
    .m_axis_cq_tvalid                               ( m_axis_cq_tvalid ),
    .m_axis_cq_tready                               ( m_axis_cq_tready ),

    .s_axis_cc_tdata                                ( s_axis_cc_tdata ),
    .s_axis_cc_tuser                                ( s_axis_cc_tuser ),
    .s_axis_cc_tlast                                ( s_axis_cc_tlast ),
    .s_axis_cc_tkeep                                ( s_axis_cc_tkeep ),
    .s_axis_cc_tvalid                               ( s_axis_cc_tvalid ),
    .s_axis_cc_tready                               ( s_axis_cc_tready ),

    //---------------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                        //
    //---------------------------------------------------------------------------------------//

    .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
    .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
    .pcie_rq_tag                                    ( pcie_rq_tag ),
    .pcie_rq_tag_av                                 ( ),
    .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),
    .pcie_cq_np_req                                 ( pcie_cq_np_req ),
    .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),
    .cfg_phy_link_down                              ( cfg_phy_link_down ),
    .cfg_phy_link_status                            ( ),
    .cfg_negotiated_width                           ( cfg_negotiated_width ),
    .cfg_current_speed                              ( cfg_current_speed ),
    .cfg_max_payload                                ( cfg_max_payload ),
    .cfg_max_read_req                               ( cfg_max_read_req ),
    .cfg_function_status                            ( cfg_function_status ),
    .cfg_function_power_state                       ( cfg_function_power_state ),
    .cfg_vf_status                                  ( cfg_vf_status ),
    .cfg_vf_power_state                             ( cfg_vf_power_state ),
    .cfg_link_power_state                           ( cfg_link_power_state ),
    // Error Reporting Interface
    .cfg_err_cor_out                                ( cfg_err_cor_out ),
    .cfg_err_nonfatal_out                           ( cfg_err_nonfatal_out ),
    .cfg_err_fatal_out                              ( cfg_err_fatal_out ),

    .cfg_local_error                                ( ),

    .cfg_ltr_enable                                 ( cfg_ltr_enable ),
    .cfg_ltssm_state                                ( cfg_ltssm_state ),
    .cfg_rcb_status                                 ( cfg_rcb_status ),
    .cfg_dpa_substate_change                        ( cfg_dpa_substate_change ),
    .cfg_obff_enable                                ( cfg_obff_enable ),
    .cfg_pl_status_change                           ( cfg_pl_status_change ),

    .cfg_tph_requester_enable                       ( cfg_tph_requester_enable ),
    .cfg_tph_st_mode                                ( cfg_tph_st_mode ),
    .cfg_vf_tph_requester_enable                    ( cfg_vf_tph_requester_enable ),
    .cfg_vf_tph_st_mode                             ( cfg_vf_tph_st_mode ),
    // Management Interface
    .cfg_mgmt_addr                                  ( cfg_mgmt_addr ),
    .cfg_mgmt_write                                 ( cfg_mgmt_write ),
    .cfg_mgmt_write_data                            ( cfg_mgmt_write_data ),
    .cfg_mgmt_byte_enable                           ( cfg_mgmt_byte_enable ),
    .cfg_mgmt_read                                  ( cfg_mgmt_read ),
    .cfg_mgmt_read_data                             ( cfg_mgmt_read_data ),
    .cfg_mgmt_read_write_done                       ( cfg_mgmt_read_write_done ),
    .cfg_mgmt_type1_cfg_reg_access                  ( cfg_mgmt_type1_cfg_reg_access ),
    .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),
    .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),
    .cfg_msg_received                               ( cfg_msg_received ),
    .cfg_msg_received_data                          ( cfg_msg_received_data ),
    .cfg_msg_received_type                          ( cfg_msg_received_type ),

    .cfg_msg_transmit                               ( cfg_msg_transmit ),
    .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
    .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
    .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),

    .cfg_fc_ph                                      ( cfg_fc_ph ),
    .cfg_fc_pd                                      ( cfg_fc_pd ),
    .cfg_fc_nph                                     ( cfg_fc_nph ),
    .cfg_fc_npd                                     ( cfg_fc_npd ),
    .cfg_fc_cplh                                    ( cfg_fc_cplh ),
    .cfg_fc_cpld                                    ( cfg_fc_cpld ),
    .cfg_fc_sel                                     ( cfg_fc_sel ),

    .cfg_per_func_status_control                    ( cfg_per_func_status_control ),
    .cfg_per_func_status_data                       ( cfg_per_func_status_data ),
    //-------------------------------------------------------------------------------//
    // EP and RP                                                                     //
    //-------------------------------------------------------------------------------//
    //.cfg_vend_id                                    ( cfg_vend_id ),
    //.cfg_dev_id                                     ( cfg_dev_id ),
    //.cfg_rev_id                                     ( cfg_rev_id ),
    .cfg_subsys_vend_id                             ( cfg_subsys_vend_id ),
    //.cfg_subsys_id                                  ( cfg_subsys_id ),

    .cfg_per_function_number                        ( cfg_per_function_number ),
    .cfg_per_function_output_request                ( cfg_per_function_output_request ),
    .cfg_per_function_update_done                   ( cfg_per_function_update_done ),

    .cfg_dsn                                        ( cfg_dsn ),
    .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),
    .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),
    .cfg_err_cor_in                                 ( cfg_err_cor_in ),
    .cfg_err_uncor_in                               ( cfg_err_uncor_in ),

    .cfg_flr_in_process                             ( cfg_flr_in_process ),
    .cfg_flr_done                                   ( {2'b0,cfg_flr_done} ),
    .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
    .cfg_vf_flr_done                                ( {2'b0,cfg_vf_flr_done} ),

    .cfg_link_training_enable                       ( cfg_link_training_enable ),
  // EP only
    .cfg_hot_reset_out                              ( cfg_hot_reset_out ),
    .cfg_config_space_enable                        ( cfg_config_space_enable ),
    .cfg_req_pm_transition_l23_ready                ( cfg_req_pm_transition_l23_ready ),

  // RP only
    .cfg_hot_reset_in                               ( cfg_hot_reset_in ),

    .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
    .cfg_ds_device_number                           ( cfg_ds_device_number ),
    .cfg_ds_function_number                         ( cfg_ds_function_number ),
    .cfg_ds_port_number                             ( cfg_ds_port_number ),
    .cfg_ext_read_received                          ( cfg_ext_read_received ),
    .cfg_ext_write_received                         ( cfg_ext_write_received ),
    .cfg_ext_register_number                        ( cfg_ext_register_number ),
    .cfg_ext_function_number                        ( cfg_ext_function_number ),
    .cfg_ext_write_data                             ( cfg_ext_write_data ),
    .cfg_ext_write_byte_enable                      ( cfg_ext_write_byte_enable ),
    .cfg_ext_read_data                              ( cfg_ext_read_data ),
    .cfg_ext_read_data_valid                        ( cfg_ext_read_data_valid ),
    //-------------------------------------------------------------------------------//
    // EP Only                                                                       //
    //-------------------------------------------------------------------------------//

    // Interrupt Interface Signals
    .cfg_interrupt_int                              ( cfg_interrupt_int ),
    .cfg_interrupt_pending                          ( {2'b0,cfg_interrupt_pending} ),
    .cfg_interrupt_sent                             ( cfg_interrupt_sent ),

    .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable ),
    .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
    .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
    .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
    .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
    .cfg_interrupt_msi_select                       ( cfg_interrupt_msi_select ),
    .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
    .cfg_interrupt_msi_pending_status               ( cfg_interrupt_msi_pending_status [31:0]),
    .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
    .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),
    .cfg_interrupt_msi_attr                         ( cfg_interrupt_msi_attr ),
    .cfg_interrupt_msi_tph_present                  ( cfg_interrupt_msi_tph_present ),
    .cfg_interrupt_msi_tph_type                     ( cfg_interrupt_msi_tph_type ),
    .cfg_interrupt_msi_tph_st_tag                   ( cfg_interrupt_msi_tph_st_tag ),
    .cfg_interrupt_msi_function_number              ( {1'b0,cfg_interrupt_msi_function_number} ),
    .cfg_interrupt_msi_pending_status_function_num  ( 4'b0),
    .cfg_interrupt_msi_pending_status_data_enable   ( 1'b0),
    //--------------------------------------------------------------------------------------//
    // Reset Pass Through Signals
    //  - Only used for PCIe_X0Y0
    //--------------------------------------------------------------------------------------//
    //.pcie_perstn0_out       (),
    .pcie_perstn1_in        (1'b0),
    //.pcie_perstn1_out       (),

    //--------------------------------------------------------------------------------------//
    //  System(SYS) Interface                                                               //
    //--------------------------------------------------------------------------------------//

    .sys_clk                                        ( sys_clk ),
    .sys_clk_gt                                     ( sys_clk_gt ),
    .sys_reset                                      ( sys_reset_n_c )
    );
 
 
    //------------------------------------------------------------------------------------------------------------------//
    //       PIO Example Design Top Level                                                                               //
    //------------------------------------------------------------------------------------------------------------------//
    pcie3_7x_to_v1_6 #(
        .TCQ                                    ( TCQ                           ),
        .C_DATA_WIDTH                           ( C_DATA_WIDTH                   )
    ) pcie3_7x_to_v1_6 (
  
        //-------------------------------------------------------------------------------------//
        //  AXI Interface                                                                      //
        //-------------------------------------------------------------------------------------//
  
        .s_axis_rq_tlast                                ( s_axis_rq_tlast ),
        .s_axis_rq_tdata                                ( s_axis_rq_tdata ),
        .s_axis_rq_tuser                                ( s_axis_rq_tuser ),
        .s_axis_rq_tkeep                                ( s_axis_rq_tkeep ),
        .s_axis_rq_tready                               ( s_axis_rq_tready ),
        .s_axis_rq_tvalid                               ( s_axis_rq_tvalid ),
  
        .m_axis_rc_tdata                                ( m_axis_rc_tdata ),
        .m_axis_rc_tuser                                ( m_axis_rc_tuser ),
        .m_axis_rc_tlast                                ( m_axis_rc_tlast ),
        .m_axis_rc_tkeep                                ( m_axis_rc_tkeep ),
        .m_axis_rc_tvalid                               ( m_axis_rc_tvalid ),
        .m_axis_rc_tready                               ( m_axis_rc_tready ),
  
        .m_axis_cq_tdata                                ( m_axis_cq_tdata ),
        .m_axis_cq_tuser                                ( m_axis_cq_tuser ),
        .m_axis_cq_tlast                                ( m_axis_cq_tlast ),
        .m_axis_cq_tkeep                                ( m_axis_cq_tkeep ),
        .m_axis_cq_tvalid                               ( m_axis_cq_tvalid ),
        .m_axis_cq_tready                               ( m_axis_cq_tready ),
  
        .s_axis_cc_tdata                                ( s_axis_cc_tdata ),
        .s_axis_cc_tuser                                ( s_axis_cc_tuser ),
        .s_axis_cc_tlast                                ( s_axis_cc_tlast ),
        .s_axis_cc_tkeep                                ( s_axis_cc_tkeep ),
        .s_axis_cc_tvalid                               ( s_axis_cc_tvalid ),
        .s_axis_cc_tready                               ( s_axis_cc_tready ),

        .s_axis_tx_tready                               ( s_axis_tx_tready  ),
        .s_axis_tx_tdata                                ( s_axis_tx_tdata   ),
        .s_axis_tx_tstrb                                ( s_axis_tx_tstrb   ),
        .s_axis_tx_tuser                                ( s_axis_tx_tuser   ),
        .s_axis_tx_tlast                                ( s_axis_tx_tlast   ),
        .s_axis_tx_tvalid                               ( s_axis_tx_tvalid  ),

        .m_axis_rx_tdata                                ( m_axis_rx_tdata   ),
        .m_axis_rx_tstrb                                ( m_axis_rx_tstrb   ),
        .m_axis_rx_tlast                                ( m_axis_rx_tlast   ),
        .m_axis_rx_tvalid                               ( m_axis_rx_tvalid  ),
        .m_axis_rx_tready                               ( m_axis_rx_tready  ),
        .m_axis_rx_tuser                                ( m_axis_rx_tuser   ),

        .cfg_interrupt                                  ( cfg_interrupt ),
        .cfg_interrupt_rdy                              ( cfg_interrupt_rdy ),

        //--------------------------------------------------------------------------------//
        //  Configuration (CFG) Interface                                                 //
        //--------------------------------------------------------------------------------//

        .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),
        .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),
  
        .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
        .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
        .pcie_rq_tag                                    ( pcie_rq_tag ),
        .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),
  
        .pcie_cq_np_req                                 ( pcie_cq_np_req ),
        .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),
  
        .cfg_phy_link_down                              ( cfg_phy_link_down ),
        .cfg_negotiated_width                           ( cfg_negotiated_width ),
        .cfg_current_speed                              ( cfg_current_speed ),
        .cfg_max_payload                                ( cfg_max_payload ),
        .cfg_max_read_req                               ( cfg_max_read_req ),
        .cfg_function_status                            ( cfg_function_status ),
        .cfg_function_power_state                       ( cfg_function_power_state ),
        .cfg_vf_status                                  ( cfg_vf_status ),
        .cfg_vf_power_state                             ( cfg_vf_power_state ),
        .cfg_link_power_state                           ( cfg_link_power_state ),
  
        // Error Reporting Interface
        .cfg_err_cor_out                                ( cfg_err_cor_out ),
        .cfg_err_nonfatal_out                           ( cfg_err_nonfatal_out ),
        .cfg_err_fatal_out                              ( cfg_err_fatal_out ),
  
        .cfg_ltr_enable                                 ( cfg_ltr_enable ),
        .cfg_ltssm_state                                ( cfg_ltssm_state ),
        .cfg_rcb_status                                 ( cfg_rcb_status ),
        .cfg_dpa_substate_change                        ( cfg_dpa_substate_change ),
        .cfg_obff_enable                                ( cfg_obff_enable ),
        .cfg_pl_status_change                           ( cfg_pl_status_change ),
  
        .cfg_tph_requester_enable                       ( cfg_tph_requester_enable ),
        .cfg_tph_st_mode                                ( cfg_tph_st_mode ),
        .cfg_vf_tph_requester_enable                    ( cfg_vf_tph_requester_enable ),
        .cfg_vf_tph_st_mode                             ( cfg_vf_tph_st_mode ),
        // Management Interface
        .cfg_mgmt_addr                                  ( cfg_mgmt_addr ),
        .cfg_mgmt_write                                 ( cfg_mgmt_write ),
        .cfg_mgmt_write_data                            ( cfg_mgmt_write_data ),
        .cfg_mgmt_byte_enable                           ( cfg_mgmt_byte_enable ),
        .cfg_mgmt_read                                  ( cfg_mgmt_read ),
        .cfg_mgmt_read_data                             ( cfg_mgmt_read_data ),
        .cfg_mgmt_read_write_done                       ( cfg_mgmt_read_write_done ),
        .cfg_mgmt_type1_cfg_reg_access                  ( cfg_mgmt_type1_cfg_reg_access ),
        .cfg_msg_received                               ( cfg_msg_received ),
        .cfg_msg_received_data                          ( cfg_msg_received_data ),
        .cfg_msg_received_type                          ( cfg_msg_received_type ),
        .cfg_msg_transmit                               ( cfg_msg_transmit ),
        .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
        .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
        .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),
        .cfg_fc_ph                                      ( cfg_fc_ph ),
        .cfg_fc_pd                                      ( cfg_fc_pd ),
        .cfg_fc_nph                                     ( cfg_fc_nph ),
        .cfg_fc_npd                                     ( cfg_fc_npd ),
        .cfg_fc_cplh                                    ( cfg_fc_cplh ),
        .cfg_fc_cpld                                    ( cfg_fc_cpld ),
        .cfg_fc_sel                                     ( cfg_fc_sel ),
        .cfg_per_func_status_control                    ( cfg_per_func_status_control ),
        .cfg_per_func_status_data                       ( cfg_per_func_status_data ),
        .cfg_config_space_enable                        ( cfg_config_space_enable ),
        .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
        .cfg_ds_device_number                           ( cfg_ds_device_number ),
        .cfg_ds_function_number                         ( cfg_ds_function_number ),
        .cfg_ds_port_number                             ( cfg_ds_port_number ),
        .cfg_err_cor_in                                 ( cfg_err_cor_in ),
        .cfg_err_uncor_in                               ( cfg_err_uncor_in ),
        .cfg_flr_in_process                             ( cfg_flr_in_process ),
        .cfg_flr_done                                   ( cfg_flr_done ),
        .cfg_hot_reset_in                               ( cfg_hot_reset_in ),
        .cfg_hot_reset_out                              ( cfg_hot_reset_out ),
        .cfg_link_training_enable                       ( cfg_link_training_enable ),
        .cfg_per_function_number                        ( cfg_per_function_number ),
        .cfg_per_function_output_request                ( cfg_per_function_output_request ),
        .cfg_per_function_update_done                   ( cfg_per_function_update_done ),
        .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),
        .cfg_req_pm_transition_l23_ready                ( cfg_req_pm_transition_l23_ready ),
        .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
        .cfg_vf_flr_done                                ( cfg_vf_flr_done ),
        .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),
        .cfg_ext_read_received                          ( cfg_ext_read_received ),
        .cfg_ext_write_received                         ( cfg_ext_write_received ),
        .cfg_ext_register_number                        ( cfg_ext_register_number ),
        .cfg_ext_function_number                        ( cfg_ext_function_number ),
        .cfg_ext_write_data                             ( cfg_ext_write_data ),
        .cfg_ext_write_byte_enable                      ( cfg_ext_write_byte_enable ),
        .cfg_ext_read_data                              ( cfg_ext_read_data ),
        .cfg_ext_read_data_valid                        ( cfg_ext_read_data_valid ),
  
  
        //-------------------------------------------------------------------------------------//
        // EP Only                                                                             //
        //-------------------------------------------------------------------------------------//
  
        // Interrupt Interface Signals
        .cfg_interrupt_int                              ( cfg_interrupt_int ),
        .cfg_interrupt_pending                          ( cfg_interrupt_pending ),
        .cfg_interrupt_sent                             ( cfg_interrupt_sent ),
        .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable ),
        .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
        .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
        .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
        .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
        .cfg_interrupt_msi_select                       ( cfg_interrupt_msi_select ),
        .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
        .cfg_interrupt_msi_pending_status               ( cfg_interrupt_msi_pending_status ),
        .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
        .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),
        .cfg_interrupt_msi_attr                         ( cfg_interrupt_msi_attr ),
        .cfg_interrupt_msi_tph_present                  ( cfg_interrupt_msi_tph_present ),
        .cfg_interrupt_msi_tph_type                     ( cfg_interrupt_msi_tph_type ),
        .cfg_interrupt_msi_tph_st_tag                   ( cfg_interrupt_msi_tph_st_tag ),
        .cfg_interrupt_msi_function_number              ( cfg_interrupt_msi_function_number ),
  
  
        .user_clk                                       ( user_clk ),
        .user_reset                                     ( user_reset ),
        .user_lnk_up                                    ( user_lnk_up )
 
    );


endmodule

