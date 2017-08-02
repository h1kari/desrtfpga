// XilinxInterfaces.sv
// Copyright 2014 Pico Computing, Inc.

interface pci_exp_ports;

    wire  [7:0]                         txp;
    wire  [7:0]                         txn;
    wire  [7:0]                         rxp;
    wire  [7:0]                         rxn;

    modport i (
        input  rxp, rxn,
        output txp, txn
    );

endinterface

interface flash_ports;
    wire                                busy;
    wire                                byte_mode;
    wire                                ce;
    wire                                oe;
    wire                                reset;
    wire                                we;
    wire   [25:0]                       a;
    wire   [15:0]                       d;
    modport i (
        input   busy,
        output  byte_mode, ce, oe, reset, we, a,
        inout   d
    );
endinterface

/* the sv package is not defined
import PicoModelParams::nCS_PER_RANK;
import PicoModelParams::BANK_WIDTH;  
import PicoModelParams::ROW_WIDTH;   
import PicoModelParams::CK_WIDTH;    
import PicoModelParams::CS_WIDTH;    
import PicoModelParams::CKE_WIDTH;   
import PicoModelParams::DQ_WIDTH;    
import PicoModelParams::DM_WIDTH;    
import PicoModelParams::DQS_WIDTH;   
import PicoModelParams::ODT_WIDTH;   

interface ddr3_phy_ports;
    wire   [DQ_WIDTH-1:0]               dq;
    wire   [ROW_WIDTH-1:0]              addr;
    wire   [BANK_WIDTH-1:0]             ba;
    wire                                ras_n;
    wire                                cas_n;
    wire                                we_n;
    wire                                reset_n;
    wire   [DM_WIDTH-1:0]               dm;
    wire   [DQS_WIDTH-1:0]              dqs_p;
    wire   [DQS_WIDTH-1:0]              dqs_n;
    wire   [CK_WIDTH-1:0]               ck_p;
    wire   [CK_WIDTH-1:0]               ck_n;
    wire   [CS_WIDTH*nCS_PER_RANK-1:0]  cs_n;
    wire   [ODT_WIDTH-1:0]              odt;
    wire   [CKE_WIDTH-1:0]              cke;
    
    modport i (
        inout   dq, dqs_p, dqs_n,
        output  addr, ba, ras_n, cas_n, we_n, reset_n, dm, ck_p, ck_n, cs_n, odt, cke
    );

endinterface
*/

interface i2c_ports;
    wire sda, scl;
    modport i (
        inout   sda,
        output  scl
    );
endinterface

// AXI INTERFACE
interface ddr3_core_uif #(
    C_AXI_ID_WIDTH        = 12,
    C_AXI_ADDR_WIDTH      = 33,
    C_AXI_DATA_WIDTH      = 256
    );
    wire                                    rst;
    wire                                    clk;
    logic   [C_AXI_ID_WIDTH-1:0]            awid;
    logic   [C_AXI_ADDR_WIDTH-1:0]          awaddr;
    logic   [7:0]                           awlen;
    logic   [2:0]                           awsize;
    logic   [1:0]                           awburst;
    logic                                   awlock;
    logic   [3:0]                           awcache;
    logic   [2:0]                           awprot;
    logic   [3:0]                           awqos;
    logic                                   awvalid;
    logic                                   awready;

    logic   [C_AXI_DATA_WIDTH-1:0]          wdata;
    logic   [C_AXI_DATA_WIDTH/8-1:0]        wstrb;
    logic                                   wlast;
    logic                                   wvalid;
    logic                                   wready;

    logic   [C_AXI_ID_WIDTH-1:0]            bid;
    logic   [1:0]                           bresp;
    logic                                   bvalid;
    logic                                   bready;

    logic   [C_AXI_ID_WIDTH-1:0]            arid;
    logic   [C_AXI_ADDR_WIDTH-1:0]          araddr;
    logic   [7:0]                           arlen;
    logic   [2:0]                           arsize;
    logic   [1:0]                           arburst;
    logic                                   arlock;
    logic   [3:0]                           arcache;
    logic   [2:0]                           arprot;
    logic   [3:0]                           arqos;
    logic                                   arvalid;
    logic                                   arready;

    logic   [C_AXI_ID_WIDTH-1:0]            rid;
    logic   [C_AXI_DATA_WIDTH-1:0]          rdata;
    logic   [1:0]                           rresp;
    logic                                   rlast;
    logic                                   rvalid;
    logic                                   rready;

    modport slave (
        inout   rst, clk,

        output  awready,
        input   awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid,

        output  wready,
        input   wdata, wstrb, wlast, wvalid,

        output  bid, bresp, bvalid, 
        input   bready,

        output  arready,
        input   arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid,

        output  rid, rdata, rresp, rlast, rvalid,
        input   rready
    );

    modport master (
        inout   rst, clk,

        input   awready,
        output  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid,

        input   wready,
        output  wdata, wstrb, wlast, wvalid,

        input   bid, bresp, bvalid, 
        output  bready,

        input   arready,
        output  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid,

        input   rid, rdata, rresp, rlast, rvalid,
        output  rready
    );

endinterface

