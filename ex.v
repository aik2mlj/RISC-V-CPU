module Execute(
    input wire[`RegLen - 1: 0] rs1_data_i,
    input wire[`RegLen - 1: 0] rs2_data_i,
    input wire[`AluOpLen - 1: 0] aluop_i,
    input wire[`AluSelLen - 1: 0] alusel_i,
    input wire[`RegLen - 1: 0] imm_i,
    input wire[`RegAddrLen - 1: 0] rd_addr_i,
    input wire rd_write_enable_i,

    input wire[`AddrLen - 1: 0] next_pc_i, // pc + 4 (JAL/JALR -> MEM(rd))
    input wire[`AddrLen - 1: 0] jump_pc_i, // pc + imm (AUIPC -> MEM(rd), B_func -> IF)

    // to MEM
    output reg[`RegLen - 1: 0] store_data_o, // to RAM
    output reg load_enable_o,
    output reg store_enable_o,
    output reg[`AddrLen - 1: 0] load_store_addr_o,
    output reg[`Funct3Len - 1: 0] funct3_o, // for LOAD/STORE in MEM
    // to MEM & EX forwarding signals
    output reg[`RegLen - 1: 0] rd_data_o, // to rd
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    output reg rd_write_enable_o,

    // to IF
    output reg[`AddrLen - 1: 0] jump_pc_o, // to IF (B_func: pc + imm, JALR: rs1 + imm)
    output reg jump_enable_o // 1 when branch is taken or JALR, to IF
);
    reg[`RegLen - 1: 0] res; // logic result
    reg cond; // branch taken signal

    always @(*) begin
        case(aluop_i)
            `ADD:   res = rs1_data_i + rs2_data_i;
            `STORE_ADDI: res = rs1_data_i + imm_i;
            `SUB:   res = rs1_data_i - rs2_data_i;
            `SLL:   res = rs1_data_i << (rs2_data_i & 5'b11111);
            `SLT:   res = {{(`RegLen - 1){1'b0}}, ($signed(rs1_data_i) < $signed(rs2_data_i))};
            `SLTU:  res = {{(`RegLen - 1){1'b0}}, (rs1_data_i < rs2_data_i)};
            `XOR:   res = rs1_data_i ^ rs2_data_i;
            `SRL:   res = rs1_data_i >> (rs2_data_i & 5'b11111); // logic right shift
            `SRA:   res = $signed(rs1_data_i) >>> (rs2_data_i & 5'b11111); // arithmetic right shift
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
        funct3_o = aluop_i[`Funct3Len - 1: 0];
        rd_addr_o = rd_addr_i;
        rd_write_enable_o = rd_write_enable_i;
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
        case(alusel_i)
            `B_NAN: begin
                jump_enable_o = cond;
                jump_pc_o = jump_pc_i;
            end
            `JALR_NPC: begin
                jump_enable_o = `Enable;
                jump_pc_o = res;
            end
            default: begin
                jump_enable_o = `Disable;
                jump_pc_o = `ZERO_WORD;
            end
        endcase
    end

endmodule
