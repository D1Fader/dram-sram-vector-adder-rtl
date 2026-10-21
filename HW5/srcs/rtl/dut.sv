//==============================================================
// ECE 564 HW5 — Near-memory vector adder
//   A = DRAM[src0], B = DRAM[src1]  ->  C = sat(A + B) -> SRAM[dst]
//==============================================================
package hw5_pkg;
  // DRAM command encoding from the spec
  typedef enum logic [1:0] {
    CMD_IDLE  = 2'b00,
    CMD_READ  = 2'b01,
    CMD_WRITE = 2'b10
  } dram_cmd_t;
endpackage


module dut_datapath
  import hw5_pkg::*;
#(
  parameter int ADDRESS_WIDTH      = 32,
  parameter int DQ_WIDTH           = 8,
  parameter int SRAM_ADDRESS_WIDTH = 32,
  parameter int SRAM_DATA_WIDTH    = 32
)(
  // System
  input  logic                          clk,
  input  logic                          reset_n,
  // Test Fixture Handshake + command
  input  logic                          valid,
  output logic                          ready,
  input  logic [ADDRESS_WIDTH-1:0]      src0,
  input  logic [ADDRESS_WIDTH-1:0]      src1,
  input  logic [ADDRESS_WIDTH-1:0]      dst,  
  //DRAM Interface       
  output logic [1:0]                    CMD,
  output logic [ADDRESS_WIDTH-1:0]      addr,
  input  logic [DQ_WIDTH-1:0]           dout,
  output logic [DQ_WIDTH-1:0]           din,
  output logic                          oe,  
  //SRAM Interface
  output logic                          write_enable,
  output logic                          chip_enable,
  output logic [SRAM_ADDRESS_WIDTH-1:0] address,
  output logic [SRAM_DATA_WIDTH-1:0]    data_in,
  // To control Unit
  output logic                          accept,
  // From control Unit
  input  logic                          rd_issue, // Enables dram_addr register to pass data to addr bus of DRAM
  input  logic                          da_sel,   // Picks src0 or src1 to be sent to addr bus of DRAM
  input  logic                          c_shift,  // Enables the res register to pass data to data_in bus of SRAM for writes
  input  logic                          sram_wr,  // Enables write_enable and chip_enable of SRAM, start a write. 
  input  logic                          sa_en,    // Enables the sram_addr register to pass data into address bus of SRAM
  input  logic                          sa_sel,   // Select address or address+4 for SRAM writes fed into the sram_addr register 
  input  logic                          ready_nxt // ready output for handshaking 
);

localparam int VEC_BYTES = 8;   // Elements per Vector
localparam int VEC_BITS = VEC_BYTES * DQ_WIDTH; // 64
localparam logic [SRAM_ADDRESS_WIDTH-1:0] SRAM_STEP = 4; // byte address of next 32-bit word

//------------------------------------------------------------
// Step 1: command capture + DRAM request (registered outputs)
//------------------------------------------------------------
logic [ADDRESS_WIDTH-1:0] src1_q;
logic [ADDRESS_WIDTH-1:0] dram_addr_q;
dram_cmd_t                cmd_q;

always_ff @( posedge clk or negedge reset_n ) begin
  if(!reset_n) begin
    src1_q <= '0;
    dram_addr_q <= '0;
    cmd_q <= CMD_IDLE; 
  end else begin
    if (accept) src1_q <= src1; 
    if (rd_issue) dram_addr_q <= da_sel ? src1_q : src0; 
    if (rd_issue) cmd_q <= CMD_READ;
    else cmd_q <= CMD_IDLE;
  end 
end

assign CMD = cmd_q; 
assign addr = dram_addr_q; 
assign din = '0; // Not writing to DRAM, can stay low
assign oe = '0; 


//------------------------------------------------------------
// Step 2: DRAM read capture
//------------------------------------------------------------
logic [DQ_WIDTH-1:0] dout_q;   // input register on the DQ bus
logic [VEC_BITS-1:0] a_sr;     // A-vector shift register (free-running)

always_ff @(posedge clk or negedge reset_n) begin 
  if (!reset_n) begin
      dout_q <= '0;
      a_sr   <= '0;
  end else begin
    dout_q <= dout; 
    a_sr <= {a_sr[VEC_BITS-DQ_WIDTH-1:0], dout_q};  // Concatenate for shift register 
  end 
end

logic [DQ_WIDTH-1:0] a_byte, b_byte; 
assign a_byte = a_sr[VEC_BITS-1 -: DQ_WIDTH];   // a_sr[63:56]
assign b_byte = dout_q; 


//------------------------------------------------------------
// Step 3: signed saturating add (combinational, one byte/cycle)
//------------------------------------------------------------
logic [DQ_WIDTH:0]   sum9;     // 9 bits: cannot overflow
logic                ovf;
logic [DQ_WIDTH-1:0] sat_val;
logic [DQ_WIDTH-1:0] c_byte;
// This is purley combinational logic once a_byte and b_byte are rolling in 
assign sum9 = {a_byte[DQ_WIDTH-1], a_byte} + {b_byte[DQ_WIDTH-1], b_byte}; //Sign extend -> ADD produce 9 bit result
assign ovf = sum9[DQ_WIDTH] ^ sum9[DQ_WIDTH-1]; // XOR
assign sat_val = sum9[DQ_WIDTH] ? 8'h80 : 8'h7F; 
assign c_byte = ovf ? sat_val : sum9[DQ_WIDTH-1:0];


//------------------------------------------------------------
// Step 4: result register + SRAM write port 
//------------------------------------------------------------

logic [SRAM_DATA_WIDTH-1:0]       res_q; 
logic [SRAM_ADDRESS_WIDTH-1:0]    sram_addr_q; 
logic we_q; 

always_ff @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin
    res_q <= 0;
    sram_addr_q <= 0;
    we_q <= 0;
  end else begin
  if(c_shift) res_q <= {res_q[SRAM_DATA_WIDTH-DQ_WIDTH-1:0], c_byte}; // CAT -> res_q
  if(sa_en) sram_addr_q <= sa_sel ? (sram_addr_q + SRAM_STEP) : dst; // lower or higher address 
  we_q <= sram_wr; 
  end
end 

assign data_in      = res_q;
assign address      = sram_addr_q;
assign write_enable = we_q;
assign chip_enable  = we_q;


  //------------------------------------------------------------
  // Step 5: handshake
  //------------------------------------------------------------
  logic ready_q;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) ready_q <= 1'b1;        // leave reset idle and ready
    else          ready_q <= ready_nxt;
  end

  assign ready  = ready_q;
  assign accept = valid & ready_q;        // AND gate -> control unit

endmodule



























































module dut #(
  parameter int ADDRESS_WIDTH = 32,
  parameter int DQ_WIDTH = 8,
  parameter int SRAM_ADDRESS_WIDTH = 32,
  parameter int SRAM_DATA_WIDTH = 32

)(
  // System Signals
  input  wire                            clk,
  input  wire                            reset_n, 
 
  // Control signals
  input  wire                            valid,
  output wire                            ready,

  // Data signals
  input  wire   [ADDRESS_WIDTH-1:0]      src0,
  input  wire   [ADDRESS_WIDTH-1:0]      src1,
  input  wire   [ADDRESS_WIDTH-1:0]      dst,

  // SDR memory interface
  output wire   [1:0]                    CMD,  // 2'b00=IDLE, 2'b01=READ, 2'b10=WRITE
  output wire   [ADDRESS_WIDTH-1:0]      addr,
  input  wire   [DQ_WIDTH-1:0]           dout,
  output wire   [DQ_WIDTH-1:0]           din,
  output wire                            oe,

  // SRAM memory interface
  output  wire                            write_enable,
  output  wire                            chip_enable,
  output  wire   [SRAM_ADDRESS_WIDTH-1:0] address,
  input   wire   [SRAM_DATA_WIDTH-1:0]    data_out,    
  output  wire   [SRAM_DATA_WIDTH-1:0]    data_in
);

 

endmodule

