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

    // Forwarding targets from ID
    input wire id_rs1_read_enable,
    input wire id_rs2_read_enable,
    input wire[`RegAddrLen - 1: 0] id_rs1_addr,
    input wire[`RegAddrLen - 1: 0] id_rs2_addr,

    // from ID
    input wire[`RegLen - 1: 0] id_rs1_data,
    input wire[`RegLen - 1: 0] id_rs2_data,
    input wire[`AluOpLen - 1: 0] id_aluop,
    input wire[`AluSelLen - 1: 0] id_alusel,
    input wire[`Funct3Len - 1: 0] id_funct3,
    input wire[`RegLen - 1: 0] id_imm,
    input wire[`RegAddrLen - 1: 0] id_rd_addr,
    input wire id_rd_write_enable,

    input wire[`AddrLen - 1: 0] id_next_pc,
    input wire[`AddrLen - 1: 0] id_jump_pc,

    // Forwarding sources from EX
    input wire rd_write_enable_ex_fw,
    input wire[`RegAddrLen - 1: 0] rd_addr_ex_fw,
    input wire[`RegLen - 1: 0] rd_data_ex_fw,

    // Forwarding sources from MEM
    input wire rd_write_enable_mem_fw,
    input wire[`RegAddrLen - 1: 0] rd_addr_mem_fw,
    input wire[`RegLen - 1: 0] rd_data_mem_fw,

    // to EX
    output reg[`RegLen - 1: 0] ex_rs1_data,
    output reg[`RegLen - 1: 0] ex_rs2_data,
    output reg[`AluOpLen - 1: 0] ex_aluop,
    output reg[`AluSelLen - 1: 0] ex_alusel,
    output reg[`Funct3Len - 1: 0] ex_funct3,
    output reg[`RegLen - 1: 0] ex_imm,
    output reg[`RegAddrLen - 1: 0] ex_rd_addr,
    output reg ex_rd_write_enable,

    output reg[`AddrLen - 1: 0] ex_next_pc,
    output reg[`AddrLen - 1: 0] ex_jump_pc,

    // to ID (Read after load: must stall)
    output reg last_is_load,
    output reg[`RegAddrLen - 1: 0] last_load_rd_addr
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                ex_aluop <= id_aluop;
                ex_alusel <= id_alusel;
                ex_funct3 <= id_funct3;
                ex_imm <= id_imm;
                ex_rd_addr <= id_rd_addr;
                ex_rd_write_enable <= id_rd_write_enable;
                ex_next_pc <= id_next_pc;
                ex_jump_pc <= id_jump_pc;
            end
        end
        else begin
            // NOP
            ex_aluop <= `NOP_ALUOP;
            ex_alusel <= `NOP_ALUSEL;
            ex_funct3 <= `NFunct3;
            ex_imm <= `ZERO_WORD;
            ex_rd_addr <= `ZERO_WORD;
            ex_rd_write_enable <= `Enable;
            ex_next_pc <= `ZERO_WORD;
            ex_jump_pc <= `ZERO_WORD;
        end
    end

    // Forwarding completed
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                if(id_rs1_read_enable && rd_write_enable_ex_fw && rd_addr_ex_fw == id_rs1_addr)
                    ex_rs1_data <= rd_data_ex_fw;
                else ex_rs1_data <= id_rs1_data;
                if(id_rs2_read_enable && rd_write_enable_ex_fw && rd_addr_ex_fw == id_rs2_addr)
                    ex_rs2_data <= rd_data_ex_fw;
                else ex_rs2_data <= id_rs2_data;
            end
        end
        else begin
            ex_rs1_data <= `ZERO_WORD;
            ex_rs2_data <= `ZERO_WORD;
        end
    end

    // Read after LOAD assertion.
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                if(id_alusel == `LOAD__RES) begin
                    last_is_load <= `True;
                    last_load_rd_addr <= id_rd_addr;
                end
                else begin
                    last_is_load <= `False;
                    last_load_rd_addr <= `X0;
                end
            end
        end
        else begin
            last_is_load <= `False;
            last_load_rd_addr <= `X0;
        end
    end
endmodule


module EX_MEM(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    // from EX
    input wire[`RegLen - 1: 0] ex_rd_data, // to rd
    input wire[`RegLen - 1: 0] ex_store_data, // to RAM
    input wire ex_load_enable,
    input wire ex_store_enable,
    input wire[`AddrLen - 1: 0] ex_load_store_addr,
    input wire[`Funct3Len - 1: 0] ex_funct3, // for LOAD/STORE in MEM
    input wire[`RegAddrLen - 1: 0] ex_rd_addr,
    input wire ex_rd_write_enable,

    // to MEM, then MEM to MEMCTRL
    output reg mem_wr_enable,
    output reg mem_wr,

    // to MEM
    output reg[`Funct3Len - 1: 0] mem_funct3,
    output reg[`RegAddrLen - 1: 0] mem_rd_addr,
    output reg mem_rd_write_enable,
    output reg[`RegLen - 1: 0] mem_rd_data,

    // to MEMCTRL
    output reg[`AddrLen - 1: 0] mem_load_store_addr,
    output reg[1: 0] mem_load_store_type,
    output reg[`RegLen - 1: 0] mem_store_data
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                mem_funct3 <= ex_funct3;
                mem_rd_addr <= ex_rd_addr;
                mem_rd_write_enable <= ex_rd_write_enable;
                mem_rd_data <= ex_rd_data;

                mem_wr_enable <= ex_load_enable | ex_store_enable;
                mem_wr <= ex_load_enable? `Read: `Write;
                mem_load_store_addr <= ex_load_store_addr;
                mem_load_store_type <= ex_funct3[1: 0];
                mem_store_data <= ex_store_data;
            end
        end
        else begin
            mem_funct3 <= `NFunct3;
            mem_rd_addr <= `X0;
            mem_rd_write_enable <= `Enable;
            mem_rd_data <= `ZERO_WORD;

            mem_wr_enable <= `Disable;
            mem_wr <= `Read;
            mem_load_store_addr <= `ZERO_WORD;
            mem_load_store_type <= 2'b00;
            mem_store_data <= `ZERO_WORD;
        end
    end
endmodule


module MEM_WB(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire[`RegLen - 1: 0] mem_rd_data,
    input wire[`RegAddrLen - 1: 0] mem_rd_addr,
    input wire mem_rd_write_enable,

    output reg[`RegLen - 1: 0] wb_rd_data,
    output reg[`RegAddrLen - 1: 0] wb_rd_addr,
    output reg wb_rd_write_enable
);
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
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