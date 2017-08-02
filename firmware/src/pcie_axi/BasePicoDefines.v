// BasePicoDefines.v - default firmware settings for the AXI-based PCIe boards
// Copyright 2007, Pico Computing, Inc.

`ifndef _BASE_PICO_DEFINES_V
`define _BASE_PICO_DEFINES_V

//-------------------- Version 5.0.7.A ----------------------
`define VERSION_MAJOR                8'h05
`define VERSION_MINOR                8'h00
`define VERSION_RELEASE              8'h07
`ifndef VERSION_COUNTER
   `define VERSION_COUNTER           8'h0A
`endif

`define ENABLE_BUS_MASTERING
`define ENABLE_JTAG_LOOPBACK
`define ENABLE_SYSTEM_MONITOR

`ifdef ENABLE_HMC
    `define HMC_STREAM_ID           116
    `define STREAM116_IN_WIDTH      128
    `define STREAM116_OUT_WIDTH     128
`endif
`ifdef PICO_MODEL_M510
    `define XILINX_ULTRASCALE
    `define LED
`endif // PICO_MODEL_M510

`ifdef PICO_MODEL_M505
    `define XILINX_PLX_LINKING_WORKAROUND
`endif //PICO_MODEL_M505

`ifdef PICO_MODEL_M503
`undef ENABLE_FLASH
`endif //M503

`define MAGIC_NUM_ADDR               32'hFFE0000C // address of magic number port
`define PICO_MAGIC_NUM               16'h5397     // value of magic number
`ifndef BITFILE_SIGNATURE
   `define BITFILE_SIGNATURE         12'h193      // unique value for this bit file
`endif
`define VERSION_ADDRESS              32'hFFE00044 // address of version information port
`define IMAGE_CAPABILITIES_ADDRESS   32'hFFE0004C // address of capabilities port
`define PICOBUS_INFO_ADDRESS         32'hFFE00050
`define CARD_MODEL_ADDRESS           32'hFFE00054
`define STATUS_ADDRESS               32'hFFE0000C
`define FLASH_READ_ASYNCH            32'hFFE000A0 //R:returns status, data, and adr from flash read
                                                  //W: specifies 32 bit address for read

`define SYSTEM_MONITOR_ADDR          32'hFFD00000

`define PICOBUS_RST_ADDR             32'hFFD00100 // low bit asserts the PicoBus reset signal

`define STREAM_ID_MASK_ADDR          32'hFFD00110 // sets the mask for the stream id, which determines how many streams are handled.

`define MAX_WR_PKT_ADDR              32'hFFD00120 // the maximum (write) packet size for pci

`define USER_MODULE_RESET_RESERVED   32'hFFC00000 // gme: don't use this by name. it's just here to reserve the addr.

//--------------------------------- Card Capabilities
// Capability definitions used to tell software what the fpga capabilities have been synthesized.
//   For example: `define IMAGE_CAPABILITIES (`PICO_CAP_FLASH | `PICO_CAP_TURBOLOADER)

`ifdef ENABLE_FLASH
   `define PICO_CAP_FLASH           32'h0001             //Can access flash ROM from PC side
`else
   `define PICO_CAP_FLASH           32'h0000             //Can access flash ROM from PC side
`endif

`ifdef ENABLE_TURBOLOADER
   `define PICO_CAP_TURBOLOADER     32'h0002             //Has access to TurboLoader.
`else
   `define PICO_CAP_TURBOLOADER     32'h0000
`endif

`ifdef ENABLE_KEYHOLE
   `define PICO_CAP_KEYHOLE         32'h0004             //Supports keyhole.
`else
   `define PICO_CAP_KEYHOLE         32'h0000             //Does not support keyhole.
`endif

`ifdef ENABLE_BUS_MASTERING
   `define PICO_CAP_BUSMASTERING    32'h0010             //Image has bus mastering
`else
   `define PICO_CAP_BUSMASTERING    32'h0000             //Image does not have bus mastering
`endif

`ifdef ENABLE_ADC
   `define PICO_CAP_ADC             32'h0020             //Image has A/D (same bit!)
`else
`ifdef ENABLE_DAC
   `define PICO_CAP_ADC             32'h0020             //Image has D/A (same bit!)
`else 
   `define PICO_CAP_ADC             32'h0000             //Image does not have A/D or D/A
`endif
`endif

`ifdef ENABLE_PIC
   `define PICO_CAP_PIC             32'h0040             //Image has PIC access
`else 
   `define PICO_CAP_PIC             32'h0000             //Image does not have PIC access
`endif

`ifdef ENABLE_JTAG_SPY
   `define PICO_CAP_JTAG_SPY        32'h0080             //Image will capture JTAG access through LPT port
`else 
   `define PICO_CAP_JTAG_SPY        32'h0000             //Image does not have JTAG capture
`endif

`ifdef ENABLE_ETH
   `define PICO_CAP_ETHERNET        32'h0100             //Image has ethernet capability
`else 
   `define PICO_CAP_ETHERNET        32'h0000             //Image does not have Ethernet capability
`endif

   `define PICO_CAP_XPORT_RAM       32'h0000             //Xilinx multiport RAM (0x0800 bit)

`ifdef PICOBUS32                                        // this bit is only used on pre-version 5.x firmware.
   `define PICO_CAP_PICOBUS32       32'h0200
`else
   `define PICO_CAP_PICOBUS32       32'h0000
`endif

`ifdef PICOBUS_WIDTH                                    // with firmware v5, the entire user picobus is optional. this bit only applies to versions >= 5.x
    `define PICO_CAP_PICOBUS        32'h0400
`else
    `define PICO_CAP_PICOBUS        32'h0000
`endif

`define IMAGE_CAPABILITIES  (`PICO_CAP_FLASH | \
                             `PICO_CAP_TURBOLOADER | \
                             `PICO_CAP_KEYHOLE | \
                             `PICO_CAP_BUSMASTERING | \
                             `PICO_CAP_ADC | \
                             `PICO_CAP_PIC | \
                             `PICO_CAP_JTAG_SPY | \
                             `PICO_CAP_ETHERNET | \
                             `PICO_CAP_XPORT_RAM | \
                             `PICO_CAP_PICOBUS32 | \
                             `PICO_CAP_PICOBUS)

//--------Defines associated with channel allocation -----------------------------------------------
`define BM_CHANNEL_BASE           32'h10100000          //address of BM devices is 0x1010,0000 thru 0x7FFF,FFFF
`define BM_CHANNEL_SIZE           32'h100000            //size of each device is one megabyte
`define BM_MAX_CHANNELS           1791                  //number of one meg channels that fit in the above address space.
`define BM_CHANNEL_STATUS_BASE    32'h10000010          //channel #1 statuses start at this address.
`define BM_CHANNEL_STATUS_SIZE    32'h10                //each channel has space for 4 * 32bit registers.
`define BM_ADDR_FROM_CHANNEL(channel)   (`BM_CHANNEL_BASE         + (channel-1) * `BM_CHANNEL_SIZE)
`define BM_STATUS_FROM_CHANNEL(channel) (`BM_CHANNEL_STATUS_BASE  + (channel-1) * `BM_CHANNEL_STATUS_SIZE)
`define BM_READ_STATUS_SIGNATURE  6'h26                 //signature of BM read  status register.
`define BM_WRITE_STATUS_SIGNATURE 6'h22                 //signature of BM write status register.
`define CHANNEL_READ_STATUS_ADDR(ch)  (`BM_CHANNEL_STATUS_BASE  + (ch-1) * `BM_CHANNEL_STATUS_SIZE)
`define CHANNEL_WRITE_STATUS_ADDR(ch) (`BM_CHANNEL_STATUS_BASE  + (ch-1) * `BM_CHANNEL_STATUS_SIZE + 4)
`define MAKE_CHANNEL_READ_STATUS(ch,avail)  ({`BM_READ_STATUS_SIGNATURE,  6'h0, avail})
`define MAKE_CHANNEL_WRITE_STATUS(ch,avail) ({`BM_WRITE_STATUS_SIGNATURE, 6'h0, avail})

//--------Defines associated with stream allocation ------------------------------------------------
// (note that since streams are an of extension of channels, they use the same addresses.)
`define PICO_STREAM_BASE        (`BM_CHANNEL_BASE)
`define PICO_STREAM_SIZE        (`BM_CHANNEL_SIZE)
`define PICO_MAX_STREAMS        (`BM_MAX_CHANNELS)
`define PICO_STREAM_STATUS_BASE (`BM_CHANNEL_STATUS_BASE)
`define PICO_STREAM_STATUS_SIZE (`BM_CHANNEL_STATUS_SIZE)

//--------------------------Impulse C------------------------------------------------------------------------
`define IMPULSEC_GLOBAL_RST_ADDR     32'h08000000       // 4 bytes (1 word) wide global reset register for Impulse C

//--------------------------Memory---------------------------------------------------------------------------
`ifdef PICO_DDR3
    // If the DDR3 Memory is being used, we need to enable some streams to connect it to PCIe
    `ifdef PICO_MODEL_M503
		// stream to DDR3 0
        `define DDR3_STREAM_ID_0    124
        `define STREAM124_IN_WIDTH  128
        `define STREAM124_OUT_WIDTH 128
		// stream to DDR3 1
        `define DDR3_STREAM_ID_1    123
        `define STREAM123_IN_WIDTH  128
        `define STREAM123_OUT_WIDTH 128
    `else // PICO_MODEL_M501 & PICO_MODEL_M505
        `define DDR3_STREAM_ID      124
        `define STREAM124_IN_WIDTH  128
        `define STREAM124_OUT_WIDTH 128
    `endif

    // Control the number of AXI interconnect ports available to the user
    `ifdef PICO_7_AXI_MASTERS
        `define PICO_AXI_MASTERS 7
        `define PICO_AXI_PORT_7
        `define PICO_AXI_PORT_6
        `define PICO_AXI_PORT_5
        `define PICO_AXI_PORT_4
        `define PICO_AXI_PORT_3
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_6_AXI_MASTERS
        `define PICO_AXI_MASTERS 6
        `define PICO_AXI_PORT_6
        `define PICO_AXI_PORT_5
        `define PICO_AXI_PORT_4
        `define PICO_AXI_PORT_3
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_5_AXI_MASTERS
        `define PICO_AXI_MASTERS 5
        `define PICO_AXI_PORT_5
        `define PICO_AXI_PORT_4
        `define PICO_AXI_PORT_3
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_4_AXI_MASTERS
        `define PICO_AXI_MASTERS 4
        `define PICO_AXI_PORT_4
        `define PICO_AXI_PORT_3
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_3_AXI_MASTERS
        `define PICO_AXI_MASTERS 3
        `define PICO_AXI_PORT_3
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_2_AXI_MASTERS
        `define PICO_AXI_MASTERS 2
        `define PICO_AXI_PORT_2
        `define PICO_AXI_PORT_1
    `elsif PICO_1_AXI_MASTERS
        `define PICO_AXI_MASTERS 1
        `define PICO_AXI_PORT_1
    `else
		`define PICO_0_AXI_MASTERS
		`define PICO_AXI_MASTERS 0
	`endif

    // determine if we want to use the MIG simulation model or the actual MIG
    // Note: MIG simulation model should only be used if SIMULATION is defined
    // and if PICO_SIM_MIG is defined
    `ifdef SIMULATION
        `ifdef PICO_SIM_MIG
            `define PICO_MIG_MODULE PicoMIG
        `else
            `define PICO_MIG_MODULE mig_DDR3
        `endif
    `else
        `define PICO_MIG_MODULE mig_DDR3
    `endif

`endif // PICO_DDR3

`ifdef PICO_MODEL_M501
    `define PICO_MODEL_NUM  32'h501
`elsif PICO_MODEL_M503
    `define PICO_MODEL_NUM  32'h503
`elsif PICO_MODEL_M505
    `define PICO_MODEL_NUM  32'h505
`elsif PICO_MODEL_M506
    `define PICO_MODEL_NUM  32'h506
`elsif PICO_MODEL_M510
    `define PICO_MODEL_NUM  32'h510
`elsif PICO_MODEL_EX800
    `define PICO_MODEL_NUM  32'h800
`else
    `ERROR_NO_PICO_MODEL
`endif

`endif // _BASE_PICO_DEFINES_V

