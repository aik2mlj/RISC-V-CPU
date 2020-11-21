`define ZERO_BYTE   8'b00000000
`define ZERO_WORD   32'h00000000
`define X0          5'b00000

`define InstLen     32
`define AddrLen     32
`define ByteLen     8
`define RegAddrLen  5
`define RegLen      32
`define RegNum      32

// ROM & RAM size
`define RAM_SIZE        131072
`define RAM_SIZELOG2    17

// Opcode
`define OpcodeLen   7
`define NOP         7'b0010011 // ADDI x0 x0 0
`define LUI         7'b0110111
`define AUIPC       7'b0010111
`define JAL         7'b1101111
`define JALR        7'b1100111
`define B_func      7'b1100011
`define LOAD_func   7'b0000011
`define STORE_func  7'b0100011
`define R_I_func    7'b0010011
`define R_R_func    7'b0110011

// Enable & Disable
`define Enable  1'b1
`define Disable 1'b0
`define True    1'b1
`define False   1'b0

// Read & Write
`define Read    1'b0
`define Write   1'b1

/*
// Funct3
`define Funct3Len   3
`define NFunct3     3'b000 // ADDI

// B_func
`define BEQ     3'b000
`define BNE     3'b001
`define BLT     3'b100
`define BGE     3'b101
`define BLTU    3'b110
`define BGEU    3'b111
// LOAD_func
`define LB      3'b000
`define LH      3'b001
`define LW      3'b010
`define LBU     3'b100
`define LHU     3'b101
// STORE_func
`define SB      3'b000
`define SH      3'b001
`define SW      3'b010
// R_I_func
`define ADDI    3'b000
`define SLLI    3'b001
`define SLTI    3'b010
`define SLTIU   3'b011
`define XORI    3'b100
`define SRLI_AI 3'b101
`define ORI     3'b110
`define ANDI    3'b111
// R_R_func
`define ADD_SUB 3'b000
`define SLL     3'b001
`define SLT     3'b010
`define SLTU    3'b011
`define XOR     3'b100
`define SRL_SRA 3'b101
`define OR      3'b110
`define AND     3'b111
*/

`define Funct3Len   3
`define NFunct3     3'b000 // ADDI
`define AluOpLen    4
`define NOP_ALUOP   4'b0000 // ADD

`define ADD     4'b0000
`define STORE_ADDI    4'b1111 // used for rs1 + imm in STORE
`define SUB     4'b1000
`define SLL     4'b0001
`define SLT     4'b0010
`define SLTU    4'b0011
`define XOR     4'b0100
`define SRL     4'b0101
`define SRA     4'b1101
`define OR      4'b0110
`define AND     4'b0111

// B_func
`define BEQ     3'b000
`define BNE     3'b001
`define BLT     3'b100
`define BGE     3'b101
`define BLTU    3'b110
`define BGEU    3'b111
// LOAD_func
`define LB      3'b000
`define LH      3'b001
`define LW      3'b010
`define LBU     3'b100
`define LHU     3'b101
// STORE_func
`define SB      3'b000
`define SH      3'b001
`define SW      3'b010

`define AluSelLen   3
`define NOP_ALUSEL      3'b101 // LOGIC_RES

`define LUI_IMM         3'b000
`define JAL_NPC         3'b001
`define JALR_NPC        3'b010
`define AUIPC_JPC       3'b011
`define B_NAN           3'b100
`define LOAD__RES       3'b101
`define STORE_RS2_RES   3'b110
`define LOGIC_RES       3'b111


