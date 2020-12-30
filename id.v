module InstDecode(
    // clk is not needed here since it is combinational
    // From IF_ID
    input wire[`AddrLen - 1: 0] next_pc_i,
    input wire[`InstLen - 1: 0] inst_i,

    output reg stall_req_o,
    output reg[`AddrLen - 1: 0] id_stall_pc_o, // used for id_stall_resume check in MEMCTRL

    // Read after LOAD signal from ID_EX(last inst)
    input wire last_is_load_i,
    input wire[`RegAddrLen - 1: 0] last_load_rd_addr_i,

    // from MEMCTRL (Read after LOAD resume signal)
    input wire stall_req_resume_i,

    // data From registers
    input wire[`RegLen - 1: 0] rs1_data_i,
    input wire[`RegLen - 1: 0] rs2_data_i,
    // To registers(data addr)
    output reg rs1_read_enable_o,
    output reg rs2_read_enable_o,
    output reg[`RegAddrLen - 1: 0] rs1_addr_o,
    output reg[`RegAddrLen - 1: 0] rs2_addr_o,

    // Forwarding sources from EX
    input wire rd_ready_ex_fw_i,
    input wire[`RegAddrLen - 1: 0] rd_addr_ex_fw_i,
    input wire[`RegLen - 1: 0] rd_data_ex_fw_i,

    // Forwarding sources from MEM
    input wire rd_ready_mem_fw_i,
    input wire[`RegAddrLen - 1: 0] rd_addr_mem_fw_i,
    input wire[`RegLen - 1: 0] rd_data_mem_fw_i,

    // To ID_EX
    output reg[`RegLen - 1: 0] rs1_data_o,
    output reg[`RegLen - 1: 0] rs2_data_o,
    output reg[`AluOpLen - 1: 0] aluop_o,
    output reg[`AluSelLen - 1: 0] alusel_o,
    output reg[`Funct3Len - 1: 0] funct3_o,
    output reg[`RegLen - 1: 0] imm_o,
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    output reg rd_write_enable_o,

    output reg[`AddrLen - 1: 0] next_pc_o, // pc + 4
    output reg[`AddrLen - 1: 0] jump_pc_o, // pc + imm, to EX and to IF

    // reset IF_ID & IF use jump_pc
    output reg jump_enable_o // JAL
);
    wire[`OpcodeLen - 1: 0] opcode = inst_i[6: 0];
    reg imm_enable;

    always @(*) begin
        rs1_addr_o = inst_i[19: 15];
        rs2_addr_o = inst_i[24: 20];
        rd_addr_o = inst_i[11: 7];
    end

    always @(*) begin
        aluop_o = {1'b0, inst_i[14: 12]};
        funct3_o = inst_i[14: 12];
        imm_enable = `Enable;
        jump_enable_o = `Disable;
        case(opcode)
            `LUI: begin
                imm_o = {inst_i[31: 12], {12{1'b0}}};
                aluop_o = `ADD;
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
                aluop_o = `ADD;
                alusel_o = `LOAD__RES;
                rs1_read_enable_o = `Enable;
                rs2_read_enable_o = `Disable;
                rd_write_enable_o = `Enable;
            end
            `STORE_func: begin
                imm_o = {{20{inst_i[31]}}, inst_i[31: 25], inst_i[11: 7]};
                aluop_o = `STORE_ADDI; // STORE: rs1 + imm
                alusel_o = `STORE_RS2_RES;
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
                imm_o = `ZERO_WORD;
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
        id_stall_pc_o = next_pc_i;
        next_pc_o = next_pc_i + 4;
        jump_pc_o = next_pc_i + imm_o;
    end

    // Get rs1_data
    always @(*) begin
        if(rs1_read_enable_o) begin
            if(rd_ready_ex_fw_i && rs1_addr_o == rd_addr_ex_fw_i) // Forwarding
                rs1_data_o = rd_data_ex_fw_i;
            else if(rd_ready_mem_fw_i && rs1_addr_o == rd_addr_mem_fw_i)
                rs1_data_o = rd_data_mem_fw_i;
            else rs1_data_o = rs1_data_i;
        end
        else rs1_data_o = `ZERO_WORD;
    end
    // Get rs2_data
    always @(*) begin
        if(rs2_read_enable_o) begin
            if(rd_ready_ex_fw_i && rs2_addr_o == rd_addr_ex_fw_i) // Forwarding
                rs2_data_o = rd_data_ex_fw_i;
            else if(rd_ready_mem_fw_i && rs2_addr_o == rd_addr_mem_fw_i)
                rs2_data_o = rd_data_mem_fw_i;
            else rs2_data_o = rs2_data_i;
        end
        else if(imm_enable)
            rs2_data_o = imm_o; // If imm is enabled, rs2 = imm. (More convenient in EX)
        else rs2_data_o = `ZERO_WORD;
    end

    // Read after LOAD STALL
    always @(*) begin
        if(last_is_load_i) begin
            if((rs1_read_enable_o && last_load_rd_addr_i == rs1_addr_o)
            || (rs2_read_enable_o && last_load_rd_addr_i == rs2_addr_o)) begin
                if(stall_req_resume_i) stall_req_o = `Disable; // id stall resumed by MEMCTRL
                else stall_req_o = `Enable;
            end
            else stall_req_o = `Disable;
        end
        else stall_req_o = `Disable;
    end

endmodule