/*
* File Name : StreamAXICtrl.v
*
* Description : Controller module for streaming data to and from the memory
*               system with the host processor via the AXI interconnect.  This
*               module converts streaming information to command and data for
*               both reading and writing.  Read/Write commands and sizes are
*               embedded in the first 128-bit entry of the streaming data.
*               This module relies upon asynchronous FIFOs in the AXI
*               interconnect to cross from the stream clock domain into the
*               AXI clock domain.  This assumes the AXI bus width is the same
*               width as the incoming stream data, which in this case is 128
*               bits.
*
*               Debug counts are available to the user logic to check the
*               write and read counts to and from the DDR3 system by writing
*               the proper command to the stream.
*
*               This module is also able to reset the DDR3 system by writing
*               to the stream with the proper command.  The user can
*               also check if the DDR3 system is done with calibration.
*
* Creation Date : Mon 01 Aug 2011 10:11:56 AM PDT
*
* Author : Corey Olson
*
* Last Modified : Thu 11 Aug 2011 10:32:14 AM PDT
*
* Copyright 2011 Pico Computing, Inc.
*/

`include "axi_defines.v"
`include "PicoDefines.v"

module StreamAXICtrl #(
    parameter MAX_LEN           = `MAX_AXI_LEN,
    parameter C_AXI_ID_WIDTH    = 8, 
    parameter C_AXI_ADDR_WIDTH  = 32, 
    parameter C_AXI_DATA_WIDTH  = 128
    ) 
    (

	//------------------------------------------------------
	// Pico Stream Interface
	//------------------------------------------------------
    input                                   clk,
    input                                   rst,
      
    input                                   si_valid,
    output reg                              si_ready,
    input       [127:0]                     si_data,
      
    output reg                              so_valid,
    input                                   so_ready,
    output reg  [127:0]                     so_data,

	//------------------------------------------------------
	// DDR3 - AXI ports
	//------------------------------------------------------

    // AXI write address channel signals
    input                                   s_axi_awready,  // Indicates slave is ready to accept a 
    output reg                              s_axi_awvalid,  // Write address valid
    output      [C_AXI_ID_WIDTH-1:0]        s_axi_awid,     // Write ID
    output      [C_AXI_ADDR_WIDTH-1:0]      s_axi_awaddr,   // Write address
    output      [7:0]                       s_axi_awlen,    // Write Burst Length
    output      [2:0]                       s_axi_awsize,   // Write Burst size
    output      [1:0]                       s_axi_awburst,  // Write Burst type
    output                                  s_axi_awlock,   // Write lock type
    output      [3:0]                       s_axi_awcache,  // Write Cache type
    output      [2:0]                       s_axi_awprot,   // Write Protection type
    output      [3:0]                       s_axi_awqos,    // Write Quality of Service Signaling
     
    // AXI write data channel signals
    input                                   s_axi_wready,   // Write data ready
    output reg                              s_axi_wvalid,   // Write valid
    output      [C_AXI_DATA_WIDTH-1:0]      s_axi_wdata,    // Write data
    output      [C_AXI_DATA_WIDTH/8-1:0]    s_axi_wstrb,    // Write strobes
    output reg                              s_axi_wlast,    // Last write transaction   
     
    // AXI write response channel signals
    input       [C_AXI_ID_WIDTH-1:0]        s_axi_bid,      // Response ID
    input       [1:0]                       s_axi_bresp,    // Write response
    input                                   s_axi_bvalid,   // Write reponse valid
    output                                  s_axi_bready,   // Response ready
     
    // AXI read address channel signals
    input                                   s_axi_arready,  // Read address ready
    output reg                              s_axi_arvalid,  // Read address valid
    output      [C_AXI_ID_WIDTH-1:0]        s_axi_arid,     // Read ID
    output      [C_AXI_ADDR_WIDTH-1:0]      s_axi_araddr,   // Read address
    output      [7:0]                       s_axi_arlen,    // Read Burst Length
    output      [2:0]                       s_axi_arsize,   // Read Burst size
    output      [1:0]                       s_axi_arburst,  // Read Burst type
    output                                  s_axi_arlock,   // Read lock type
    output      [3:0]                       s_axi_arcache,  // Read Cache type
    output      [2:0]                       s_axi_arprot,   // Read Protection type
    output      [3:0]                       s_axi_arqos,    // Read Quality of Service Signaling 
     
    // AXI read data channel signals   
    input       [C_AXI_ID_WIDTH-1:0]        s_axi_rid,      // Response ID
    input       [1:0]                       s_axi_rresp,    // Read response
    input                                   s_axi_rvalid,   // Read reponse valid
    input       [C_AXI_DATA_WIDTH-1:0]      s_axi_rdata,    // Read data
    input                                   s_axi_rlast,    // Read last
    output reg                              s_axi_rready,   // Read Response ready
   
	//------------------------------------------------------
    // Signals to and from the DDR3
	//------------------------------------------------------
    output reg                              ddr3_reset,
    input                                   init_cmptd
);

    //------------------------------------------------------
    // Local Signals
    //------------------------------------------------------
    
    localparam  
                // states
                READ_COMMAND        = 0,    // assert the read command to the memory controller
                WAIT                = 1,    // waiting for valid read/write command from the input stream
                WRITE_DDR3_RESET    = 2,    // write to the DDR3 reset signal in this state
                READ_DDR3_RESET     = 3,    // read the current DDR3 reset and init_cmptd state
                WRITE_COMMAND       = 4,    // assert the write command to the memory controller
                WRITE               = 5,    // writing data to the memory
                LOAD                = 6;    // allow command data load from stream fifo to buffers
    
    reg                                     rst_q;
    reg                                     init_cmptd_q;
    
    reg         [2:0]                       state;
    reg         [2:0]                       nextState;
    
    
    wire                                    ddr3_bit;
    wire        [27:0]                      length_bits;
    wire        [C_AXI_ADDR_WIDTH-1:0]      address_bits;
    wire        [2:0]                       cmd_bits;

    reg                                     ddr3_bit_q;
    reg         [27:0]                      length_bits_q;
    reg         [C_AXI_ADDR_WIDTH-1:0]      address_bits_q;
    reg         [2:0]                       cmd_bits_q;
    
    reg         [C_AXI_ID_WIDTH-1:0]        transactionID;
    reg         [7:0]                       length;
    reg         [C_AXI_ADDR_WIDTH-1:0]      address;
    
    reg         [8:0]                       writeCount;
    reg         [31:0]                      totalLength;
    reg                                     loadTotalLength;
    reg                                     decTotalLength;
    reg                                     loadDDR3Reset;

    //------------------------------------------------------
    // Logic
    //------------------------------------------------------
    
    // Register reset to help ease timing
    always @ (posedge clk) begin
        if (rst) begin
            rst_q <= 1;
            init_cmptd_q <= 0;
        end else begin
            rst_q <= 0;
            init_cmptd_q <= init_cmptd;
        end
    end
   
    // normal quality of service is fine
    assign s_axi_awqos      = `NOT_QOS_PARTICIPANT;
    assign s_axi_arqos      = `NOT_QOS_PARTICIPANT;
    
    // when writing to memory, we want the address to continually increment
    assign s_axi_awburst    = `INCREMENTING;
    assign s_axi_arburst    = `INCREMENTING;

    // a single burst should only be for 128 bits of data (1 transfer)
    assign s_axi_awsize     = `SIXTEEN_BYTES;
    assign s_axi_arsize     = `SIXTEEN_BYTES;

    // don't worry about caching, but allow the slaves to buffer this data
    assign s_axi_awcache    = `BUF_ONLY;
    assign s_axi_arcache    = `BUF_ONLY;

    // this doesn't need any sort of security and is just data writing to or
    // being read from memory
    assign s_axi_awprot     = `DATA_SECURE_NORMAL;
    assign s_axi_arprot     = `DATA_SECURE_NORMAL;
    
    // don't need to lock this for now, but may want to revisit this in the
    // future
    assign s_axi_awlock     = `NORMAL_ACCESS;
    assign s_axi_arlock     = `NORMAL_ACCESS;

    // want all of the write data to be valid
    assign s_axi_wstrb      = ~0;

    ////////////////////////
    // DATA, ADDR, LENGTH //
    ////////////////////////
    
    // this assumes the axi bus width is 128 bits for this port
    assign s_axi_wdata  = si_data;
    
    // simply accept write responses but don't need to check them
    assign s_axi_bready = 1;
    
    // first entry of input data from the stream is interpreted as:
    // 0                = ddr3 reset bit (active high)
    // 31:0             = length (number of desired bytes to write - 16)
    // 63:32            = addr
    // 127:126          = command bits
    //                    0: DDR3 read command 
    //                    2: DDR3 reset
    //                    3: read counters
    //                    4: DDR3 write command
    assign ddr3_bit     = si_data[0];
    assign length_bits  = si_data[31:4];
    assign address_bits = si_data[C_AXI_ADDR_WIDTH+31:32];
    assign cmd_bits     = si_data[127:125];
    always @ (posedge clk) begin
        if (rst_q) begin
            ddr3_bit_q      <= 0;
            length_bits_q   <= 0;
            address_bits_q  <= 0;
            cmd_bits_q      <= 0;
        end else begin
            ddr3_bit_q      <= ddr3_bit;
            length_bits_q   <= length_bits;
            address_bits_q  <= address_bits;
            cmd_bits_q      <= cmd_bits;
        end
    end
    
    // only doing a read or a write at once, so both the read and write
    // address/length can share the same data
    assign s_axi_awid = transactionID;
    assign s_axi_arid = transactionID;
    assign s_axi_awlen = length;
    assign s_axi_arlen = length;
    assign s_axi_awaddr = address;
    assign s_axi_araddr = address;
   
    /////////////////////////////////////////////////
    // COUNTERS FOR A TRANSACTION & LARGE TRANSFER //
    /////////////////////////////////////////////////

    // counter to track the number of transfers for a write
    // -loaded when a write command is sent to the memory
    // -decrements to 0 when another data transfer occurs
    // -wlast should be asserted for the transaction when writeCount=1
    assign loadTransactionCount = s_axi_awvalid & s_axi_awready;
    assign decTransactionCount = s_axi_wvalid & s_axi_wready;
    always @ (posedge clk) begin
        if (rst_q) begin
            writeCount <= 0;
        end else if (loadTransactionCount) begin
            writeCount <= s_axi_awlen + 1'b1;
        end else if (decTransactionCount) begin
            writeCount <= writeCount - 1'b1;
        end
    end

    // -counter used to chop up large read and write commands into smaller
    // commands (<= 4kB), which are then valid for the AXI protocol
    // -track whether we are reading or writing
    // -set the length of this burst
    // -track the address from the starting address (from the stream)
    // -note: a large transaction has completed once totalLength=0 and the
    // current transaction has completed
    always @ (posedge clk) begin
        if (rst_q) begin
            totalLength <= 0;
            length <= 0;
            address <= 0;
            transactionID <= 0;
        end 
        // load the address, read/write bit, and length on the start of a new
        // transaction
        else if (loadTotalLength) begin
            address <= address_bits_q;
            transactionID <= 0;
            if (length_bits_q >= MAX_LEN) begin
                length <= MAX_LEN - 1'b1;
                totalLength <= length_bits_q + 1 - MAX_LEN;
            end else begin
                length <= length_bits_q;
                totalLength <= 0;
            end
        end 
        // update the current transaction length (length) and the total
        // remaining length (totalLength)
        // -note: AXI is byte addressable, so each transfer of 128 bits
        // accounts for 4 bits of address
        else if (decTotalLength) begin
            address <= address + ((length+1) * 16);
            transactionID <= transactionID + 1'b1;
            if (totalLength > MAX_LEN) begin
                length <= MAX_LEN - 1'b1;
                totalLength <= totalLength - MAX_LEN;
            end else begin
                length <= totalLength - 1'b1;
                totalLength <= 0;
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////////
    // states for the controller:
    //
    // WAIT:                waiting for valid read or write data. 
    //
    // LOAD:                cycle of delay to allow the command data embedded in the stream data to
    //                      be loaded into local buffers
    //
    // WRITE_COMMAND:       send the write command (multiple times if 
    //                      necessary), and after each command, move on to 
    //                      sending the write data
    // 
    // READ_COMMAND:        send the read command (multiple times if required
    //                      to chop up large read into smaller blocks)
    // 
    // WRITE:               only entered if doing a write to the memory. count
    //                      the transfers and assert s_axi_wlast on the last 
    //                      transfer for a burst
    // 
    // WRITE_DDR3_RESET:    write the DDR3 reset signal to the appropriate
    //                      value (LS bit of the input stream data)
    //
    // READ_DDR3_RESET:     read the current value of the DDR3 reset and
    //                      init_cmptd signals and write them to the output 
    //                      stream
    //////////////////////////////////////////////////////////////////////////////

    // FSM
    always @ (posedge clk) begin
        if (rst_q) begin
            state <= WAIT;
        end else begin
            state <= nextState;
        end
    end

    // next state logic
    always @ (*) begin
        
        si_ready = 0;
        
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_wlast = (writeCount == 1);
        s_axi_arvalid = 0;
        
        loadTotalLength = 0;
        decTotalLength = 0;
        loadDDR3Reset = 0;
        
        so_data = s_axi_rdata;
        so_valid = s_axi_rvalid;
        s_axi_rready = so_ready;
        
        nextState = state;

        case(state)
            // simply wait for valid data on the inputs and then go to the
            // appropriate state in order to send the write or read command
            WAIT: begin
                if (si_valid) begin
                    si_ready = 1;
                    nextState = LOAD;
                end
            end
            // this stage is used to allow the command, address, and length 
            // bits to be loaded from the stream into the local buffers
            LOAD: begin
                loadTotalLength = 1;
                nextState = cmd_bits_q;
            end
            // send the write command information (including address, length,
            // size, ...) to the memory controller, then move onto sending the
            // write data
            // -after this state, we must always send the data associated with
            // this write command
            WRITE_COMMAND: begin
                s_axi_awvalid = 1;
                if (s_axi_awready) begin
                    nextState = WRITE;
                end
            end
            // send the read command information (including address, length,
            // size, ...) to the memory controller, then move onto the next
            // transaction
            // -if chopping up a large read command into smaller commands(<4kB)
            //  this state may need to execute multiple times
            READ_COMMAND: begin
                s_axi_arvalid = 1;
                if (s_axi_arready) begin
                    // move on if commands have been sent for the whole length
                    if (totalLength == 0) begin
                        nextState = WAIT;
                    end else begin
                        decTotalLength = 1;
                    end
                end
            end
            // when valid data is available, send it to the memory controller
            // from the input stream FIFO.  this relies on the interconnect to
            // do clock domain crossing, since we are synchronous to the
            // streaming clock and not the AXI clock.  Also, assert wlast for
            // the last piece of write data.
            WRITE: begin
                // send the write data
                if (si_valid) begin
                    s_axi_wvalid = 1;
                    if (s_axi_wready) begin
                        si_ready = 1;
                    end
                end

                // assert wlast for the last transaction of a write burst
                if (writeCount == 1) begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        // done if all data has been sent for all chopped up
                        // sections of the larger write data
                        if (totalLength == 0) begin
                            nextState = WAIT;
                        end else begin
                            decTotalLength = 1;
                            nextState = WRITE_COMMAND;
                        end
                    end
                end
            end
            
            // write the LS bit of the input stream data to the DDR3 reset
            // signal (active high)
            WRITE_DDR3_RESET: begin
                loadDDR3Reset = 1;
                nextState = WAIT;
            end

            // read the current value of the DDR3 reset signal
            // output stream written to:
            // bits 127:2   = 0
            // bit  1       = init_cmptd_q
            // bit  0       = ddr3_reset
            READ_DDR3_RESET: begin
                so_valid = 1;
                so_data = {126'h0,init_cmptd_q,ddr3_reset};
                if (so_ready) begin
                    nextState = WAIT;
                end 
            end
            
            // if we get some bad data, we could possibly get to this state,
            // so just go back to the wait state
            default: begin
                nextState = WAIT;
            end
        endcase
    end

    ////////////////
    // DDR3 Reset //
    ////////////////
    always @ (posedge clk) begin
        if (rst) begin
            ddr3_reset <= 0;
        end begin
            // storage for the DDR3 reset bit, because we must wait to be in
            // the WRITE_DDR3_RESET state before loading the ddr3_reset signal
            if (loadDDR3Reset) begin
                ddr3_reset <= ddr3_bit_q;
            end
        end
    end
    
endmodule

