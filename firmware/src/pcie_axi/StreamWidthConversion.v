// StreamWidthConversion.v
// Copyright 2011 Pico Computing, Inc.

// This module allows for the conversion of streams from the base 128b width.

// This module converts an in stream from 128 to W (currently only written for W=32)
module InStreamWidthConversion #(
        parameter           W=128
    ) (
        // core stream signals
        input               clk,
        input               rst,
        
        // base stream signals                                   
        input              s128_valid,
        input      [127:0] s128_data,
        output reg         s128_rdy,
        
        // converted stream signals
        output reg           s_valid,  
        input                s_rdy,    
        output reg [W-1:0]   s_data
    );
    
    reg     [127:0] wr_data_hold;
    reg     [2:0]   wr_byte;
    reg             clearWrByte; 
    reg             incrWrByte;
   
    reg             load32Data;
    reg             load128Data;
    
    reg     [1:0]   state;
    reg     [1:0]   nextState;

    // load data into a 128-bit local register
    always @ (posedge clk) begin
        if (rst) begin
            wr_data_hold    <= 0;
        end else if (load128Data) begin
            wr_data_hold    <= s128_data;
        end
    end

    // load data from the 128-bit register into the 32-bit output register
    always @ (posedge clk) begin
        if (rst) begin
            s_data          <= 0;
        end else if (load32Data) begin
            case(wr_byte) 
                0: s_data   <= wr_data_hold[31:0];
                1: s_data   <= wr_data_hold[63:32];
                2: s_data   <= wr_data_hold[95:64];
                3: s_data   <= wr_data_hold[127:96];
            endcase
        end
    end

    // count which byte we are writing
    always @ (posedge clk) begin
        if (rst || clearWrByte) begin
            wr_byte <= 0;
        end else if (incrWrByte) begin
            wr_byte <= wr_byte + 1;
        end
    end

    // state machine to control the loading of the data
    localparam  WAIT    = 0,
                LOAD    = 1,
                VALID   = 2;

    // FSM
    always @ (posedge clk) begin
        if (rst) begin
            state   <= WAIT;
        end else begin
            state   <= nextState;
        end
    end

    // next state logic
    always @ (*) begin

        // external outputs (output of this module)
        s128_rdy    = 0;
        s_valid     = 0;

        // internal outputs (stays within this module)
        clearWrByte = 0;
        incrWrByte  = 0;
        load128Data = 0;
        load32Data  = 0;
        nextState   = state;

        case (state)
           
            // wait for valid data on the input stream
            // NOTE: don't assert ready in this state, because we want to be able to go directly to
            //       the LOAD state in the event that we get 2 128-bit transactions back-to-back
            WAIT: begin
                load128Data         = 1;
                clearWrByte         = 1;
                if (s128_valid) begin
                   nextState        = LOAD;
                end 
            end

            // assume 128-bit register has valid data, load it into the 32-bit register
            LOAD: begin
                s128_rdy            = 1;
                if (s128_valid) begin
                    load32Data      = 1;
                    incrWrByte      = 1;
                    nextState       = VALID;
                end else begin
                    nextState       = WAIT;
                end
            end

            // 128-bit register contains valid data, assert valid on the output
            VALID: begin
                s_valid             = 1;
                if (s_rdy && (wr_byte == 4)) begin
                    if (s128_valid) begin
                        load128Data = 1;
                        clearWrByte = 1;
                        nextState   = LOAD;
                    end else begin
                        nextState   = WAIT;
                    end
                end else if (s_rdy) begin
                    load32Data      = 1;
                    incrWrByte      = 1;
                end
            end

            // should never enter this state
            default: begin
                nextState = WAIT;
            end
        endcase
    end
      
endmodule 

// This module converts an out stream from W to 128 (currently only written for W=32)
module OutStreamWidthConversion #(
        parameter           W=128
    ) (
        // core stream signals
        input               clk,
        input               rst,
        
        // base stream signals                                   
        output reg          s128_valid,
        output reg  [127:0] s128_data,
        input               s128_rdy,
        
        // converted stream signals
        input               s_valid,  
        output reg          s_rdy,    
        input       [W-1:0] s_data
    );
    
    reg     [W-1:0] wr_data_hold;
    reg     [2:0]   wr_byte;
    reg             clearWrByte; 
    reg             incrWrByte;
   
    reg             load32Data;
    reg             load128Data;
    
    reg     [1:0]   state;
    reg     [1:0]   nextState;

    reg             skipWait;
    reg             nextSkipWait;    

    // load data from the input into the 32-bit output register
    always @ (posedge clk) begin
        if (rst) begin
            wr_data_hold    <= 0;
        end else if (load32Data) begin
            wr_data_hold    <= s_data;
        end
    end

    // load data into a 128-bit local register from the 32-bit registered input
    always @ (posedge clk) begin
        if (rst) begin
            s128_data                   <= 0;
        end else if (load128Data) begin
            case(wr_byte) 
                0: s128_data[31:0]      <= wr_data_hold;
                1: s128_data[63:32]     <= wr_data_hold;
                2: s128_data[95:64]     <= wr_data_hold;
                3: s128_data[127:96]    <= wr_data_hold;
            endcase
        end
    end

    // count which byte we are writing
    always @ (posedge clk) begin
        if (rst || clearWrByte) begin
            wr_byte <= 0;
        end else if (incrWrByte) begin
            wr_byte <= wr_byte + 1;
        end
    end

    // flag to tell the logic to skip the WAIT state on the next set of 4 data elements
    always @ (posedge clk) begin
        if (rst) begin
            skipWait    <= 0;
        end else begin
            skipWait    <= nextSkipWait;
        end
    end

    // state machine to control the loading of the data
    localparam  WAIT    = 0,
                LOAD    = 1,
                VALID   = 2,
                CYCLE   = 3;

    // FSM
    always @ (posedge clk) begin
        if (rst) begin
            state   <= WAIT;
        end else begin
            state   <= nextState;
        end
    end

    // next state logic
    always @ (*) begin

        // external outputs (output of this module)
        s_rdy       = 0;
        s128_valid  = 0;

        // internal outputs (stays within this module)
        clearWrByte = 0;
        incrWrByte  = 0;
        load128Data = 0;
        load32Data  = 0;
        nextSkipWait= skipWait;
        nextState   = state;

        case (state)
           
            // wait for valid data on the input stream
            WAIT: begin
                load32Data          = 1;
                s_rdy               = 1;
                clearWrByte         = 1;
                if (s_valid) begin
                   nextState        = LOAD;
                end
            end

            // assume 32-bit register has valid data, load it into the 32-bit register
            LOAD: begin
                s_rdy               = 1;
                nextSkipWait        = 0;
                if (s_valid) begin
                    load32Data      = 1;
                    load128Data     = 1;
                    incrWrByte      = 1;
                    if (wr_byte == 2) begin
                        nextState   = CYCLE;
                    end
                end 
            end

            // dead cycle to just load the final 32 bits, because we know the 32-bit register has
            //  valid data in it
            // NOTE: this state also accepts a new value into the 32-bit register, so 
            CYCLE: begin
                s_rdy               = 1;
                load128Data         = 1;
                load32Data          = 1;
                nextState           = VALID;
                if (s_valid) begin
                    nextSkipWait    = 1;
                end
            end

            // 128-bit register contains valid data, assert valid on the output
            VALID: begin
                s128_valid          = 1;
                clearWrByte         = 1;
                if (s128_rdy) begin
                    if (skipWait) begin
                        nextState   = LOAD;
                    end else begin
                        nextState   = WAIT;
                    end
                end
            end

            // should never enter this state
            default: begin
                nextState = WAIT;
            end
        endcase
    end
    
endmodule 
