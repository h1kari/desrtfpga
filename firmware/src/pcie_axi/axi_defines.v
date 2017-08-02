// Defines file for AXI modules from
//  -AMBA AXI Protocol Specification 
//  -Version 2.0

// Settings for ARLEN[7:0] & AWLEN[7:0] from page 4-3
// -controls the number of data transfers within each burst
// number of transfers is ARLEN[7:0] + 1 or AWLEN[7:0] + 1
`define MAX_AXI_LEN             256

// Settings for ARSIZE[2:0] & AWSIZE[2:0] from page 4-4
// -specifies the maximum number of data bytes to transfer for each data
// transfer within a burst
`define ONE_BYTE                3'h0
`define TWO_BYTES               3'h1
`define FOUR_BYTES              3'h2
`define EIGHT_BYTES             3'h3
`define SIXTEEN_BYTES           3'h4
`define THIRTY_TWO_BYTES        3'h5
`define SIXTY_FOUR_BYTES        3'h6
`define ONE_TWENTY_EIGHT_BYTES  3'h7

// Settings for ARBURST[1:0] & AWBURST[1:0] from page 4-5
// -specifies the way the address is incremented (or not) by the AXI slave
// device after the first data transfer
`define FIXED           2'h0    // fixed-address burst
`define INCREMENTING    2'h1    // incrementing-address burst
`define WRAPPING        2'h2    // incrementing-address burst that wraps to a lower address at the wrap boundary
`define RESERVED_1      2'h3    // reserved value

// Settings for ARCACHE[3:0] & AWCACHE[3:0] from page 5-3
// bit 3 = write allocate: if the transfer is a write and it misses in the cache,
//      it should be allocated
// bit 2 = read allocate: if the transfer is a read and it misses in the cache, it
//      should be allocated
// bit 1 = cacheable: transaction at the final destination does not have to match
//      the characteristics of the original transaction
//      writes - a number of different writes can be merged together
//      reads - a location can be pre-fetched or can be fetched only once for
//          multiple transactions
// bit 0 = bufferable: the interconnect or any component can delay the transaction
//      reaching its final destination for an arbitrary number of cycles
`define NON_CACHE_NON_BUFFER                4'h0
`define BUF_ONLY                            4'h1
`define CACHE_DO_NOT_ALLOC                  4'h2
`define CACHE_BUF_DO_NOT_ALLOC              4'h3
`define RESERVED_2                          4'h4
`define RESERVED_3                          4'h5
`define CACHE_WRITE_THROUGH_ALLOC_READS     4'h6
`define CACHE_WRITE_BACK_ALLOC_READS        4'h7
`define RESERVED_4                          4'h8
`define RESERVED_5                          4'h9
`define CACHE_WRITE_THROUGH_ALLOC_WRITES    4'hA
`define CACHE_WRITE_BACK_ALLOC_WRITES       4'hB
`define RESERVED_6                          4'hC
`define RESERVED_7                          4'hD
`define CACHE_WRITE_THROUGH_ALLOC_BOTH      4'hE
`define CACHE_WRITE_BACK_ALLOC_BOTH         4'hF

// Settings for ARPROT[2:0] & AWPROT[2:0] from page 5-4
// bit 2 = normal or priviledged: used by some masters to indicate their
//          processing mode
// bit 1 = secure or non-secure: used by systems where a greater degree of
//          differentition between processing modes is required
// bit 0 = data or instruction: gives an indication if the transaction is data
//          or instruction
`define DATA_SECURE_NORMAL              3'h0
`define DATA_SECURE_PRIV                3'h1
`define DATA_NONSECURE_NORMAL           3'h2
`define DATA_NONSECURE_PRIV             3'h3
`define INSTRUCTION_SECURE_NORMAL       3'h4
`define INSTRUCTION_SECURE_PRIV         3'h5
`define INSTRUCTION_NONSECURE_NORMAL    3'h6
`define INSTRUCTION_NONSECURE_PRIV      3'h7

// Settings for ARLOCK[1:0] & AWLOCK[1:0] from page 6-2
// -used to enable the implementation of atomic access primitives
// -provides exclusive access and locked access
`define NORMAL_ACCESS       2'h0
`define EXCLUSIVE_ACCESS    2'h1
`define LOCKED_ACCESS       2'h2
`define RESERVED_8          2'h3

// Settings for RRESP[1:0] & BRESP[1:0] from page 7-2
// -used to convey information about the access to the slave
// -access could be valid or in error state
`define OKAY    2'h0    // Normal access okay indicates if a normal access has been successful. 
                        //  Can also indicate an exclusive access failure.
`define EXOKAY  2'h1    // Exclusive access okay indicates that either the read or write portion 
                        //  of an exclusive access has been successful.
`define SLVERR  2'h2    // Slave error is used when the access has reached the slave successfully, 
                        //  but the slave wishes to return an error condition to the originating master
`define DECERR  2'h3    // Decode error is generated typically by an interconnect component to indicate 
                        //  that there is no slave at the transaction address.

// Settings for ARQOS[3:0] & AWQOS[3:0] from page 13-3
`define NOT_QOS_PARTICIPANT     4'h0    // not participating in the quality of service function
