module IF_ID(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire[`AddrLen - 1: 0] if_next_pc,
    input wire[`InstLen - 1: 0] if_inst,
    output reg[`AddrLen - 1: 0] id_next_pc,
    output reg[`InstLen - 1: 0] id_inst
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                id_next_pc <= if_next_pc;
                id_inst <= if_inst;
            end
        end
        else begin
            id_next_pc <= `ZERO_WORD;
            id_inst <= `ZERO_WORD; // Turn into NOP later in EX case clause
        end
    end
endmodule

module ID_EX(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire[`RegLen - 1: 0] id_rs1_data,
    input wire[`RegLen - 1: 0] id_rs2_data,
    input wire[`AluOpLen - 1: 0] id_aluop,
    input wire[`AluSelLen - 1: 0] id_alusel,
    input wire[`RegLen - 1: 0] id_imm,
    input wire[`RegAddrLen - 1: 0] id_rd_addr,
    input wire id_rd_write_enable,

    input wire[`AddrLen - 1: 0] id_next_pc,
    input wire[`AddrLen - 1: 0] id_jump_pc,

    output reg[`RegLen - 1: 0] ex_rs1_data,
    output reg[`RegLen - 1: 0] ex_rs2_data,
    output reg[`AluOpLen - 1: 0] ex_aluop,
    output reg[`AluSelLen - 1: 0] ex_alusel,
    output reg[`RegLen - 1: 0] ex_imm,
    output reg[`RegAddrLen - 1: 0] ex_rd_addr,
    output reg ex_rd_write_enable,

    output reg[`AddrLen - 1: 0] ex_next_pc,
    output reg[`AddrLen - 1: 0] ex_jump_pc
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                ex_rs1_data <= id_rs1_data;
                ex_rs2_data <= id_rs2_data;
                ex_aluop <= id_aluop;
                ex_alusel <= id_alusel;
                ex_imm <= id_imm;
                ex_rd_addr <= id_rd_addr;
                ex_rd_write_enable <= id_rd_write_enable;
                ex_next_pc <= id_next_pc;
                ex_jump_pc <= id_jump_pc;
            end
        end
        else begin
            // NOP
            ex_rs1_data <= `ZERO_WORD;
            ex_rs2_data <= `ZERO_WORD;
            ex_aluop <= `NOP_ALUOP;
            ex_alusel <= `NOP_ALUSEL;
            ex_imm <= `ZERO_WORD;
            ex_rd_addr <= `ZERO_WORD;
            ex_rd_write_enable <= `Enable;
            ex_next_pc <= `ZERO_WORD;
            ex_jump_pc <= `ZERO_WORD;
        end
    end
endmodule

module EX_MEM(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire [`RegLen - 1: 0] ex_data, // to rd(usually) or mem(STORE_func)
    input wire ex_load_enable,
    input wire ex_store_enable,
    input wire [`AddrLen - 1: 0] ex_load_store_addr,
    input wire [`Funct3Len - 1: 0] ex_funct3, // for LOAD/STORE in MEM
    input wire [`RegAddrLen - 1: 0] ex_rd_addr,
    input wire  ex_rd_write_enable,

    output reg[`RegLen - 1: 0] mem_data, // to rd(usually) or mem(STORE_func)
    output reg mem_load_enable,
    output reg mem_store_enable,
    output reg[`AddrLen - 1: 0] mem_load_store_addr,
    output reg[`Funct3Len - 1: 0] mem_funct3, // for LOAD/STORE in MEM
    output reg[`RegAddrLen - 1: 0] mem_rd_addr,
    output reg mem_rd_write_enable
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                mem_data <= ex_data;
                mem_load_enable <= ex_load_enable;
                mem_store_enable <= ex_store_enable;
                mem_load_store_addr <= ex_load_store_addr;
                mem_funct3 <= ex_funct3;
                mem_rd_addr <= ex_rd_addr;
                mem_rd_write_enable <= ex_rd_write_enable;
            end
        end
        else begin
            mem_data <= `ZERO_WORD;
            mem_load_enable <= `Disable;
            mem_store_enable <= `Disable;
            mem_load_store_addr <= `ZERO_WORD;
            mem_funct3 <= `NFunct3;
            mem_rd_addr <= `ZERO_WORD;
            mem_rd_write_enable <= `Enable;
        end
    end
endmodule

module MEM_WB(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire[`RegLen - 1: 0] mem_rd_data,
    input wire mem_rd_addr,
    input wire mem_rd_write_enable,

    output reg[`RegLen - 1: 0] wb_rd_data,
    output reg wb_rd_addr,
    output reg wb_rd_write_enable
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                wb_rd_data <= mem_rd_data;
                wb_rd_addr <= mem_rd_addr;
                wb_rd_write_enable <= mem_rd_write_enable;
            end
        end
        else begin
            wb_rd_data <= `ZERO_WORD;
            wb_rd_addr <= `X0;
            wb_rd_write_enable <= `Enable;
        end
    end
endmodule