# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/desrtfpga"]"

# Create project
create_project desrtfpga ./desrtfpga

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects desrtfpga]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xcku060-ffva1156-2-e" $obj
set_property "simulator_language" "Mixed" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files [list \
 "[file normalize "$origin_dir/firmware/src/pcie_axi/BasePicoDefines.v"]"\
 "[file normalize "$origin_dir/firmware/PicoDefines.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/Reorder.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/CounterClkGen.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/fifo_512x128.v"]"\
 "[file normalize "$origin_dir/firmware/xilinx/src/FIFO.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PCIeHdrAlignSplit.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PicoStreamIn.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PicoStreamOut.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PIO_128_RX_ENGINE.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PIO_128_TX_ENGINE.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/StreamToPicoBus.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/TagFIFO.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/CardInfo32.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/PIO_EP.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/Stream2PicoBus.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/SystemMonitor32.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/TestCounter32.v"]"\
 "[file normalize "$origin_dir/firmware/xilinx/src/pcie3_7x_to_v1_6.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/pcie_app_v6.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/StreamWidthConversion.v"]"\
 "[file normalize "$origin_dir/firmware/xilinx/src/xilinx_pcie_3_0_7vx.v"]"\
 "[file normalize "$origin_dir/firmware/src/PicoInterfaces.sv"]"\
 "[file normalize "$origin_dir/firmware/m510/src/UserWrapper.v"]"\
 "[file normalize "$origin_dir/firmware/m510/src/PicoFramework.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/RGBBlink.v"]"\
 "[file normalize "$origin_dir/firmware/m510/src/Pico_Toplevel.v"]"\
 "[file normalize "$origin_dir/firmware/src/pcie_axi/axi_defines.v"]"\
 "[file normalize "$origin_dir/firmware/src/UtilFunc.sv"]"\
 "[file normalize "$origin_dir/firmware/xilinx/src/XilinxInterfaces.sv"]"\
 "[file normalize "$origin_dir/ip/coregen_fifo_32x128/coregen_fifo_32x128.upgrade_log"]"\
]
add_files -norecurse -fileset $obj $files

# Import local files from the original project
set files [list \
 "[file normalize "$origin_dir/sbox8.v"]"\
 "[file normalize "$origin_dir/sbox7.v"]"\
 "[file normalize "$origin_dir/sbox6.v"]"\
 "[file normalize "$origin_dir/sbox5.v"]"\
 "[file normalize "$origin_dir/sbox4.v"]"\
 "[file normalize "$origin_dir/sbox3.v"]"\
 "[file normalize "$origin_dir/sbox2.v"]"\
 "[file normalize "$origin_dir/sbox1.v"]"\
 "[file normalize "$origin_dir/key_sel.v"]"\
 "[file normalize "$origin_dir/crp.v"]"\
 "[file normalize "$origin_dir/des.v"]"\
 "[file normalize "$origin_dir/ip/fsl_ring_async/fsl_ring_async.xci"]"\
 "[file normalize "$origin_dir/ip/fsl_fifo_async/fsl_fifo_async.xci"]"\
 "[file normalize "$origin_dir/redux_lfsr.v"]"\
 "[file normalize "$origin_dir/fsl_to_bus.v"]"\
 "[file normalize "$origin_dir/descrack.v"]"\
 "[file normalize "$origin_dir/ip/coregen_fifo_32x128/coregen_fifo_32x128.xci"]"\
 "[file normalize "$origin_dir/descrack_stream_core.v"]"\
 "[file normalize "$origin_dir/ip/fsl_fifo_async_out/fsl_fifo_async_out.xci"]"\
 "[file normalize "$origin_dir/ip/fsl_fifo_in_async/fsl_fifo_in_async.xci"]"\
 "[file normalize "$origin_dir/ip/fsl_ring_sync/fsl_ring_sync.xci"]"\
 "[file normalize "$origin_dir/stream_to_fsl.v"]"\
 "[file normalize "$origin_dir/fsl_to_stream.v"]"\
 "[file normalize "$origin_dir/ip/pcie3_ultrascale_0/pcie3_ultrascale_0.xci"]"\
 "[file normalize "$origin_dir/ip/mmcm/mmcm.xci"]"\
 "[file normalize "$origin_dir/descrack_stream_region.v"]"\
 "[file normalize "$origin_dir/descrack_stream_top.v"]"\
]
set imported_files [import_files -fileset sources_1 $files]

# Set 'sources_1' fileset file properties for remote files
set file "$origin_dir/firmware/src/pcie_axi/BasePicoDefines.v"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "Verilog Header" $file_obj

set file "$origin_dir/firmware/PicoDefines.v"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "Verilog Header" $file_obj

set file "$origin_dir/firmware/src/pcie_axi/axi_defines.v"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "Verilog Header" $file_obj

set file "$origin_dir/firmware/src/PicoInterfaces.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "SystemVerilog" $file_obj

set file "$origin_dir/firmware/src/UtilFunc.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "SystemVerilog" $file_obj

set file "$origin_dir/firmware/xilinx/src/XilinxInterfaces.sv"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "SystemVerilog" $file_obj

set file "$origin_dir/ip/coregen_fifo_32x128/coregen_fifo_32x128.upgrade_log"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "IP Update Log" $file_obj


# Set 'sources_1' fileset file properties for local files
set file "fsl_ring_async/fsl_ring_async.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "fsl_fifo_async/fsl_fifo_async.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "coregen_fifo_32x128/coregen_fifo_32x128.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "fsl_fifo_async_out/fsl_fifo_async_out.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "fsl_fifo_in_async/fsl_fifo_in_async.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "fsl_ring_sync/fsl_ring_sync.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "pcie3_ultrascale_0/pcie3_ultrascale_0.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "mmcm/mmcm.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}


# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "Pico_Toplevel" $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/firmware/m510/src/M510_KU060_FFVA1156_E.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "$origin_dir/firmware/m510/src/M510_KU060_FFVA1156_E.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/firmware/m510/src/clocks.tcl"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "$origin_dir/firmware/m510/src/clocks.tcl"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "TCL" $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "top" "Pico_Toplevel" $obj
set_property "xelab.nosort" "1" $obj
set_property "xelab.unifast" "" $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xcku060-ffva1156-2-e -flow {Vivado Synthesis 2015} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2015" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" "xcku060-ffva1156-2-e" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xcku060-ffva1156-2-e -flow {Vivado Implementation 2015} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2015" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" "xcku060-ffva1156-2-e" $obj
set_property "steps.write_bitstream.args.readback_file" "0" $obj
set_property "steps.write_bitstream.args.verbose" "0" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created:desrtfpga"
