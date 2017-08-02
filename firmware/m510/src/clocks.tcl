# generated system PicoBus clock
create_generated_clock -name sys_picoclk -divide_by 60 -source [get_pins PicoFramework/app/FrameworkPicoBus/s2pb/clk_gen/clk_reg_reg/C] [get_pins PicoFramework/app/FrameworkPicoBus/s2pb/clk_gen/inst/O]
set_clock_groups -async -group [get_clocks sys_picoclk]

# generated user PicoBus clock
# we divide a 250 MHz stream clock by a factor of 62 down to approximately 4 MHz
if {[llength [get_pins -quiet UserWrapper/UserModule_s2pb/s2pb/clk_gen/clk_reg_reg/C]]>0} {
    create_generated_clock -name usr_picoclk -divide_by 60 -source [get_pins UserWrapper/UserModule_s2pb/s2pb/clk_gen/clk_reg_reg/C] [get_pins UserWrapper/UserModule_s2pb/s2pb/clk_gen/inst/O]
    set_clock_groups -async -group [get_clocks usr_picoclk]
}

# generated clock in the System Monitor
create_generated_clock -name dclk -source [get_pins {PicoFramework/app/FrameworkPicoBus/s2pb/clk_gen/inst/O}] -divide_by 64 [get_pins {PicoFramework/app/SystemMonitor/PicoClkCnt_reg[5]/Q}]

