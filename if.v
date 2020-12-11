module InstFetch(
    output reg stall_req_o,

    // from PCReg
    input wire[`AddrLen - 1: 0] pc_i,

    // from MEMCTRL: whole word
    input wire memctrl_off_i,
    input wire inst_ready_i,
    input wire[`RegLen - 1: 0] inst_i,

    // to IF_ID
    output reg[`AddrLen - 1: 0] next_pc_o, // pc_o + 4, to if_id
    output reg[`InstLen - 1: 0] inst_o // Send to IF_ID
);
    always @(*) begin
        if(memctrl_off_i) stall_req_o = `Disable;
        else stall_req_o = `Enable;
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