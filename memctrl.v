module MemCtrl(
    // connect to RAM
    input wire[`ByteLen - 1: 0] ram_data_i,
    output reg[`ByteLen - 1: 0] ram_data_o,
    output reg[`AddrLen - 1: 0] ram_addr_o,
    output reg ram_wr_o,

    // IF
    input wire if_pc_enable_i,
    input wire if_pc_i,
    output reg[`ByteLen - 1: 0] if_inst_8bit_o,

    // to STALLBUS
    output reg if_ctrl_stall_req_o,

    // MEM
    input wire mem_wr_enable_i,
    input wire mem_wr_i, // write/read signal (1 for write)
    input wire[`AddrLen - 1: 0] load_store_addr_i,
    output reg[`ByteLen - 1: 0] load_data_8bit_o,
    input wire[`ByteLen - 1: 0] store_data_8bit_i
);

    // if_ctrl_stall_req_o
    always @(*) begin
        // mem first
        if(mem_wr_enable_i) begin
            if(if_pc_enable_i) if_ctrl_stall_req_o = `Enable;
            else if_ctrl_stall_req_o = `Disable;
        end
        else if_ctrl_stall_req_o = `Disable;
    end

    // to RAM
    always @(*) begin
        // mem first
        if(mem_wr_enable_i) begin
            ram_wr_o = mem_wr_i;
            ram_addr_o = load_store_addr_i;
            if(mem_wr_i == `Read) begin
                ram_data_o = `ZERO_WORD;
            end
            else begin
                ram_data_o = store_data_8bit_i;
            end
        end
        else if(if_pc_enable_i) begin
            ram_wr_o = `Read;
            ram_addr_o = if_pc_i;
            ram_data_o = `ZERO_WORD;
        end
        else begin // avoid latch & not to triggle ram
            ram_wr_o = ram_wr_o;
            ram_addr_o = ram_addr_o;
            ram_data_o = ram_data_o;
        end
    end

    // from RAM
    always @(*) begin
        load_data_8bit_o = `ZERO_WORD; // FIXME:
        if_inst_8bit_o = `ZERO_WORD;
        if(mem_wr_enable_i) begin
            if(mem_wr_i == `Read) begin
                load_data_8bit_o = ram_data_i; // FIXME: MEM_0 bug?
            end
        end
        else if(if_pc_enable_i) begin
            if_inst_8bit_o = ram_data_i;
        end
    end
endmodule
