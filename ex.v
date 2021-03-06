module Execution(
    input wire[`RegLen - 1: 0] rs1_data_i,
    input wire[`RegLen - 1: 0] rs2_data_i,
    input wire[`AluOpLen - 1: 0] aluop_i,
    input wire[`AluSelLen - 1: 0] alusel_i,
    input wire[`Funct3Len - 1: 0] funct3_i,
    input wire[`RegLen - 1: 0] imm_i,
    input wire[`RegAddrLen - 1: 0] rd_addr_i,
    input wire rd_write_enable_i,

    input wire[`AddrLen - 1: 0] next_pc_i, // pc + 4 (JAL/JALR -> MEM(rd))
    input wire[`AddrLen - 1: 0] jump_pc_i, // pc + imm (AUIPC -> MEM(rd), B_func -> IF)

    input wire[`AddrLen - 1: 0] predicted_pc_i, // the next predicted pc, directly from ID id_pc_o

    // to MEM
    output reg[`AddrLen - 1: 0] next_pc_o, // used for id_stall_resume check in MEM
    output reg[`RegLen - 1: 0] store_data_o, // to RAM
    output reg load_enable_o,
    output reg store_enable_o,
    output reg[`AddrLen - 1: 0] load_store_addr_o,
    output reg[`Funct3Len - 1: 0] funct3_o, // for LOAD/STORE in MEM
    output reg rd_write_enable_o,
    // to MEM & EX forwarding signals
    output reg[`RegLen - 1: 0] rd_data_o, // to rd
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    // EX forwarding signal
    output reg rd_ready_o,

    // to PcReg
    output reg is_branch_o,
    output reg branch_taken_o,
    output reg[`AddrLen - 1: 0] branch_pc_o, // where the branch inst. is
    output reg[`AddrLen - 1: 0] branch_target_o, // branch target(i.e. pc + imm)
    output reg[`AddrLen - 1: 0] jump_pc_o, // to IF (B_func: pc + imm/pc + 4, JALR: rs1 + imm)
    output reg jump_enable_o // 1 when branch is taken or JALR, to IF
);
    reg[`RegLen - 1: 0] res; // logic result
    reg cond; // branch taken signal

    always @(*) begin
        case(aluop_i)
            `ADD:   res = rs1_data_i + rs2_data_i;
            `STORE_ADDI: res = rs1_data_i + imm_i;
            `SUB:   res = rs1_data_i - rs2_data_i;
            `SLL:   res = rs1_data_i << (rs2_data_i[4: 0]);
            `SLT:   res = {{(`RegLen - 1){1'b0}}, ($signed(rs1_data_i) < $signed(rs2_data_i))};
            `SLTU:  res = {{(`RegLen - 1){1'b0}}, (rs1_data_i < rs2_data_i)};
            `XOR:   res = rs1_data_i ^ rs2_data_i;
            `SRL:   res = rs1_data_i >> (rs2_data_i[4: 0]); // logic right shift
            `SRA:   res = (rs1_data_i >> (rs2_data_i[4: 0])) | ({32{rs1_data_i[31]}} << (6'd32 - {1'b0, rs2_data_i[4: 0]})); // arithmetic right shift
            `OR:    res = rs1_data_i | rs2_data_i;
            `AND:   res = rs1_data_i & rs2_data_i;
            default:res = `ZERO_WORD;
        endcase
    end

    always @(*) begin
        case(aluop_i[2: 0])
            `BEQ:   cond = (rs1_data_i == rs2_data_i);
            `BNE:   cond = (rs1_data_i != rs2_data_i);
            `BLT:   cond = ($signed(rs1_data_i) < $signed(rs2_data_i));
            `BGE:   cond = ($signed(rs1_data_i) >= $signed(rs2_data_i));
            `BLTU:  cond = (rs1_data_i < rs2_data_i);
            `BGEU:  cond = (rs1_data_i >= rs2_data_i);
            default:cond = `Disable;
        endcase
    end

    always @(*) begin
        rd_data_o = `ZERO_WORD;
        store_data_o = `ZERO_WORD;
        load_enable_o = `Disable;
        store_enable_o = `Disable;
        load_store_addr_o = `ZERO_WORD;
        funct3_o = funct3_i;
        rd_addr_o = rd_addr_i;
        rd_write_enable_o = (rd_write_enable_i && rd_addr_i);
        rd_ready_o = rd_write_enable_o;
        case(alusel_i)
            `LUI_IMM: begin // load rd with imm
                rd_data_o = imm_i;
            end
            `AUIPC_JPC: begin // rd
                rd_data_o = jump_pc_i;
            end
            `JAL_NPC: begin // rd
                rd_data_o = next_pc_i;
            end
            `JALR_NPC: begin // rd
                rd_data_o = next_pc_i;
            end
            `B_NAN: begin
            end
            `LOAD__RES: begin // rd
                load_enable_o = `Enable;
                load_store_addr_o = res;
                rd_ready_o = `Disable;  // ready: LOAD is not ready
            end
            `STORE_RS2_RES: begin // RAM
                store_enable_o = `Enable;
                store_data_o = rs2_data_i;
                load_store_addr_o = res;
            end
            `LOGIC_RES: begin // rd
                rd_data_o = res;
            end
        endcase
    end

    // jump: B_func, JALR
    always @(*) begin
        is_branch_o = `False;
        branch_taken_o = `False;
        branch_pc_o = `ZERO_WORD;
        branch_target_o = `ZERO_WORD;
        jump_enable_o = `Disable;
        jump_pc_o = `ZERO_WORD;
        case(alusel_i)
            `B_NAN: begin
                is_branch_o = `True;
                branch_taken_o = cond;
                branch_pc_o = next_pc_i - 4;
                branch_target_o = jump_pc_i;
                jump_pc_o = cond? jump_pc_i: next_pc_i; // pc + imm or pc + 4
                jump_enable_o = predicted_pc_i == jump_pc_o? `Disable: `Enable; // If mispredicted, jump
            end
            `JALR_NPC: begin
                jump_enable_o = `Enable;
                jump_pc_o = res;
            end
        endcase
    end

    always @(*) begin
        next_pc_o = next_pc_i;
    end

endmodule
