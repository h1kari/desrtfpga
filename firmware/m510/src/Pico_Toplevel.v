// Copyright 2009-2016 Micron Technology, Inc. All Rights Reserved.  This
// software contains confidential information and trade secrets of Micron
// Technology, Inc. Use, disclosure, or reproduction is prohibited without the
// prior express written permission of Micron Technology, Inc.

`timescale 1ns / 1ps

`include "PicoDefines.v"

// *********************************************************
// M510 Pico_Toplevel
//
// Macro defs:
//     PICOBUS_WIDTH       : enable pico bus
//     ENABLE_HMC          : enable hmc controller
//     ENABLE_2ND_HMC_LINK : enable 2nd hmc link (controller) 
//     LED                 : led?
// *********************************************************

module Pico_Toplevel # (

    parameter HMC_LANE_WIDTH          = 8 ,
    
    parameter PL_FAST_TRAIN           = "FALSE",
    parameter C_DATA_WIDTH            = 128,            
                                        // RX/TX interface data width

    parameter C_AXI_ID_WIDTH       = 6,
    parameter C_AXI_ADDR_WIDTH     = 34,
    parameter C_AXI_DATA_WIDTH     = 128, 
`ifdef LED
    parameter LED_NUM                 = 1,
`endif // LED
    
    // Do not override parameters below this line
    parameter STRB_WIDTH              = C_DATA_WIDTH / 8               
                                        // TSTRB width

)
(

`ifdef ENABLE_HMC
    // HMC reference clock
    input                               hmc_refclkp  ,
    input                               hmc_refclkn  ,

    // HMC Link Interface
    input  [HMC_LANE_WIDTH-1:0]         lxrxp        ,
    input  [HMC_LANE_WIDTH-1:0]         lxrxn        ,
    output [HMC_LANE_WIDTH-1:0]         lxtxp        ,
    output [HMC_LANE_WIDTH-1:0]         lxtxn        ,

    // HMC Power Save Pins
    output                              lxrxps       ,
    input                               lxtxps       ,

    // HMC Error Interrupt
    input                               ferr_n       ,

    // HMC Global Reset
    inout                               p_rst_n      ,

    // HMC I2C
    inout                               scl          ,
    inout                               sda          ,

    // Test reset signal
    output  [2:0]                       cub          ,
    output                              trst_n       ,

    // 2nd HMC Link //
    `ifdef ENABLE_2ND_HMC_LINK
        input                           hmc1_refclkp ,
        input                           hmc1_refclkn ,
        input  [HMC_LANE_WIDTH-1:0]     hmc1_lxrxp   ,
        input  [HMC_LANE_WIDTH-1:0]     hmc1_lxrxn   ,
        output [HMC_LANE_WIDTH-1:0]     hmc1_lxtxp   ,
        output [HMC_LANE_WIDTH-1:0]     hmc1_lxtxn   ,

        output                          hmc1_lxrxps  ,
        input                           hmc1_lxtxps  ,
    `endif
`endif

    output  [7:0]                       pci_exp_txp,
    output  [7:0]                       pci_exp_txn,
    input   [7:0]                       pci_exp_rxp,
    input   [7:0]                       pci_exp_rxn,

    
    input                               extra_clk_p,
    input                               extra_clk_n,

`ifdef LED
    output  [LED_NUM-1:0]               led_r,
    output  [LED_NUM-1:0]               led_g,
    output  [LED_NUM-1:0]               led_b,
`endif

    input                               sys_clk_p,
    input                               sys_clk_n,
    input                               sys_reset_n
);
    
    wire                                s_clk;
    wire                                s_rst;

    wire [127:0]                        s_in_data;
    wire [8:0]                          s_in_id;
    wire                                s_in_valid;

    wire                                s_out_en;
    wire [8:0]                          s_out_id;
    wire [127:0]                        s_out_data;

    wire [8:0]                          s_poll_id;
    wire [31:0]                         s_poll_seq;
    wire                                s_poll_next_desc_valid;
    wire [127:0]                        s_poll_next_desc;

    wire                                s_next_desc_rd_en;
    wire [8:0]                          s_next_desc_rd_id;
    
    wire [9:0]                          temp;

`ifdef PICOBUS_WIDTH
    wire [7:0]                      UserPBWidth = `PICOBUS_WIDTH;
`else
    wire [7:0]                      UserPBWidth = 0;
`endif // PICOBUS_WIDTH

`ifdef ENABLE_HMC
    wire            PicoClk;
    wire            PicoRst;

    wire [31:0]     PicoAddr;
    wire            PicoRd;
    wire            PicoWr;
    wire [127:0]    PicoDataIn;
    wire [127:0]    PicoDataOut;

    wire [31:0]     hmc0_PicoAddr;
    wire            hmc0_PicoRd;
    wire            hmc0_PicoWr;

    wire            hmc_tx_clk ;
    wire            hmc_rx_clk ;
    wire            hmc_rst    ;
    wire            hmc_trained;

    wire            hmc_cmd_valid_p0;
    wire            hmc_wr_data_valid_p0;
    wire   [3:0]    hmc_cmd_p0; 
    wire            hmc_rd_data_valid_p0;
    wire            hmc_clk_p0;
    wire  [33:0]    hmc_addr_p0;
    wire   [3:0]    hmc_size_p0;
    wire [127:0]    hmc_wr_data_p0;
    wire [127:0]    hmc_rd_data_p0;
    wire            hmc_wr_data_ready_p0, hmc_cmd_ready_p0;
    wire   [5:0]    hmc_tag_p0, hmc_rd_data_tag_p0;
    wire   [6:0]    hmc_errstat_p0;
    wire            hmc_dinv_p0;

    wire            hmc_cmd_valid_p1;
    wire            hmc_wr_data_valid_p1;
    wire   [3:0]    hmc_cmd_p1; 
    wire            hmc_rd_data_valid_p1;
    wire            hmc_clk_p1;
    wire  [33:0]    hmc_addr_p1;
    wire   [3:0]    hmc_size_p1;
    wire [127:0]    hmc_wr_data_p1;
    wire [127:0]    hmc_rd_data_p1;
    wire            hmc_wr_data_ready_p1, hmc_cmd_ready_p1;
    wire   [5:0]    hmc_tag_p1, hmc_rd_data_tag_p1;
    wire   [6:0]    hmc_errstat_p1;
    wire            hmc_dinv_p1;

    wire            hmc_cmd_valid_p2;
    wire            hmc_wr_data_valid_p2;
    wire   [3:0]    hmc_cmd_p2; 
    wire            hmc_rd_data_valid_p2;
    wire            hmc_clk_p2;
    wire  [33:0]    hmc_addr_p2;
    wire   [3:0]    hmc_size_p2;
    wire [127:0]    hmc_wr_data_p2;
    wire [127:0]    hmc_rd_data_p2;
    wire            hmc_wr_data_ready_p2, hmc_cmd_ready_p2;
    wire   [5:0]    hmc_tag_p2, hmc_rd_data_tag_p2;
    wire   [6:0]    hmc_errstat_p2;
    wire            hmc_dinv_p2;

    wire            hmc_cmd_valid_p3;
    wire            hmc_wr_data_valid_p3;
    wire   [3:0]    hmc_cmd_p3; 
    wire            hmc_rd_data_valid_p3;
    wire            hmc_clk_p3;
    wire  [33:0]    hmc_addr_p3;
    wire   [3:0]    hmc_size_p3;
    wire [127:0]    hmc_wr_data_p3;
    wire [127:0]    hmc_rd_data_p3;
    wire            hmc_wr_data_ready_p3, hmc_cmd_ready_p3;
    wire   [5:0]    hmc_tag_p3, hmc_rd_data_tag_p3;
    wire   [6:0]    hmc_errstat_p3;
    wire            hmc_dinv_p3;

    wire            hmc_cmd_valid_p4;
    wire            hmc_wr_data_valid_p4;
    wire   [3:0]    hmc_cmd_p4; 
    wire            hmc_rd_data_valid_p4;
    wire            hmc_clk_p4;
    wire  [33:0]    hmc_addr_p4;
    wire   [3:0]    hmc_size_p4;
    wire [127:0]    hmc_wr_data_p4;
    wire [127:0]    hmc_rd_data_p4;
    wire            hmc_wr_data_ready_p4, hmc_cmd_ready_p4;
    wire   [5:0]    hmc_tag_p4, hmc_rd_data_tag_p4;
    wire   [6:0]    hmc_errstat_p4;
    wire            hmc_dinv_p4;


    wire [31:0]     hmc1_PicoAddr;
    wire            hmc1_PicoRd;
    wire            hmc1_PicoWr;
    wire [127:0]    hmc1_PicoDataOut;

    `ifdef ENABLE_2ND_HMC_LINK
    
        wire            hmc1_tx_clk, hmc1_rx_clk, hmc1_rst, hmc1_trained;
    
    
        wire            hmc_cmd_valid_p5;
        wire            hmc_wr_data_valid_p5;
        wire   [3:0]    hmc_cmd_p5; 
        wire            hmc_rd_data_valid_p5;
        wire            hmc_clk_p5;
        wire  [33:0]    hmc_addr_p5;
        wire   [3:0]    hmc_size_p5;
        wire [127:0]    hmc_wr_data_p5;
        wire [127:0]    hmc_rd_data_p5;
        wire            hmc_wr_data_ready_p5, hmc_cmd_ready_p5;
        wire   [5:0]    hmc_tag_p5, hmc_rd_data_tag_p5;
        wire   [6:0]    hmc_errstat_p5;
        wire            hmc_dinv_p5;
    
        wire            hmc_cmd_valid_p6;
        wire            hmc_wr_data_valid_p6;
        wire   [3:0]    hmc_cmd_p6; 
        wire            hmc_rd_data_valid_p6;
        wire            hmc_clk_p6;
        wire  [33:0]    hmc_addr_p6;
        wire   [3:0]    hmc_size_p6;
        wire [127:0]    hmc_wr_data_p6;
        wire [127:0]    hmc_rd_data_p6;
        wire            hmc_wr_data_ready_p6, hmc_cmd_ready_p6;
        wire   [5:0]    hmc_tag_p6, hmc_rd_data_tag_p6;
        wire   [6:0]    hmc_errstat_p6;
        wire            hmc_dinv_p6;
    
        wire            hmc_cmd_valid_p7;
        wire            hmc_wr_data_valid_p7;
        wire   [3:0]    hmc_cmd_p7; 
        wire            hmc_rd_data_valid_p7;
        wire            hmc_clk_p7;
        wire  [33:0]    hmc_addr_p7;
        wire   [3:0]    hmc_size_p7;
        wire [127:0]    hmc_wr_data_p7;
        wire [127:0]    hmc_rd_data_p7;
        wire            hmc_wr_data_ready_p7, hmc_cmd_ready_p7;
        wire   [5:0]    hmc_tag_p7, hmc_rd_data_tag_p7;
        wire   [6:0]    hmc_errstat_p7;
        wire            hmc_dinv_p7;
    
        wire            hmc_cmd_valid_p8;
        wire            hmc_wr_data_valid_p8;
        wire   [3:0]    hmc_cmd_p8; 
        wire            hmc_rd_data_valid_p8;
        wire            hmc_clk_p8;
        wire  [33:0]    hmc_addr_p8;
        wire   [3:0]    hmc_size_p8;
        wire [127:0]    hmc_wr_data_p8;
        wire [127:0]    hmc_rd_data_p8;
        wire            hmc_wr_data_ready_p8, hmc_cmd_ready_p8;
        wire   [5:0]    hmc_tag_p8, hmc_rd_data_tag_p8;
        wire   [6:0]    hmc_errstat_p8;
        wire            hmc_dinv_p8;
    
        wire            hmc_cmd_valid_p9;
        wire            hmc_wr_data_valid_p9;
        wire   [3:0]    hmc_cmd_p9; 
        wire            hmc_rd_data_valid_p9;
        wire            hmc_clk_p9;
        wire  [33:0]    hmc_addr_p9;
        wire   [3:0]    hmc_size_p9;
        wire [127:0]    hmc_wr_data_p9;
        wire [127:0]    hmc_rd_data_p9;
        wire            hmc_wr_data_ready_p9, hmc_cmd_ready_p9;
        wire   [5:0]    hmc_tag_p9, hmc_rd_data_tag_p9;
        wire   [6:0]    hmc_errstat_p9;
        wire            hmc_dinv_p9;
    `endif // ENALBE_2ND_HMC_LINK

`endif // ENABLE_HMC

    // user-direct writes
    wire [127:0]                        user_pci_wr_q_data;
    wire                                user_pci_wr_q_valid, user_pci_wr_q_en;
    wire [127:0]                        user_pci_wr_data_q_data;
    wire                                user_pci_wr_data_q_valid, user_pci_wr_data_q_en;
    wire                                direct_rx_valid;

    wire                                extra_clk;


`ifdef ENABLE_HMC
    // for now, we just tie off the cub and trst_n signals
    // in the future, we could potentially drive this from an HMC controller
    assign  cub                     = 3'b0;
    assign  trst_n                  = 1'b1;

    // need to create a single-ended reference clock for the HMC transceivers
    wire                                hmc_refclk;
    IBUFDS_GTE3 #(
        .REFCLK_EN_TX_PATH              (1'b0),
        .REFCLK_HROW_CK_SEL             (2'b00),
        .REFCLK_ICNTL_RX                (2'b00)
    ) IBUFDS_GTE3_MGTREFCLK0_X0Y1_INST (
        .I                              (hmc_refclkp),
        .IB                             (hmc_refclkn),
        .CEB                            (1'b0),
        .O                              (hmc_refclk),
        .ODIV2                          ()
    );
    
    // reference clock for the 2nd HMC link = L3
    // need to create a single-ended reference clock for the HMC transceivers
    `ifdef ENABLE_2ND_HMC_LINK
    wire                                hmc1_refclk;
    IBUFDS_GTE3 #(
        .REFCLK_EN_TX_PATH              (1'b0),
        .REFCLK_HROW_CK_SEL             (2'b00),
        .REFCLK_ICNTL_RX                (2'b00)
    ) IBUFDS_GTE3_HMC1_REFCLK (
        .I                              (hmc1_refclkp),
        .IB                             (hmc1_refclkn),
        .CEB                            (1'b0),
        .O                              (hmc1_refclk),
        .ODIV2                          ()
    );
    `endif
`endif // ENABLE_HMC



    // ---------------------------------------------------------------
    // FRAMEWORK
    // ---------------------------------------------------------------
    PicoFrameworkM510_KU060 
    PicoFramework (
        
        // stream signals we're taking to the toplevel for the user
        .s_clk                          ( s_clk                    ) ,
        .s_rst                          ( s_rst                    ) ,

        .s_out_en                       ( s_out_en                 ) ,
        .s_out_id                       ( s_out_id                 ) ,
        .s_out_data                     ( s_out_data               ) ,

        .s_in_valid                     ( s_in_valid               ) ,
        .s_in_id                        ( s_in_id[8:0]             ) ,
        .s_in_data                      ( s_in_data[127:0]         ) ,

        .s_poll_id                      ( s_poll_id[8:0]           ) ,
        .s_poll_seq                     ( s_poll_seq[31:0]         ) ,
        .s_poll_next_desc               ( s_poll_next_desc[127:0]  ) ,
        .s_poll_next_desc_valid         ( s_poll_next_desc_valid   ) ,

        .s_next_desc_rd_en              ( s_next_desc_rd_en        ) ,
        .s_next_desc_rd_id              ( s_next_desc_rd_id[8:0]   ) ,

        .UserPBWidth                    ( UserPBWidth              ) ,

        // user-direct writes
        .user_pci_wr_q_data             ( user_pci_wr_q_data       ) ,
        .user_pci_wr_q_valid            ( user_pci_wr_q_valid      ) ,
        .user_pci_wr_q_en               ( user_pci_wr_q_en         ) ,

        .user_pci_wr_data_q_data        ( user_pci_wr_data_q_data  ) ,
        .user_pci_wr_data_q_valid       ( user_pci_wr_data_q_valid ) ,
        .user_pci_wr_data_q_en          ( user_pci_wr_data_q_en    ) ,
        .direct_rx_valid                ( direct_rx_valid          ) ,
        
        .pci_exp_txp                    ( pci_exp_txp      ) ,
        .pci_exp_txn                    ( pci_exp_txn      ) ,
        .pci_exp_rxp                    ( pci_exp_rxp      ) ,
        .pci_exp_rxn                    ( pci_exp_rxn      ) ,

        .temp                           ( temp             ) ,

        .extra_clk_p                    ( extra_clk_p      ) ,
        .extra_clk_n                    ( extra_clk_n      ) ,
        .extra_clk                      ( extra_clk        ) ,

        .sys_clk_p                      ( sys_clk_p        ) ,
        .sys_clk_n                      ( sys_clk_n        ) ,
        .sys_reset_n                    ( sys_reset_n      )
    ); // PicoFramework
    
    
    
    UserWrapper UserWrapper (


    `ifdef ENABLE_HMC
        .hmc_tx_clk                  (hmc_tx_clk),
        .hmc_rx_clk                  (hmc_rx_clk),
        .hmc_rst                     (hmc_rst),
        .hmc_trained                 (hmc_trained),

        // hmc p0 --
        .hmc_clk_p0                  (hmc_clk_p0),
        .hmc_addr_p0                 (hmc_addr_p0),
        .hmc_size_p0                 (hmc_size_p0),
        .hmc_tag_p0                  (hmc_tag_p0),
        .hmc_cmd_valid_p0            (hmc_cmd_valid_p0),
        .hmc_cmd_ready_p0            (hmc_cmd_ready_p0),
        .hmc_cmd_p0                  (hmc_cmd_p0),
        .hmc_wr_data_p0              (hmc_wr_data_p0),
        .hmc_wr_data_valid_p0        (hmc_wr_data_valid_p0),
        .hmc_wr_data_ready_p0        (hmc_wr_data_ready_p0),
        .hmc_rd_data_p0              (hmc_rd_data_p0),
        .hmc_rd_data_tag_p0          (hmc_rd_data_tag_p0),
        .hmc_rd_data_valid_p0        (hmc_rd_data_valid_p0),
        .hmc_errstat_p0              (hmc_errstat_p0),
        .hmc_dinv_p0                 (hmc_dinv_p0),
        // hmc p1 --
        .hmc_clk_p1                  (hmc_clk_p1),
        .hmc_addr_p1                 (hmc_addr_p1),
        .hmc_size_p1                 (hmc_size_p1),
        .hmc_tag_p1                  (hmc_tag_p1),
        .hmc_cmd_valid_p1            (hmc_cmd_valid_p1),
        .hmc_cmd_ready_p1            (hmc_cmd_ready_p1),
        .hmc_cmd_p1                  (hmc_cmd_p1),
        .hmc_wr_data_p1              (hmc_wr_data_p1),
        .hmc_wr_data_valid_p1        (hmc_wr_data_valid_p1),
        .hmc_wr_data_ready_p1        (hmc_wr_data_ready_p1),
        .hmc_rd_data_p1              (hmc_rd_data_p1),
        .hmc_rd_data_tag_p1          (hmc_rd_data_tag_p1),
        .hmc_rd_data_valid_p1        (hmc_rd_data_valid_p1),
        .hmc_errstat_p1              (hmc_errstat_p1),
        .hmc_dinv_p1                 (hmc_dinv_p1),
        // hmc p2 --
        .hmc_clk_p2                  (hmc_clk_p2),
        .hmc_addr_p2                 (hmc_addr_p2),
        .hmc_size_p2                 (hmc_size_p2),
        .hmc_tag_p2                  (hmc_tag_p2),
        .hmc_cmd_valid_p2            (hmc_cmd_valid_p2),
        .hmc_cmd_ready_p2            (hmc_cmd_ready_p2),
        .hmc_cmd_p2                  (hmc_cmd_p2),
        .hmc_wr_data_p2              (hmc_wr_data_p2),
        .hmc_wr_data_valid_p2        (hmc_wr_data_valid_p2),
        .hmc_wr_data_ready_p2        (hmc_wr_data_ready_p2),
        .hmc_rd_data_p2              (hmc_rd_data_p2),
        .hmc_rd_data_tag_p2          (hmc_rd_data_tag_p2),
        .hmc_rd_data_valid_p2        (hmc_rd_data_valid_p2),
        .hmc_errstat_p2              (hmc_errstat_p2),
        .hmc_dinv_p2                 (hmc_dinv_p2),
        // hmc p3 --
        .hmc_clk_p3                  (hmc_clk_p3),
        .hmc_addr_p3                 (hmc_addr_p3),
        .hmc_size_p3                 (hmc_size_p3),
        .hmc_tag_p3                  (hmc_tag_p3),
        .hmc_cmd_valid_p3            (hmc_cmd_valid_p3),
        .hmc_cmd_ready_p3            (hmc_cmd_ready_p3),
        .hmc_cmd_p3                  (hmc_cmd_p3),
        .hmc_wr_data_p3              (hmc_wr_data_p3),
        .hmc_wr_data_valid_p3        (hmc_wr_data_valid_p3),
        .hmc_wr_data_ready_p3        (hmc_wr_data_ready_p3),
        .hmc_rd_data_p3              (hmc_rd_data_p3),
        .hmc_rd_data_tag_p3          (hmc_rd_data_tag_p3),
        .hmc_rd_data_valid_p3        (hmc_rd_data_valid_p3),
        .hmc_errstat_p3              (hmc_errstat_p3),
        .hmc_dinv_p3                 (hmc_dinv_p3),
        // hmc p4 --
        .hmc_clk_p4                  (hmc_clk_p4),
        .hmc_addr_p4                 (hmc_addr_p4),
        .hmc_size_p4                 (hmc_size_p4),
        .hmc_tag_p4                  (hmc_tag_p4),
        .hmc_cmd_valid_p4            (hmc_cmd_valid_p4),
        .hmc_cmd_ready_p4            (hmc_cmd_ready_p4),
        .hmc_cmd_p4                  (hmc_cmd_p4),
        .hmc_wr_data_p4              (hmc_wr_data_p4),
        .hmc_wr_data_valid_p4        (hmc_wr_data_valid_p4),
        .hmc_wr_data_ready_p4        (hmc_wr_data_ready_p4),
        .hmc_rd_data_p4              (hmc_rd_data_p4),
        .hmc_rd_data_tag_p4          (hmc_rd_data_tag_p4),
        .hmc_rd_data_valid_p4        (hmc_rd_data_valid_p4),
        .hmc_errstat_p4              (hmc_errstat_p4),
        .hmc_dinv_p4                 (hmc_dinv_p4),


        `ifdef ENABLE_2ND_HMC_LINK
        // hmc p5 --
        .hmc_clk_p5                  (hmc_clk_p5),
        .hmc_addr_p5                 (hmc_addr_p5),
        .hmc_size_p5                 (hmc_size_p5),
        .hmc_tag_p5                  (hmc_tag_p5),
        .hmc_cmd_valid_p5            (hmc_cmd_valid_p5),
        .hmc_cmd_ready_p5            (hmc_cmd_ready_p5),
        .hmc_cmd_p5                  (hmc_cmd_p5),
        .hmc_wr_data_p5              (hmc_wr_data_p5),
        .hmc_wr_data_valid_p5        (hmc_wr_data_valid_p5),
        .hmc_wr_data_ready_p5        (hmc_wr_data_ready_p5),
        .hmc_rd_data_p5              (hmc_rd_data_p5),
        .hmc_rd_data_tag_p5          (hmc_rd_data_tag_p5),
        .hmc_rd_data_valid_p5        (hmc_rd_data_valid_p5),
        .hmc_errstat_p5              (hmc_errstat_p5),
        .hmc_dinv_p5                 (hmc_dinv_p5),
        // hmc p6 --
        .hmc_clk_p6                  (hmc_clk_p6),
        .hmc_addr_p6                 (hmc_addr_p6),
        .hmc_size_p6                 (hmc_size_p6),
        .hmc_tag_p6                  (hmc_tag_p6),
        .hmc_cmd_valid_p6            (hmc_cmd_valid_p6),
        .hmc_cmd_ready_p6            (hmc_cmd_ready_p6),
        .hmc_cmd_p6                  (hmc_cmd_p6),
        .hmc_wr_data_p6              (hmc_wr_data_p6),
        .hmc_wr_data_valid_p6        (hmc_wr_data_valid_p6),
        .hmc_wr_data_ready_p6        (hmc_wr_data_ready_p6),
        .hmc_rd_data_p6              (hmc_rd_data_p6),
        .hmc_rd_data_tag_p6          (hmc_rd_data_tag_p6),
        .hmc_rd_data_valid_p6        (hmc_rd_data_valid_p6),
        .hmc_errstat_p6              (hmc_errstat_p6),
        .hmc_dinv_p6                 (hmc_dinv_p6),
        // hmc p7 --
        .hmc_clk_p7                  (hmc_clk_p7),
        .hmc_addr_p7                 (hmc_addr_p7),
        .hmc_size_p7                 (hmc_size_p7),
        .hmc_tag_p7                  (hmc_tag_p7),
        .hmc_cmd_valid_p7            (hmc_cmd_valid_p7),
        .hmc_cmd_ready_p7            (hmc_cmd_ready_p7),
        .hmc_cmd_p7                  (hmc_cmd_p7),
        .hmc_wr_data_p7              (hmc_wr_data_p7),
        .hmc_wr_data_valid_p7        (hmc_wr_data_valid_p7),
        .hmc_wr_data_ready_p7        (hmc_wr_data_ready_p7),
        .hmc_rd_data_p7              (hmc_rd_data_p7),
        .hmc_rd_data_tag_p7          (hmc_rd_data_tag_p7),
        .hmc_rd_data_valid_p7        (hmc_rd_data_valid_p7),
        .hmc_errstat_p7              (hmc_errstat_p7),
        .hmc_dinv_p7                 (hmc_dinv_p7),
        // hmc p8 --
        .hmc_clk_p8                  (hmc_clk_p8),
        .hmc_addr_p8                 (hmc_addr_p8),
        .hmc_size_p8                 (hmc_size_p8),
        .hmc_tag_p8                  (hmc_tag_p8),
        .hmc_cmd_valid_p8            (hmc_cmd_valid_p8),
        .hmc_cmd_ready_p8            (hmc_cmd_ready_p8),
        .hmc_cmd_p8                  (hmc_cmd_p8),
        .hmc_wr_data_p8              (hmc_wr_data_p8),
        .hmc_wr_data_valid_p8        (hmc_wr_data_valid_p8),
        .hmc_wr_data_ready_p8        (hmc_wr_data_ready_p8),
        .hmc_rd_data_p8              (hmc_rd_data_p8),
        .hmc_rd_data_tag_p8          (hmc_rd_data_tag_p8),
        .hmc_rd_data_valid_p8        (hmc_rd_data_valid_p8),
        .hmc_errstat_p8              (hmc_errstat_p8),
        .hmc_dinv_p8                 (hmc_dinv_p8),
        // hmc p9 --
        .hmc_clk_p9                  (hmc_clk_p9),
        .hmc_addr_p9                 (hmc_addr_p9),
        .hmc_size_p9                 (hmc_size_p9),
        .hmc_tag_p9                  (hmc_tag_p9),
        .hmc_cmd_valid_p9            (hmc_cmd_valid_p9),
        .hmc_cmd_ready_p9            (hmc_cmd_ready_p9),
        .hmc_cmd_p9                  (hmc_cmd_p9),
        .hmc_wr_data_p9              (hmc_wr_data_p9),
        .hmc_wr_data_valid_p9        (hmc_wr_data_valid_p9),
        .hmc_wr_data_ready_p9        (hmc_wr_data_ready_p9),
        .hmc_rd_data_p9              (hmc_rd_data_p9),
        .hmc_rd_data_tag_p9          (hmc_rd_data_tag_p9),
        .hmc_rd_data_valid_p9        (hmc_rd_data_valid_p9),
        .hmc_errstat_p9              (hmc_errstat_p9),
        .hmc_dinv_p9                 (hmc_dinv_p9),

        `endif // ENABLE_2ND_HMC_LINK

        .PicoClk                        (PicoClk),
        .PicoRst                        (PicoRst),
        .PicoAddr                       (PicoAddr),
        .PicoDataIn                     (PicoDataIn),
        .PicoRd                         (PicoRd),
        .PicoWr                         (PicoWr),
        .PicoDataOut                    (PicoDataOut | hmc1_PicoDataOut ),
     `endif  // ENABLE_HMC

        .extra_clk                      ( extra_clk ),
        .clk                            ( s_clk ),
        .rst                            ( s_rst ),
        
        .s_out_en                       ( s_out_en ),
        .s_out_id                       ( s_out_id ),
        .s_out_data                     ( s_out_data ),
        
        .s_in_valid                     ( s_in_valid ),
        .s_in_id                        ( s_in_id[8:0] ),
        .s_in_data                      ( s_in_data[127:0] ),
        
        .s_poll_id                      ( s_poll_id[8:0] ),
        .s_poll_seq                     ( s_poll_seq[31:0] ),
        .s_poll_next_desc               ( s_poll_next_desc[127:0] ),
        .s_poll_next_desc_valid         ( s_poll_next_desc_valid ),
        
        .s_next_desc_rd_en              ( s_next_desc_rd_en ),
        .s_next_desc_rd_id              ( s_next_desc_rd_id[8:0] ),
        
        // user-direct writes
        .direct_rx_valid                ( direct_rx_valid ),
        .user_pci_wr_q_data             ( user_pci_wr_q_data ),
        .user_pci_wr_q_valid            ( user_pci_wr_q_valid ),
        .user_pci_wr_q_en               ( user_pci_wr_q_en ),
        
        .user_pci_wr_data_q_data        ( user_pci_wr_data_q_data ),
        .user_pci_wr_data_q_valid       ( user_pci_wr_data_q_valid ),
        .user_pci_wr_data_q_en          ( user_pci_wr_data_q_en )
    );


`ifdef ENABLE_HMC
    // we use bits 30:28 to differentiate between HMC controllers
    assign hmc0_PicoAddr                = PicoAddr & 32'h8FFFFFFF;
    assign hmc0_PicoRd                  = PicoRd & (PicoAddr[30:28] == 3'b000);
    assign hmc0_PicoWr                  = PicoWr & (PicoAddr[30:28] == 3'b000);
    assign hmc1_PicoAddr                = PicoAddr & 32'h8FFFFFFF;
    assign hmc1_PicoRd                  = PicoRd & (PicoAddr[30:28] == 3'b001);
    assign hmc1_PicoWr                  = PicoWr & (PicoAddr[30:28] == 3'b001);

    // HMC controller for first link
    hmc_top hmc_top (
        .refclk                         (hmc_refclk),

        .lxrxp                          (lxrxp),
        .lxrxn                          (lxrxn),
        .lxtxp                          (lxtxp),
        .lxtxn                          (lxtxn),


        .lxrxps                         (lxrxps),
        .lxtxps                         (lxtxps),

        .ferr_n                         (ferr_n),

        .p_rst_n                        (p_rst_n),

        .scl                            (scl),
        .sda                            (sda),

        .hmc_power_scl                  (hmc_power_scl),
        .hmc_power_sda                  (hmc_power_sda),

        .stratix_power_scl              (stratix_power_scl),
        .stratix_power_sda              (stratix_power_sda),

        .stratix_temp_scl               (stratix_temp_scl),
        .stratix_temp_sda               (stratix_temp_sda),

        .system_power_scl               (system_power_scl),
        .system_power_sda               (system_power_sda),

        .fpga_id                        (fpga_id),
        .extra_clk                      (extra_clk),

        .hmc_tx_clk                     (hmc_tx_clk),
        .hmc_rx_clk                     (hmc_rx_clk),
        .hmc_rst_out                    (hmc_rst),
        .hmc_trained_out                (hmc_trained),

        .clk_p0                      (hmc_clk_p0),
        .addr_p0                     (hmc_addr_p0),
        .size_p0                     (hmc_size_p0),
        .tag_p0                      (hmc_tag_p0),
        .cmd_valid_p0                (hmc_cmd_valid_p0),
        .cmd_ready_p0                (hmc_cmd_ready_p0),
        .cmd_p0                      (hmc_cmd_p0),
        .wr_data_p0                  (hmc_wr_data_p0),
        .wr_data_valid_p0            (hmc_wr_data_valid_p0),
        .wr_data_ready_p0            (hmc_wr_data_ready_p0),

        .rd_data_p0                  (hmc_rd_data_p0),
        .rd_data_tag_p0              (hmc_rd_data_tag_p0),
        .rd_data_valid_p0            (hmc_rd_data_valid_p0),
        .errstat_p0                  (hmc_errstat_p0),
        .dinv_p0                     (hmc_dinv_p0),
        .clk_p1                      (hmc_clk_p1),
        .addr_p1                     (hmc_addr_p1),
        .size_p1                     (hmc_size_p1),
        .tag_p1                      (hmc_tag_p1),
        .cmd_valid_p1                (hmc_cmd_valid_p1),
        .cmd_ready_p1                (hmc_cmd_ready_p1),
        .cmd_p1                      (hmc_cmd_p1),
        .wr_data_p1                  (hmc_wr_data_p1),
        .wr_data_valid_p1            (hmc_wr_data_valid_p1),
        .wr_data_ready_p1            (hmc_wr_data_ready_p1),

        .rd_data_p1                  (hmc_rd_data_p1),
        .rd_data_tag_p1              (hmc_rd_data_tag_p1),
        .rd_data_valid_p1            (hmc_rd_data_valid_p1),
        .errstat_p1                  (hmc_errstat_p1),
        .dinv_p1                     (hmc_dinv_p1),
        .clk_p2                      (hmc_clk_p2),
        .addr_p2                     (hmc_addr_p2),
        .size_p2                     (hmc_size_p2),
        .tag_p2                      (hmc_tag_p2),
        .cmd_valid_p2                (hmc_cmd_valid_p2),
        .cmd_ready_p2                (hmc_cmd_ready_p2),
        .cmd_p2                      (hmc_cmd_p2),
        .wr_data_p2                  (hmc_wr_data_p2),
        .wr_data_valid_p2            (hmc_wr_data_valid_p2),
        .wr_data_ready_p2            (hmc_wr_data_ready_p2),

        .rd_data_p2                  (hmc_rd_data_p2),
        .rd_data_tag_p2              (hmc_rd_data_tag_p2),
        .rd_data_valid_p2            (hmc_rd_data_valid_p2),
        .errstat_p2                  (hmc_errstat_p2),
        .dinv_p2                     (hmc_dinv_p2),
        .clk_p3                      (hmc_clk_p3),
        .addr_p3                     (hmc_addr_p3),
        .size_p3                     (hmc_size_p3),
        .tag_p3                      (hmc_tag_p3),
        .cmd_valid_p3                (hmc_cmd_valid_p3),
        .cmd_ready_p3                (hmc_cmd_ready_p3),
        .cmd_p3                      (hmc_cmd_p3),
        .wr_data_p3                  (hmc_wr_data_p3),
        .wr_data_valid_p3            (hmc_wr_data_valid_p3),
        .wr_data_ready_p3            (hmc_wr_data_ready_p3),

        .rd_data_p3                  (hmc_rd_data_p3),
        .rd_data_tag_p3              (hmc_rd_data_tag_p3),
        .rd_data_valid_p3            (hmc_rd_data_valid_p3),
        .errstat_p3                  (hmc_errstat_p3),
        .dinv_p3                     (hmc_dinv_p3),
        .clk_p4                      (hmc_clk_p4),
        .addr_p4                     (hmc_addr_p4),
        .size_p4                     (hmc_size_p4),
        .tag_p4                      (hmc_tag_p4),
        .cmd_valid_p4                (hmc_cmd_valid_p4),
        .cmd_ready_p4                (hmc_cmd_ready_p4),
        .cmd_p4                      (hmc_cmd_p4),
        .wr_data_p4                  (hmc_wr_data_p4),
        .wr_data_valid_p4            (hmc_wr_data_valid_p4),
        .wr_data_ready_p4            (hmc_wr_data_ready_p4),

        .rd_data_p4                  (hmc_rd_data_p4),
        .rd_data_tag_p4              (hmc_rd_data_tag_p4),
        .rd_data_valid_p4            (hmc_rd_data_valid_p4),
        .errstat_p4                  (hmc_errstat_p4),
        .dinv_p4                     (hmc_dinv_p4),

        .PicoClk                        (PicoClk),
        .PicoRst                        (PicoRst),
        .PicoAddr                       (hmc0_PicoAddr),
        .PicoDataIn                     (PicoDataIn),
        .PicoRd                         (hmc0_PicoRd),
        .PicoWr                         (hmc0_PicoWr),
        .PicoDataOut                    (PicoDataOut)
    );

`ifdef ENABLE_2ND_HMC_LINK

    // HMC controller for 2nd link
    hmc_top #(
        .HMC_LINK_NUMBER  ( 1                    )
    ) hmc_top_1 (
        .refclk           ( hmc1_refclk          ) ,

        .lxrxp            ( hmc1_lxrxp           ) ,
        .lxrxn            ( hmc1_lxrxn           ) ,
        .lxtxp            ( hmc1_lxtxp           ) ,
        .lxtxn            ( hmc1_lxtxn           ) ,

        .lxrxps           ( hmc1_lxrxps          ) ,
        .lxtxps           ( hmc1_lxtxps          ) ,

        .extra_clk        ( extra_clk            ) ,

        .hmc_tx_clk       ( hmc1_tx_clk          ) ,
        .hmc_rx_clk       ( hmc1_rx_clk          ) ,
        .hmc_rst_out      ( hmc1_rst             ) ,
        .hmc_trained_out  ( hmc1_trained         ) ,

        .clk_p0           ( hmc_clk_p5           ) ,
        .addr_p0          ( hmc_addr_p5          ) ,
        .size_p0          ( hmc_size_p5          ) ,
        .tag_p0           ( hmc_tag_p5           ) ,
        .cmd_valid_p0     ( hmc_cmd_valid_p5     ) ,
        .cmd_ready_p0     ( hmc_cmd_ready_p5     ) ,
        .cmd_p0           ( hmc_cmd_p5           ) ,
        .wr_data_p0       ( hmc_wr_data_p5       ) ,
        .wr_data_valid_p0 ( hmc_wr_data_valid_p5 ) ,
        .wr_data_ready_p0 ( hmc_wr_data_ready_p5 ) ,

        .rd_data_p0       ( hmc_rd_data_p5       ) ,
        .rd_data_tag_p0   ( hmc_rd_data_tag_p5   ) ,
        .rd_data_valid_p0 ( hmc_rd_data_valid_p5 ) ,
        .errstat_p0       ( hmc_errstat_p5       ) ,
        .dinv_p0          ( hmc_dinv_p5          ) ,
        .clk_p1           ( hmc_clk_p6           ) ,
        .addr_p1          ( hmc_addr_p6          ) ,
        .size_p1          ( hmc_size_p6          ) ,
        .tag_p1           ( hmc_tag_p6           ) ,
        .cmd_valid_p1     ( hmc_cmd_valid_p6     ) ,
        .cmd_ready_p1     ( hmc_cmd_ready_p6     ) ,
        .cmd_p1           ( hmc_cmd_p6           ) ,
        .wr_data_p1       ( hmc_wr_data_p6       ) ,
        .wr_data_valid_p1 ( hmc_wr_data_valid_p6 ) ,
        .wr_data_ready_p1 ( hmc_wr_data_ready_p6 ) ,

        .rd_data_p1       ( hmc_rd_data_p6       ) ,
        .rd_data_tag_p1   ( hmc_rd_data_tag_p6   ) ,
        .rd_data_valid_p1 ( hmc_rd_data_valid_p6 ) ,
        .errstat_p1       ( hmc_errstat_p6       ) ,
        .dinv_p1          ( hmc_dinv_p6          ) ,
        .clk_p2           ( hmc_clk_p7           ) ,
        .addr_p2          ( hmc_addr_p7          ) ,
        .size_p2          ( hmc_size_p7          ) ,
        .tag_p2           ( hmc_tag_p7           ) ,
        .cmd_valid_p2     ( hmc_cmd_valid_p7     ) ,
        .cmd_ready_p2     ( hmc_cmd_ready_p7     ) ,
        .cmd_p2           ( hmc_cmd_p7           ) ,
        .wr_data_p2       ( hmc_wr_data_p7       ) ,
        .wr_data_valid_p2 ( hmc_wr_data_valid_p7 ) ,
        .wr_data_ready_p2 ( hmc_wr_data_ready_p7 ) ,

        .rd_data_p2       ( hmc_rd_data_p7       ) ,
        .rd_data_tag_p2   ( hmc_rd_data_tag_p7   ) ,
        .rd_data_valid_p2 ( hmc_rd_data_valid_p7 ) ,
        .errstat_p2       ( hmc_errstat_p7       ) ,
        .dinv_p2          ( hmc_dinv_p7          ) ,
        .clk_p3           ( hmc_clk_p8           ) ,
        .addr_p3          ( hmc_addr_p8          ) ,
        .size_p3          ( hmc_size_p8          ) ,
        .tag_p3           ( hmc_tag_p8           ) ,
        .cmd_valid_p3     ( hmc_cmd_valid_p8     ) ,
        .cmd_ready_p3     ( hmc_cmd_ready_p8     ) ,
        .cmd_p3           ( hmc_cmd_p8           ) ,
        .wr_data_p3       ( hmc_wr_data_p8       ) ,
        .wr_data_valid_p3 ( hmc_wr_data_valid_p8 ) ,
        .wr_data_ready_p3 ( hmc_wr_data_ready_p8 ) ,

        .rd_data_p3       ( hmc_rd_data_p8       ) ,
        .rd_data_tag_p3   ( hmc_rd_data_tag_p8   ) ,
        .rd_data_valid_p3 ( hmc_rd_data_valid_p8 ) ,
        .errstat_p3       ( hmc_errstat_p8       ) ,
        .dinv_p3          ( hmc_dinv_p8          ) ,
        .clk_p4           ( hmc_clk_p9           ) ,
        .addr_p4          ( hmc_addr_p9          ) ,
        .size_p4          ( hmc_size_p9          ) ,
        .tag_p4           ( hmc_tag_p9           ) ,
        .cmd_valid_p4     ( hmc_cmd_valid_p9     ) ,
        .cmd_ready_p4     ( hmc_cmd_ready_p9     ) ,
        .cmd_p4           ( hmc_cmd_p9           ) ,
        .wr_data_p4       ( hmc_wr_data_p9       ) ,
        .wr_data_valid_p4 ( hmc_wr_data_valid_p9 ) ,
        .wr_data_ready_p4 ( hmc_wr_data_ready_p9 ) ,

        .rd_data_p4       ( hmc_rd_data_p9       ) ,
        .rd_data_tag_p4   ( hmc_rd_data_tag_p9   ) ,
        .rd_data_valid_p4 ( hmc_rd_data_valid_p9 ) ,
        .errstat_p4       ( hmc_errstat_p9       ) ,
        .dinv_p4          ( hmc_dinv_p9          ) ,

        .PicoClk          ( PicoClk              ) ,
        .PicoRst          ( PicoRst              ) ,
        .PicoAddr         ( hmc1_PicoAddr        ) ,
        .PicoDataIn       ( PicoDataIn           ) ,
        .PicoRd           ( hmc1_PicoRd          ) ,
        .PicoWr           ( hmc1_PicoWr          ) ,
        .PicoDataOut      ( hmc1_PicoDataOut     )
    );
`else   // NOT ENABLE_2ND_HMC_LINK
    assign  hmc1_PicoDataOut            = 128'h0;
`endif  // ENABLE_2ND_HMC_LINK
`endif  // ENABLE_HMC

    //------------------------------------------------------
    // LED
    //  - same logic we use on the EX700 for causing color
    //    change.
    //------------------------------------------------------
`ifdef LED
    RGBBlink # (
        .LED_NUM    (LED_NUM)
    ) RGBBlink (
        .extra_clk  (extra_clk),
        .led_r      (led_r    ),
        .led_g      (led_g    ),
        .led_b      (led_b    )
    );
    
`endif // LED

endmodule


