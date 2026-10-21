//==============================================================
// ECE 564 HW5 — Near-memory vector adder
//   A = DRAM[src0], B = DRAM[src1]  ->  C = sat(A + B) -> SRAM[dst]
//==============================================================

module dut_datapath #(
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
// DRAM command encoding from the spec (SystemVerilog enum)
typedef enum logic [1:0] {
  CMD_IDLE  = 2'b00,
  CMD_READ  = 2'b01,
  CMD_WRITE = 2'b10
} dram_cmd_t;

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





module dut_control (
  input logic clk,
  input logic reset_n,
  // From Datapath
  input logic accept,
  // To Datapath
  output logic rd_issue,
  output logic da_sel,
  output logic c_shift,
  output logic sram_wr,
  output logic sa_en,
  output logic sa_sel,
  output logic ready_nxt
);

// States (SystemVerilog enum, feature #2)
  typedef enum logic [2:0] {
    S_IDLE    = 3'd0,
    S_FETCH_A = 3'd1,
    S_ADD_HI  = 3'd2,
    S_ADD_LO  = 3'd3,
    S_DONE    = 3'd4
  } state_t;


  // Timing, all relative to E0 (the accept edge)
  localparam int RD_LAT     = 7;  // READ edge -> first byte in dout_q (E0 -> E7), measured in vsim-mem
  localparam int RD_SPACING = 8;  // min cycles between READ commands
  localparam int VEC_BYTES  = 8;
  localparam int HALF_BYTES = 4;

  localparam logic [4:0] CNT_RD2    = RD_SPACING - 1;            //  7: issue READ src1 -> E8
  localparam logic [4:0] CNT_A_DONE = RD_SPACING + RD_LAT - 1;   // 14: b7 lands in dout_q at E15
  localparam logic [4:0] CNT_HI     = CNT_A_DONE + HALF_BYTES;   // 18: 4th sum lands at E19
  localparam logic [4:0] CNT_LO     = CNT_A_DONE + VEC_BYTES;    // 22: 8th sum lands at E23


state_t state_q, state_d; 
logic [4:0] cnt_q; // Counter to know when to advance to next state 

//-----------------------
// NEXT STATE AND COUNTER 
//-----------------------
always_ff @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin
    state_q <= S_IDLE; 
    cnt_q <= '0;
  end else begin
    state_q <= state_d;
    if(state_q <= S_IDLE) cnt_q <= '0; 
    else cnt_q <= cnt_q + 5'd1; // increment counter
  end
end 


//----------------------------------------
// Counter Comparators and State Decoding 
//----------------------------------------
logic eq_rd2, eq_a_done, eq_hi, eq_lo;
assign eq_rd2    = (cnt_q == CNT_RD2);
assign eq_a_done = (cnt_q == CNT_A_DONE);
assign eq_hi     = (cnt_q == CNT_HI);
assign eq_lo     = (cnt_q == CNT_LO);

logic s_idle, s_fetch_a, s_add_hi, s_add_lo, s_done; 
assign s_idle    = (state_q == S_IDLE);
assign s_fetch_a = (state_q == S_FETCH_A);
assign s_add_hi  = (state_q == S_ADD_HI);
assign s_add_lo  = (state_q == S_ADD_LO);
assign s_done    = (state_q == S_DONE);

//----------------------------
// NEXT STATE LOGIC 
//---------------------------
always_comb begin
  state_d = state_q; // default is stay, prevent latch
  case (state_q)
    S_IDLE: if(accept) state_d = S_FETCH_A; 
    S_FETCH_A: if(eq_a_done) state_d = S_ADD_HI; 
    S_ADD_HI: if(eq_hi) state_d = S_ADD_LO; 
    S_ADD_LO: if(eq_lo) state_d = S_DONE; 
    S_DONE: state_d = S_IDLE;
    default: state_d = S_IDLE;
  endcase
end 

//--------------------------
// OUTPUT LOGIC TO DATAPATH 
//--------------------------
assign rd_issue = accept | (s_fetch_a && eq_rd2);
assign da_sel = ~s_idle; 
assign sa_sel = ~s_idle; 
assign c_shift = s_add_hi | s_add_lo; 
assign sram_wr = (s_add_hi & eq_hi) | (s_add_lo & eq_lo);
assign sa_en = accept | (s_add_lo & eq_lo);
assign ready_nxt = s_done | (s_idle & ~accept); 

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

// Control-unit <-> datapath wires
  logic accept;
  logic rd_issue, da_sel, c_shift, sram_wr, sa_en, sa_sel, ready_nxt;

  dut_datapath #(
    .ADDRESS_WIDTH      (ADDRESS_WIDTH),
    .DQ_WIDTH           (DQ_WIDTH),
    .SRAM_ADDRESS_WIDTH (SRAM_ADDRESS_WIDTH),
    .SRAM_DATA_WIDTH    (SRAM_DATA_WIDTH)
  ) u_dp (
    .clk          (clk),
    .reset_n      (reset_n),
    .valid        (valid),
    .ready        (ready),
    .src0         (src0),
    .src1         (src1),
    .dst          (dst),
    .CMD          (CMD),
    .addr         (addr),
    .dout         (dout),
    .din          (din),
    .oe           (oe),
    .write_enable (write_enable),
    .chip_enable  (chip_enable),
    .address      (address),
    .data_in      (data_in),
    .accept       (accept),
    .rd_issue     (rd_issue),
    .da_sel       (da_sel),
    .c_shift      (c_shift),
    .sram_wr      (sram_wr),
    .sa_en        (sa_en),
    .sa_sel       (sa_sel),
    .ready_nxt    (ready_nxt)
  );

  dut_control u_ctrl (
    .clk       (clk),
    .reset_n   (reset_n),
    .accept    (accept),
    .rd_issue  (rd_issue),
    .da_sel    (da_sel),
    .c_shift   (c_shift),
    .sram_wr   (sram_wr),
    .sa_en     (sa_en),
    .sa_sel    (sa_sel),
    .ready_nxt (ready_nxt)
  );
 

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

