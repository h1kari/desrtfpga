// PicoDefines.v - here we configure the base firmware for our project

// This includes a placeholder "user" module that you will replace with your code.
// To use your own module, just change the name from PicoBus128_counter to your
//   module's name, and then add the file to your ISE project.
`define USER_MODULE_NAME descrack_stream_top
`define XILINX_FPGA

`define STREAM1_IN_WIDTH 128
`define STREAM1_OUT_WIDTH 128
`define PICOBUS_WIDTH 128

// We define the type of FPGA and card we're using.
`define PICO_MODEL_M510
`define PICO_FPGA_KU060

`define EXTRA_CLK 1
`define REGIONS 29
`define CORES 3

`define RING_DIN  1'b1
`define RING_DOUT 1'b0

`include "BasePicoDefines.v"

