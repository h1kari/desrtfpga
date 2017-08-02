// SystemMonitor32.v
// Exposes the raw system monitor values for internal voltage, auxiliary voltage, and temperature.
// Calculate the "real" values from the raw values as follows:
//     Voltage = (RAW_VALUE / 1024) * 3
//     Degrees Celsius = RAW_VALUE * 503.975 / 1024 - 273.15

// The system monitor is placed in auto-sequence mode so it continuously samples all the sensors we want.
// We just need to watch the end-of-channel (eoc) flag to know when to grab data. When that goes high, we send the
// channel number to the address port. A few cycles later, the data shows up and drdy goes high, at which point we latch it.

`include "PicoDefines.v"

module SystemMonitor32 (
    input              s_clk, // Stream Clock - nominally 250Mhz
    input              s_rst, // Stream Clock synchronous reset
    /* PicoBus ports */
    input              PicoRst,
    input              PicoClk,
    input      [31:0]  PicoAddr,
    input      [31:0] PicoDataIn,
    output reg [31:0] PicoDataOut,
    input              PicoRd,
    input              PicoWr,
    output     [9:0]   temp
);

    assign temp = r_temp;

localparam S_PB_RATIO = 62;

reg [9:0] vccint, vccaux, vp, r_temp;
wire [15:0] dobus;
wire [5:0] channel;
wire eoc, drdy;
reg [S_PB_RATIO+1:0] drdy_vec;
reg s_drdy;

// AC-505 Kintex 7 & AC-510 Kintex UltraScale dclk can be 8-250MHz. 
// The internal ADC clk can be 1-5.2MHz for Kintex UltraScale and 
// 1-26Mhz for Kintex 7.
// Bits 8-15 of INIT_42 specify the divisor. 
// We'll use the 250Mhz stream clk (s_clk) for dclk and 
// we'll adjust the ADC divisor to 64 give us a valid ~3.9Mhz internal ADC clk.
// *** the e17 PicoClk is 62.5MHz and the m501 is 250MHz. (STALE COMMENT???) ***
// Note: The PicoClk for the 5.5.0.0 firmare release is 8Mhz 
`ifdef ALTERA_FPGA
   (* noprune = 1 *)
   (* syn_preserve = 1 *)
`else
   (* S = "TRUE" *)
   (* KEEP = "TRUE" *)
   (* DONT_TOUCH = "TRUE" *)
`endif
reg [5:0] PicoClkCnt;
reg drdy_meta1, drdy_meta2, pb_drdy;

always @(posedge PicoClk) PicoClkCnt <= PicoClkCnt + 1;

always @(posedge PicoClk) begin
    if (PicoRd & (PicoAddr[31:0] == (`SYSTEM_MONITOR_ADDR+4))) begin
        PicoDataOut[31:0] <= {6'h0, vp[9:0],
                              6'h0, vccaux[9:0]};
    end else if (PicoRd & (PicoAddr[31:0] == (`SYSTEM_MONITOR_ADDR))) begin
        PicoDataOut[31:0] <= {6'h0, vccint[9:0],
                              6'h0, r_temp[9:0]};
    end else begin
        PicoDataOut[31:0] <= 32'h0;
    end
    // captue channel data
    if (pb_drdy) begin
        if (channel[5:0] == 6'h0) r_temp <= dobus[15:6];
        if (channel[5:0] == 6'h1) vccint <= dobus[15:6];
        if (channel[5:0] == 6'h2) vccaux <= dobus[15:6];
        if (channel[5:0] == 6'h3) vp <= dobus[15:6];
    end
    // Synchronize the drdy signal to pico clock domain
    drdy_meta1 <= s_drdy;
    drdy_meta2 <= drdy_meta1;
    pb_drdy <= drdy_meta2;
end

// Pulse extend the drdy signal for crossing from the system to PicoBus clock domain
always @(posedge s_clk) begin
    if (s_rst) begin
       drdy_vec <= {S_PB_RATIO+2{1'b0}};
    end else begin
       drdy_vec <= {drdy_vec[S_PB_RATIO:0], drdy};
    end
    s_drdy <= |drdy_vec;
end

`ifdef XILINX_ULTRASCALE

// instantiation based on example from the V5 user guide.
SYSMONE1 #(
    .INIT_40(16'h3000), // Configuration register 0 (0x3000 means average 256 samples)
    .INIT_41(16'h2FDE), // Configuration register 1 (low bit disable overtemp shutdown)
    .INIT_42(16'h4000), // Configuration register 2 // ADC clock - DCLK/2
    .INIT_43(16'h0), // Test register 0
    .INIT_44(16'h0), // Test register 1
    .INIT_45(16'h0), // Test register 2
    .INIT_46(16'h0), // Test register 3
    .INIT_47(16'h0), // Test register 4
    .INIT_48(16'h7F01), // Sequence register 0
    .INIT_49(16'h0), // Sequence register 1
    .INIT_4A(16'h4F00), // ADC Channel Averaging Enables
    .INIT_4B(16'h0), // Sequence register 3
    .INIT_4C(16'h0), // Sequence register 4
    .INIT_4D(16'h0), // Sequence register 5
    .INIT_4E(16'h0), // Sequence register 6
    .INIT_4F(16'h0), // Sequence register 7
    .INIT_50(16'h0), // Alarm limit register 0
    .INIT_51(16'h0), // Alarm limit register 1
    .INIT_52(16'h0), // Alarm limit register 2
    .INIT_53(16'hB883), // Alarm limit register 3 0xB88X = 90 Celcius
    .INIT_54(16'h0), // Alarm limit register 4
    .INIT_55(16'h0), // Alarm limit register 5
    .INIT_56(16'h0), // Alarm limit register 6
    .INIT_57(16'h0)  // Alarm limit register 7
) my_sysmon (
    .BUSY(busy), // 1-bit output ADC busy signal
    .CHANNEL(channel[5:0]), // 6-bit output channel selection
    .DO(dobus[15:0]), // 16-bit output data bus for dynamic reconfig port
    .EOC(eoc),
    .DRDY(drdy),
    .DADDR({2'b0, channel[5:0]}),// 8-bit input address bus for dynamic reconfig
    .DCLK(s_clk), // 1-bit input clock for dynamic reconfig port
    .DEN(eoc), // 1-bit input enable for dynamic reconfig port
    .DWE(1'b0), // 1-bit input write enable for dynamic reconfig port
    .RESET(s_rst) // 1-bit input active high reset
);

`else   // !XILINX_ULTRASCALE

assign channel[5] = 1'b0;

// instantiation based on example from the V5 user guide.
SYSMON #(
    .INIT_40(16'h3000), // Configuration register 0 (0x3000 means average 256 samples)
    .INIT_41(16'h20FE), // Configuration register 1 (low bit disable overtemp shutdown)
    .INIT_42(16'h4000), // Configuration register 2
    .INIT_43(16'h0), // Test register 0
    .INIT_44(16'h0), // Test register 1
    .INIT_45(16'h0), // Test register 2
    .INIT_46(16'h0), // Test register 3
    .INIT_47(16'h0), // Test register 4
    .INIT_48(16'h0F01), // Sequence register 0
    .INIT_49(16'h0), // Sequence register 1
    .INIT_4A(16'h0), // Sequence register 2
    .INIT_4B(16'h0), // Sequence register 3
    .INIT_4C(16'h0), // Sequence register 4
    .INIT_4D(16'h0), // Sequence register 5
    .INIT_4E(16'h0), // Sequence register 6
    .INIT_4F(16'h0), // Sequence register 7
    .INIT_50(16'h0), // Alarm limit register 0
    .INIT_51(16'h0), // Alarm limit register 1
    .INIT_52(16'h0), // Alarm limit register 2
    .INIT_53(16'hB883), // Alarm limit register 3 0xB88X = 90 Celcius
    .INIT_54(16'h0), // Alarm limit register 4
    .INIT_55(16'h0), // Alarm limit register 5
    .INIT_56(16'h0), // Alarm limit register 6
    .INIT_57(16'h0)  // Alarm limit register 7
) my_sysmon (
    .BUSY(busy), // 1-bit output ADC busy signal
    .CHANNEL(channel[4:0]), // 5-bit output channel selection
    .DO(dobus[15:0]), // 16-bit output data bus for dynamic reconfig port
    .EOC(eoc),
    .DRDY(drdy),
    .DADDR({1'b0, channel[5:0]}),// 7-bit input address bus for dynamic reconfig
    .DCLK(s_clk), // 1-bit input clock for dynamic reconfig port
    .DEN(eoc), // 1-bit input enable for dynamic reconfig port
    .DWE(1'b0), // 1-bit input write enable for dynamic reconfig port
    .RESET(s_rst) // 1-bit input active high reset
);

`endif  // !XILINX_ULTRASCALE

endmodule
