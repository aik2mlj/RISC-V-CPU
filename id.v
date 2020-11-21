module InstDecode(
    // clk is not needed here since it is combinational
    // From IF_ID
    input wire[`AddrLen - 1: 0] next_pc_i,
    input wire[`InstLen - 1: 0] inst_i,

    // From registers
    input wire[`RegLen - 1: 0] rs1_data_i,
    input wire[`RegLen - 1: 0] rs2_data_i,

    output reg stall_req_o,

    // To registers
    output reg rs1_read_enable_o,
    output reg rs2_read_enable_o,
    output reg[`RegAddrLen - 1: 0] rs1_addr_o,
    output reg[`RegAddrLen - 1: 0] rs2_addr_o,

    // To ALU
    output reg[`RegLen - 1: 0] rs1_data_o,
    output reg[`RegLen - 1: 0] rs2_data_o,
    output reg[`AluOpLen - 1: 0] aluop_o,
    output reg[`AluSelLen - 1: 0] alusel_o,
    output reg[`RegLen - 1: 0] imm_o,
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    output reg rd_write_enable_o,

    output reg[`AddrLen - 1: 0] next_pc_o, // pc + 4
    output reg[`AddrLen - 1: 0] jump_pc_o, // pc + imm, to EX and to IF
    output reg jump_enable_o
);
    wire[`OpcodeLen - 1: 0] opcode = inst[6: 0];
    reg imm_enable;

    always @(*) begin
        rs1_addr_o = inst_i[19: 15];
        rs2_addr_o = inst_i[24: 20];
        rd_addr_o = inst_i[11: 7];
    end


    always @(*) begin
        aluop_o = {1'b0, inst_i[14: 12]};
        imm_enable = `Enable;
        jump_enable_o = `Disable;
        case(opcode_o)
            `LUI: begin
                imm_o = {inst_i[31: 12], {12{1'b0}}};
                alusel_o = `LUI_IMM;
                rs1_read_enable_o = `Disable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
            `AUIPC: begin
                imm_o = {inst_i[31: 12], {12{1'b0}}};
                alusel_o = `AUIPC_JPC;
                rs1_read_enable_o = `Disable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;

                jump_enable_o = `Enable; // JUMP!
            end
            `JAL: begin
                imm_o = {{12{inst_i[31]}}, inst_i[19: 12], inst_i[20], inst_i[30: 21], 1'b0};
                alusel_o = `JAL_NPC;
                rs1_read_enable_o = `Disable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;

                jump_enable_o = `Enable; // JUMP!
            end
            `JALR: begin
                imm_o = {{20{inst_i[31]}}, inst_i[31: 20]};
                alusel_o = `JALR_NPC;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
            `B_func: begin
                imm_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30: 25], inst_i[11: 8], 1'b0};
                alusel_o = `B_NAN;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Enable;
                rd_write_enable_o = `Disable;
            end
            `LOAD_func: begin
                imm_o = {{20{inst_i[31]}}, inst_i[31: 20]};
                alusel_o = `LOAD__RES;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
            `STORE_func: begin
                imm_o = {{20{inst_i[31]}}, inst_i[31: 25], inst_i[11: 7]};
                alusel_o = `STORE_RS2_RES;
                aluop_o = `STORE_ADDI; // STORE: rs1 + imm
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Enable;
                rd_write_enable_o = `Disable;
            end
            `R_I_func: begin
                imm_o = {{20{inst_i[31]}}, inst_i[31: 20]};
                alusel_o = `LOGIC_RES;
                if(inst_i[14: 12] == 3'b101) aluop_o[3] = inst_i[30]; // SRLI & SRAI
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
            `R_R_func: begin
                imm_enable = `Disable;
                aluop_o[3] = inst_i[30]; // funct7_bit
                alusel_o = `LOGIC_RES;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Enable;
                rd_write_enable_o = `Enable;
            end
            default: begin // NOP
                imm_o = `ZERO_WORD;
                aluop_o = `NOP_ALUOP;
                alusel_o = `NOP_ALUSEL;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
        endcase
        // end
        // else begin
        //     // NOP: ADDI x0 x0 0
        //     aluop_o = `NOP_ALUOP;
        //     alusel_o = `NOP_ALUSEL;
        //     rs1_read_enable_o = `Enable;
        //     rs2_read_enable_o = `Disable;
        //     rd_write_enable_o = `Enable;
        //     imm_o = `ZERO_WORD;
        //     imm_enable = `Enable;
        //     jump_enable_o = `Disable;
        // end
    end

    // calculate pc + imm for AUIPC, JAL, Branch
    always @(*) begin
        next_pc_o = next_pc_i;
        jump_pc_o = next_pc_i + imm_o - 4;
    end

    // Get rs1_data
    always @(*) begin
        if(rs1_read_enable_o) begin
            rs1_data_o = rs1_data_i;
        end
        else rs1_data_o = `ZERO_WORD;
    end
    // Get rs2_data
    always @(*) begin
        if(rs2_read_enable_o)
            rs2_data_o = rs2_data_i;
        else if(!imm_enable)
            rs2_data_o = imm_o; // If imm is disabled, rs2 = imm. (More convenient in EX)
        else rs2_data_o = `ZERO_WORD;
    end

endmodule