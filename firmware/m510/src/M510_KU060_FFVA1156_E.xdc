##-----------------------------------------------------------------------------
##
## (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##-----------------------------------------------------------------------------
##
## Project    : Ultrascale FPGA Gen3 Integrated Block for PCI Express
## File       : xilinx_pcie3_uscale_ep_x8g2.xdc
## Version    : 3.1
##-----------------------------------------------------------------------------
#
# User Configuration
# Link Width   - x8
# Link Speed   - Gen2
# Family       - virtexu
# Part         - xcvu095
# Package      - ffvd1924
# Speed grade  - -2
# PCIe Block   - X0Y0
###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]
set_false_path -from [get_ports sys_reset_n]

###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################
create_clock -period 5.000 -name extra_clk [get_ports extra_clk_p]

###############################################################################
# Pinout and Related I/O Constraints
###############################################################################
set_property IOSTANDARD LVDS [get_ports extra_clk_p]
set_property PACKAGE_PIN AK31 [get_ports extra_clk_p]
set_property PACKAGE_PIN AK32 [get_ports extra_clk_n]
set_property IOSTANDARD LVDS [get_ports extra_clk_n]

#LED
set_property IOSTANDARD LVCMOS18 [get_ports {led_r[0]}]
set_property PACKAGE_PIN D11 [get_ports {led_r[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_g[0]}]
set_property PACKAGE_PIN B11 [get_ports {led_g[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_b[0]}]
set_property PACKAGE_PIN B10 [get_ports {led_b[0]}]

# TODO: in the future, we should probably set an output delay for these
#set_output_delay -clock [get_clocks extra_clk] 0 [get_ports {led_r[0]}]
#set_output_delay -clock [get_clocks extra_clk] 0 [get_ports {led_g[0]}]
#set_output_delay -clock [get_clocks extra_clk] 0 [get_ports {led_b[0]}]

###############################################################################
# User Physical Constraints
###############################################################################

#Pblock for PicoFramework
create_pblock pblock_PicoFramework
add_cells_to_pblock [get_pblocks pblock_PicoFramework] [get_cells -quiet [list PicoFramework]]
resize_pblock [get_pblocks pblock_PicoFramework] -add {SLICE_X124Y0:SLICE_X142Y110}
resize_pblock [get_pblocks pblock_PicoFramework] -add {RAMB18_X15Y0:RAMB18_X17Y43}
resize_pblock [get_pblocks pblock_PicoFramework] -add {RAMB36_X15Y0:RAMB36_X17Y21}

###############################################################################
# Pinout and Related I/O Constraints
###############################################################################
##### SYS RESET###########
set_property LOC PCIE_3_1_X0Y0 [get_cells PicoFramework/core/pcie3_ultrascale_0_i/inst/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]
set_property PACKAGE_PIN K22 [get_ports sys_reset_n]
set_property PULLUP true [get_ports sys_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset_n]

##### REFCLK_IBUF###########
set_property PACKAGE_PIN AB5 [get_ports sys_clk_n]
set_property LOC BUFG_GT_X1Y36 [get_cells PicoFramework/core/pcie3_ultrascale_0_i/inst/gt_top_i/phy_clk_i/bufg_gt_pclk]
set_property LOC BUFG_GT_X1Y37 [get_cells PicoFramework/core/pcie3_ultrascale_0_i/inst/gt_top_i/phy_clk_i/bufg_gt_userclk]
set_property LOC BUFG_GT_X1Y38 [get_cells PicoFramework/core/pcie3_ultrascale_0_i/inst/gt_top_i/phy_clk_i/bufg_gt_coreclk]

###############################################################################
# Flash Programming Settings: Uncomment as required by your design
# Items below between < > must be updated with correct values to work properly.
###############################################################################

# these are some general configuration settings
# in the future, these should probably be in their own XDC file
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
# this is just a dummy code that we want to be able to read when we load up the FPGA
#set_property BITSTREAM.CONFIG.USERID 0xCAFE0850 [current_design]
#
# SPI Flash Programming
set_property CONFIG_MODE SPIx8 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
#set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
# Example PROM Generation command that should be executed from the Tcl Console
#write_cfgmem -format mcs -interface spix4 -size 128 -loadbit "up 0x0 <inputBitfile.bit>" <outputBitfile.bit>


set_clock_groups -asynchronous -group [get_clocks clk_out1_mmcm] -group [get_clocks clk_out2_mmcm]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[3]}] -group [get_clocks clk_out2_mmcm]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[3]}] -group [get_clocks clk_out1_mmcm]

create_pblock u0
add_cells_to_pblock [get_pblocks u0] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[0].descrack_stream_region}]]
resize_pblock [get_pblocks u0] -add {CLOCKREGION_X5Y2:CLOCKREGION_X5Y2}

create_pblock u1
add_cells_to_pblock [get_pblocks u1] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[1].descrack_stream_region}]]
resize_pblock [get_pblocks u1] -add {CLOCKREGION_X5Y3:CLOCKREGION_X5Y3}

create_pblock u2
add_cells_to_pblock [get_pblocks u2] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[2].descrack_stream_region}]]
resize_pblock [get_pblocks u2] -add {CLOCKREGION_X5Y4:CLOCKREGION_X5Y4}

create_pblock u3
add_cells_to_pblock [get_pblocks u3] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[3].descrack_stream_region}]]
resize_pblock [get_pblocks u3] -add {CLOCKREGION_X4Y4:CLOCKREGION_X4Y4}

create_pblock u4
add_cells_to_pblock [get_pblocks u4] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[4].descrack_stream_region}]]
resize_pblock [get_pblocks u4] -add {CLOCKREGION_X3Y4:CLOCKREGION_X3Y4}

create_pblock u5
add_cells_to_pblock [get_pblocks u5] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[5].descrack_stream_region}]]
resize_pblock [get_pblocks u5] -add {CLOCKREGION_X2Y4:CLOCKREGION_X2Y4}

create_pblock u6
add_cells_to_pblock [get_pblocks u6] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[6].descrack_stream_region}]]
resize_pblock [get_pblocks u6] -add {CLOCKREGION_X1Y4:CLOCKREGION_X1Y4}

create_pblock u7
add_cells_to_pblock [get_pblocks u7] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[7].descrack_stream_region}]]
resize_pblock [get_pblocks u7] -add {CLOCKREGION_X0Y4:CLOCKREGION_X0Y4}

create_pblock u8
add_cells_to_pblock [get_pblocks u8] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[8].descrack_stream_region}]]
resize_pblock [get_pblocks u8] -add {CLOCKREGION_X0Y3:CLOCKREGION_X0Y3}

create_pblock u9
add_cells_to_pblock [get_pblocks u9] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[9].descrack_stream_region}]]
resize_pblock [get_pblocks u9] -add {CLOCKREGION_X1Y3:CLOCKREGION_X1Y3}

create_pblock u10
add_cells_to_pblock [get_pblocks u10] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[10].descrack_stream_region}]]
resize_pblock [get_pblocks u10] -add {CLOCKREGION_X2Y3:CLOCKREGION_X2Y3}

create_pblock u11
add_cells_to_pblock [get_pblocks u11] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[11].descrack_stream_region}]]
resize_pblock [get_pblocks u11] -add {CLOCKREGION_X3Y3:CLOCKREGION_X3Y3}

create_pblock u12
add_cells_to_pblock [get_pblocks u12] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[12].descrack_stream_region}]]
resize_pblock [get_pblocks u12] -add {CLOCKREGION_X4Y3:CLOCKREGION_X4Y3}

create_pblock u13
add_cells_to_pblock [get_pblocks u13] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[13].descrack_stream_region}]]
resize_pblock [get_pblocks u13] -add {CLOCKREGION_X4Y2:CLOCKREGION_X4Y2}

create_pblock u14
add_cells_to_pblock [get_pblocks u14] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[14].descrack_stream_region}]]
resize_pblock [get_pblocks u14] -add {CLOCKREGION_X3Y2:CLOCKREGION_X3Y2}

create_pblock u15
add_cells_to_pblock [get_pblocks u15] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[15].descrack_stream_region}]]
resize_pblock [get_pblocks u15] -add {CLOCKREGION_X2Y2:CLOCKREGION_X2Y2}

create_pblock u16
add_cells_to_pblock [get_pblocks u16] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[16].descrack_stream_region}]]
resize_pblock [get_pblocks u16] -add {CLOCKREGION_X1Y2:CLOCKREGION_X1Y2}

create_pblock u17
add_cells_to_pblock [get_pblocks u17] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[17].descrack_stream_region}]]
resize_pblock [get_pblocks u17] -add {CLOCKREGION_X0Y2:CLOCKREGION_X0Y2}

create_pblock u18
add_cells_to_pblock [get_pblocks u18] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[18].descrack_stream_region}]]
resize_pblock [get_pblocks u18] -add {CLOCKREGION_X0Y1:CLOCKREGION_X0Y1}

create_pblock u19
add_cells_to_pblock [get_pblocks u19] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[19].descrack_stream_region}]]
resize_pblock [get_pblocks u19] -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y0}

create_pblock u20
add_cells_to_pblock [get_pblocks u20] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[20].descrack_stream_region}]]
resize_pblock [get_pblocks u20] -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y0}

create_pblock u21
add_cells_to_pblock [get_pblocks u21] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[21].descrack_stream_region}]]
resize_pblock [get_pblocks u21] -add {CLOCKREGION_X1Y1:CLOCKREGION_X1Y1}

create_pblock u22
add_cells_to_pblock [get_pblocks u22] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[22].descrack_stream_region}]]
resize_pblock [get_pblocks u22] -add {CLOCKREGION_X2Y1:CLOCKREGION_X2Y1}

create_pblock u23
add_cells_to_pblock [get_pblocks u23] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[23].descrack_stream_region}]]
resize_pblock [get_pblocks u23] -add {CLOCKREGION_X2Y0:CLOCKREGION_X2Y0}

create_pblock u24
add_cells_to_pblock [get_pblocks u24] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[24].descrack_stream_region}]]
resize_pblock [get_pblocks u24] -add {CLOCKREGION_X3Y0:CLOCKREGION_X3Y0}

create_pblock u25
add_cells_to_pblock [get_pblocks u25] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[25].descrack_stream_region}]]
resize_pblock [get_pblocks u25] -add {CLOCKREGION_X3Y1:CLOCKREGION_X3Y1}

create_pblock u26
add_cells_to_pblock [get_pblocks u26] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[26].descrack_stream_region}]]
resize_pblock [get_pblocks u26] -add {CLOCKREGION_X4Y1:CLOCKREGION_X4Y1}

create_pblock u27
add_cells_to_pblock [get_pblocks u27] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[27].descrack_stream_region}]]
resize_pblock [get_pblocks u27] -add {CLOCKREGION_X4Y0:CLOCKREGION_X4Y0}

create_pblock u28a
add_cells_to_pblock [get_pblocks u28a] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[28].descrack_stream_region/des_stream_cores[0].descrack_stream_core} {UserWrapper/UserModule/des_stream_regions[28].descrack_stream_region/des_stream_cores[1].descrack_stream_core}]]
resize_pblock [get_pblocks u28a] -add {CLOCKREGION_X5Y0:CLOCKREGION_X5Y0}

create_pblock u28b
#add_cells_to_pblock [get_pblocks u28b] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[28].descrack_stream_region/des_stream_cores[2].descrack_stream_core} {UserWrapper/UserModule/des_stream_regions[28].descrack_stream_region/des_stream_cores[3].descrack_stream_core}]]
add_cells_to_pblock [get_pblocks u28b] [get_cells -quiet [list {UserWrapper/UserModule/des_stream_regions[28].descrack_stream_region/des_stream_cores[2].descrack_stream_core}]]
resize_pblock [get_pblocks u28b] -add {CLOCKREGION_X5Y1:CLOCKREGION_X5Y1}
