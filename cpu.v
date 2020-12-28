// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "consts.v"

module cpu(
    input  wire                 clk_in,         // system clock signal
    input  wire                 rst_in,         // reset signal
    input  wire                 rdy_in,         // ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,        // data input bus
    output wire [ 7:0]          mem_dout,       // data output bus
    output wire [31:0]          mem_a,          // address bus (only 17:0 is used)
    output wire                 mem_wr,         // write/read signal (1 for write)

    input  wire                 io_buffer_full, // 1 if uart buffer is full

    output wire [31:0]          dbgreg_dout     // cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - rst > rdy
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// Stall bus wires
wire if_stall_req_o;
wire id_stall_req_o;
wire mem_stall_req_o;

wire if_stall_enable_i;
wire id_stall_enable_i;
wire ex_stall_enable_i;
wire mem_stall_enable_i;
wire wb_stall_enable_i;


// -------------------- PCReg wires --------------------
wire pcreg_jump_enable_i;
wire[`AddrLen - 1: 0] pcreg_jump_pc_i;

// -------------------- IF wires --------------------
wire if_pc_enable_i;
wire[`AddrLen - 1: 0] if_pc_i;
wire if_pc_jump_enable_i;

wire if_from_ram_enable_o;
wire[`AddrLen - 1: 0] if_pc_o;
wire if_pc_jump_enable_o;

wire if_inst_ready_i;
wire[`RegLen - 1: 0] if_inst_i;

wire if_inst_ready_o;

wire[`AddrLen - 1: 0] if_next_pc_o;
wire[`InstLen - 1: 0] if_inst_o;

// -------------------- ID wires --------------------
wire[`AddrLen - 1: 0] id_next_pc_i;
wire[`InstLen - 1: 0] id_inst_i;

wire[`RegLen - 1: 0] id_rs1_data_i, id_rs2_data_i;      // Reg -> ID
wire id_rs1_read_enable_o, id_rs2_read_enable_o;    // ID -> Reg
wire[`RegAddrLen - 1: 0] id_rs1_addr_o, id_rs2_addr_o;

wire[`RegLen - 1: 0] id_rs1_data_o, id_rs2_data_o;
wire[`AluOpLen - 1: 0] id_aluop_o;
wire[`AluSelLen - 1: 0] id_alusel_o;
wire[`Funct3Len - 1: 0] id_funct3_o;
wire[`RegLen - 1: 0] id_imm_o;
wire[`RegAddrLen - 1: 0] id_rd_addr_o;
wire id_rd_write_enable_o;

wire[`AddrLen - 1: 0] id_next_pc_o;
wire[`AddrLen - 1: 0] id_jump_pc_o;
wire id_jump_enable_o;

// -------------------- EX wires --------------------
wire[`RegLen - 1: 0] ex_rs1_data_i;
wire[`RegLen - 1: 0] ex_rs2_data_i;
wire[`AluOpLen - 1: 0] ex_aluop_i;
wire[`AluSelLen - 1: 0] ex_alusel_i;
wire[`Funct3Len - 1: 0] ex_funct3_i;
wire[`RegLen - 1: 0] ex_imm_i;
wire[`RegAddrLen - 1: 0] ex_rd_addr_i;
wire ex_rd_write_enable_i;

wire[`AddrLen - 1: 0] ex_next_pc_i;
wire[`AddrLen - 1: 0] ex_jump_pc_i;

wire[`RegLen - 1: 0] ex_store_data_o;
wire ex_load_enable_o;
wire ex_store_enable_o;
wire[`AddrLen - 1: 0] ex_load_store_addr_o;
wire[`Funct3Len - 1: 0] ex_funct3_o;
wire[`RegLen - 1: 0] ex_rd_data_o;
wire[`RegAddrLen - 1: 0] ex_rd_addr_o;
wire ex_rd_write_enable_o;
wire ex_rd_ready_o;

wire[`AddrLen - 1: 0] ex_jump_pc_o;
wire ex_jump_enable_o;

// -------------------- MEM wires --------------------
wire mem_wr_enable_i;
wire mem_wr_i;
wire mem_wr_enable_o;
wire mem_wr_o;

wire[`Funct3Len - 1: 0] mem_funct3_i;
wire[`RegAddrLen - 1: 0] mem_rd_addr_i;
wire mem_rd_write_enable_i;
wire[`RegLen - 1: 0] mem_rd_data_i;

wire[`AddrLen - 1: 0] mem_load_store_addr_i;
wire[1: 0] mem_load_store_type_i;
wire[`RegLen - 1: 0] mem_store_data_i;

wire mem_load_store_ready_i;
wire[`RegLen - 1: 0] mem_load_data_i;

wire[`RegLen - 1: 0] mem_rd_data_o;
wire[`RegAddrLen - 1: 0] mem_rd_addr_o;
wire mem_rd_write_enable_o;

// -------------------- WB wires --------------------
wire[`RegLen - 1: 0] wb_rd_data_i;
wire[`RegAddrLen - 1: 0] wb_rd_addr_i;
wire wb_rd_write_enable_i;

// -------------------- Miscellaneous --------------------
wire last_is_load;
wire[`RegAddrLen - 1: 0] last_load_rd_addr;

wire is_if_output;
wire is_mem_output;

wire id_stall_req_resume;


MemCtrl memctrl(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),

    .ram_data_i(mem_din),
    .ram_data_o(mem_dout),
    .ram_addr_o(mem_a),
    .ram_wr_o(mem_wr),

    .memctrl_off_o(memctrl_off), // TODO: rewrite?

    .if_from_ram_enable_i(if_from_ram_enable_o),
    .if_pc_i(if_pc_o),
    .if_pc_jump_enable_i(if_pc_jump_enable_o),

    .is_if_output_o(is_if_output),
    .if_inst_ready_o(if_inst_ready_i),
    .if_inst_o(if_inst_i),

    .id_stall_req_i(id_stall_req_o),
    .id_stall_req_resume_o(id_stall_req_resume),

    .mem_wr_enable_i(mem_wr_enable_o), // from MEM
    .mem_wr_i(mem_wr_o), // from MEM
    .load_store_addr_i(mem_load_store_addr_i),
    .load_store_type_i(mem_load_store_type_i),
    .store_data_i(mem_store_data_i),

    .is_mem_output_o(is_mem_output),
    .load_store_ready_o(mem_load_store_ready_i),
    .load_data_o(mem_load_data_i)
);

StallBus stallbus(
    .if_stall_req_i(if_stall_req_o),
    .id_stall_req_i(id_stall_req_o),
    .mem_stall_req_i(mem_stall_req_o),

    .if_stall_enable_o(if_stall_enable_i),
    .id_stall_enable_o(id_stall_enable_i),
    .ex_stall_enable_o(ex_stall_enable_i),
    .mem_stall_enable_o(mem_stall_enable_i),
    .wb_stall_enable_o(wb_stall_enable_i)
);

Register register(
    .clk(clk_in),
    .rst(rst_in),

    .rs1_enable_i(id_rs1_read_enable_o),
    .rs2_enable_i(id_rs2_read_enable_o),
    .rs1_addr_i(id_rs1_addr_o),
    .rs2_addr_i(id_rs2_addr_o),
    .rs1_data_o(id_rs1_data_i),
    .rs2_data_o(id_rs2_data_i),

    .rd_enable_i(wb_rd_write_enable_i),
    .rd_addr_i(wb_rd_addr_i),
    .rd_data_i(wb_rd_data_i),

    .dbgregs_o(dbgreg_dout)
);

assign pcreg_jump_enable_i = ex_jump_enable_o | id_jump_enable_o;
assign pcreg_jump_pc_i = (ex_jump_enable_o)? ex_jump_pc_o: id_jump_pc_o; // B_func taken/JALR: ex_jump; JAL/JALR: id_jump

PCReg pc_reg(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .stall_enable(if_stall_enable_i),

    .jump_enable_i(pcreg_jump_enable_i),
    .jump_pc_i(pcreg_jump_pc_i),

    .inst_ready_i(if_inst_ready_o),

    .pc_enable_o(if_pc_enable_i),
    .pc_o(if_pc_i),
    .pc_jump_enable_o(if_pc_jump_enable_i)
);

InstFetch inst_fetch(
    .stall_req_o(if_stall_req_o),

    .pc_enable_i(if_pc_enable_i),
    .pc_i(if_pc_i),
    .pc_jump_enable_i(if_pc_jump_enable_i),

    .if_from_ram_enable_o(if_from_ram_enable_o),
    .pc_o(if_pc_o),
    .pc_jump_enable_o(if_pc_jump_enable_o),

    .is_if_output_i(is_if_output),
    .inst_ready_i(if_inst_ready_i),
    .inst_i(if_inst_i),

    .inst_ready_o(if_inst_ready_o),

    .next_pc_o(if_next_pc_o),
    .inst_o(if_inst_o)
);

wire if_id_rst_i = rst_in; // | id_jump_enable_o | ex_jump_enable_o;
// JAL/AUIPC detected in ID | B_func taken/JALR detected in EX, reset IF_ID(NOP).

IF_ID if_id(
    .clk(clk_in),
    .rst(if_id_rst_i),
    .rdy(rdy_in),
    .stall_enable(id_stall_enable_i),

    .if_next_pc(if_next_pc_o),
    .if_inst(if_inst_o),
    .id_next_pc(id_next_pc_i),
    .id_inst(id_inst_i)
);

InstDecode inst_decode(
    .next_pc_i(id_next_pc_i),
    .inst_i(id_inst_i),

    .stall_req_o(id_stall_req_o),

    // Read after LOAD signal from ID_EX(last inst)
    .last_is_load_i(last_is_load),
    .last_load_rd_addr_i(last_load_rd_addr),

    .stall_req_resume_i(id_stall_req_resume),

    // data from Reg
    .rs1_data_i(id_rs1_data_i),
    .rs2_data_i(id_rs2_data_i),

    // addr to Reg
    .rs1_read_enable_o(id_rs1_read_enable_o),
    .rs2_read_enable_o(id_rs2_read_enable_o),
    .rs1_addr_o(id_rs1_addr_o),
    .rs2_addr_o(id_rs2_addr_o),

    // Forwarding sources from EX
    .rd_ready_ex_fw_i(ex_rd_ready_o), // ready: LOAD is not ready
    .rd_addr_ex_fw_i(ex_rd_addr_o),
    .rd_data_ex_fw_i(ex_rd_data_o),

    // Forwarding sources from MEM
    .rd_ready_mem_fw_i(mem_rd_write_enable_o),
    .rd_addr_mem_fw_i(mem_rd_addr_o),
    .rd_data_mem_fw_i(mem_rd_data_o),

    // to ID_EX
    .rs1_data_o(id_rs1_data_o),
    .rs2_data_o(id_rs2_data_o),
    .aluop_o(id_aluop_o),
    .alusel_o(id_alusel_o),
    .funct3_o(id_funct3_o),
    .imm_o(id_imm_o),
    .rd_addr_o(id_rd_addr_o),
    .rd_write_enable_o(id_rd_write_enable_o),

    .next_pc_o(id_next_pc_o),
    .jump_pc_o(id_jump_pc_o),

    .jump_enable_o(id_jump_enable_o)
);

wire id_ex_jump_rst = ex_jump_enable_o; // FIXME:
// B_func taken/JALR detected in EX | Read after LOAD stall: reset ID_EX(NOP)

ID_EX id_ex(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .stall_enable(ex_stall_enable_i),
    .jump_rst(id_ex_jump_rst),

    .id_rs1_data(id_rs1_data_o),
    .id_rs2_data(id_rs2_data_o),
    .id_aluop(id_aluop_o),
    .id_alusel(id_alusel_o),
    .id_funct3(id_funct3_o),
    .id_imm(id_imm_o),
    .id_rd_addr(id_rd_addr_o),
    .id_rd_write_enable(id_rd_write_enable_o),

    .id_next_pc(id_next_pc_o),
    .id_jump_pc(id_jump_pc_o),

    .ex_rs1_data(ex_rs1_data_i),
    .ex_rs2_data(ex_rs2_data_i),
    .ex_aluop(ex_aluop_i),
    .ex_alusel(ex_alusel_i),
    .ex_funct3(ex_funct3_i),
    .ex_imm(ex_imm_i),
    .ex_rd_addr(ex_rd_addr_i),
    .ex_rd_write_enable(ex_rd_write_enable_i),

    .ex_next_pc(ex_next_pc_i),
    .ex_jump_pc(ex_jump_pc_i),

    // LOAD signal
    .last_is_load(last_is_load),
    .last_load_rd_addr(last_load_rd_addr)
);

Execution excution(
    .rs1_data_i(ex_rs1_data_i),
    .rs2_data_i(ex_rs2_data_i),
    .aluop_i(ex_aluop_i),
    .alusel_i(ex_alusel_i),
    .funct3_i(ex_funct3_i),
    .imm_i(ex_imm_i),
    .rd_addr_i(ex_rd_addr_i),
    .rd_write_enable_i(ex_rd_write_enable_i),

    .next_pc_i(ex_next_pc_i),
    .jump_pc_i(ex_jump_pc_i),

    .store_data_o(ex_store_data_o),
    .load_enable_o(ex_load_enable_o),
    .store_enable_o(ex_store_enable_o),
    .load_store_addr_o(ex_load_store_addr_o),
    .funct3_o(ex_funct3_o),

    .rd_write_enable_o(ex_rd_write_enable_o),
    .rd_data_o(ex_rd_data_o),
    .rd_addr_o(ex_rd_addr_o),
    .rd_ready_o(ex_rd_ready_o),

    .jump_pc_o(ex_jump_pc_o),
    .jump_enable_o(ex_jump_enable_o)
);

wire ex_mem_rst_i = rst_in | id_stall_req_resume;

EX_MEM ex_mem(
    .clk(clk_in),
    .rst(ex_mem_rst_i),
    .rdy(rdy_in),
    .stall_enable(mem_stall_enable_i),

    .ex_rd_data(ex_rd_data_o),
    .ex_store_data(ex_store_data_o),
    .ex_load_enable(ex_load_enable_o),
    .ex_store_enable(ex_store_enable_o),
    .ex_load_store_addr(ex_load_store_addr_o),
    .ex_funct3(ex_funct3_o),
    .ex_rd_addr(ex_rd_addr_o),
    .ex_rd_write_enable(ex_rd_write_enable_o),

    .mem_wr_enable(mem_wr_enable_i),
    .mem_wr(mem_wr_i),

    .mem_funct3(mem_funct3_i),
    .mem_rd_addr(mem_rd_addr_i),
    .mem_rd_write_enable(mem_rd_write_enable_i),
    .mem_rd_data(mem_rd_data_i),

    .mem_load_store_addr(mem_load_store_addr_i),
    .mem_load_store_type(mem_load_store_type_i),
    .mem_store_data(mem_store_data_i)
);

MemoryAccess memory_access(
    .wr_enable_i(mem_wr_enable_i),
    .wr_i(mem_wr_i),
    .funct3_i(mem_funct3_i),
    .rd_addr_i(mem_rd_addr_i),
    .rd_write_enable_i(mem_rd_write_enable_i),
    .rd_data_i(mem_rd_data_i),

    .stall_req_o(mem_stall_req_o),

    .wr_enable_o(mem_wr_enable_o),
    .wr_o(mem_wr_o),

    .is_mem_output_i(is_mem_output),
    .load_store_ready_i(mem_load_store_ready_i),
    .load_data_i(mem_load_data_i),

    .rd_data_o(mem_rd_data_o),
    .rd_addr_o(mem_rd_addr_o),
    .rd_write_enable_o(mem_rd_write_enable_o)
);

MEM_WB mem_wb(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .stall_enable(wb_stall_enable_i),

    .mem_rd_data(mem_rd_data_o),
    .mem_rd_addr(mem_rd_addr_o),
    .mem_rd_write_enable(mem_rd_write_enable_o),

    .wb_rd_data(wb_rd_data_i),
    .wb_rd_addr(wb_rd_addr_i),
    .wb_rd_write_enable(wb_rd_write_enable_i)
);


// simple WB: wb_xxx connected to registers

endmodule