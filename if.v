module InstFetch(
    output reg stall_req_o,

    // from PCReg
    input wire pc_enable_i,
    input wire[`AddrLen - 1: 0] pc_i, // also to IF
    input wire pc_jump_enable_i,

    // to MEMCTRL
    output reg pc_enable_o,
    output reg[`AddrLen - 1: 0] pc_o,
    output reg pc_jump_enable_o,

    // from MEMCTRL: whole word
    input wire memctrl_off_i,
    input wire pc_plus4_ready_i,
    input wire inst_ready_i,
    input wire[`RegLen - 1: 0] inst_i,

    // to PCReg
    output reg pc_plus4_ready_o,
    output reg inst_ready_o,

    // to IF_ID
    output reg[`AddrLen - 1: 0] next_pc_o, // pc_o + 4, to if_id
    output reg[`InstLen - 1: 0] inst_o // Send to IF_ID
);
    always @(*) begin
        if(memctrl_off_i) stall_req_o = `Disable;
        else stall_req_o = `Enable;
    end

    always @(*) begin
        pc_enable_o = pc_enable_i;
        pc_o = pc_i;
        pc_jump_enable_o = pc_jump_enable_i;
    end

    always @(*) begin
        pc_plus4_ready_o = pc_plus4_ready_i;
        inst_ready_o = inst_ready_i;
    end

    // to IF_ID
    always @(*) begin
        if(inst_ready_i) begin
            next_pc_o = pc_i; // already the next pc
            inst_o = inst_i;
            // stall_req_o = `Disable;
        end
        else begin
            next_pc_o = `ZERO_WORD;
            inst_o = `ZERO_WORD;
            // stall_req_o = `Enable;
        end
    end

endmodule