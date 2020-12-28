module InstFetch(
    input wire clk,
    input wire rst,

    output reg stall_req_o,

    // from PCReg
    input wire pc_enable_i,
    input wire[`AddrLen - 1: 0] pc_i, // also to IF
    input wire pc_jump_enable_i,

    // to MEMCTRL
    output reg if_from_ram_enable_o,
    output reg[`AddrLen - 1: 0] pc_o,
    output reg pc_jump_enable_o,

    // from MEMCTRL: whole word
    input wire is_if_output_i,
    input wire inst_ready_i,
    input wire[`RegLen - 1: 0] inst_i,

    // to PCReg
    output reg inst_ready_o,

    // to IF_ID
    output reg[`AddrLen - 1: 0] next_pc_o, // pc_o + 4, to if_id
    output reg[`InstLen - 1: 0] inst_o // Send to IF_ID
);
    reg[40: 0] icache[127: 0];

    // i-cache here
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < 128; i = i + 1) begin
                icache[i][40] <= 1'b1;
            end
            pc_o <= `ZERO_WORD;
        end
        else begin
            if(inst_ready_i) begin
                icache[pc_o[8: 2]] <= {pc_o[17: 9], inst_i};
                pc_o <= pc_i + 4;
            end
            else begin
                pc_o <= pc_i;
            end
        end
    end

    always @(*) begin
        if(!rst) begin
            if_from_ram_enable_o = (icache[pc_o[8: 2]][40: 32] != pc_o[17: 9]) && !inst_ready_i;
        end
        else if_from_ram_enable_o = `Disable;
    end

    // always @(*) begin
    //     if(if_from_ram_enable_o && is_if_output_i) stall_req_o = `Enable;
    //     else stall_req_o = `Disable;
    // end

    // jump_enable to MEMCTRL
    always @(*) begin
        if(if_from_ram_enable_o) begin
            pc_jump_enable_o = pc_jump_enable_i;
        end
        else begin
            pc_jump_enable_o = `ZERO_WORD;
        end
    end

    always @(*) begin
        inst_ready_o = inst_ready_i;
    end

    // to IF_ID
    always @(*) begin
        if(rst) begin
            next_pc_o = `ZERO_WORD;
            inst_o = `ZERO_WORD;
            stall_req_o = `Disable;
        end
        else if(icache[pc_i[8: 2]][40: 32] == pc_i[17: 9]) begin
            next_pc_o = pc_i;
            inst_o = icache[pc_i[8: 2]][31: 0];
            stall_req_o = `Disable;
        end
        else if(inst_ready_i) begin
            next_pc_o = pc_i;
            inst_o = inst_i;
            stall_req_o = `Disable;
        end
        else begin
            next_pc_o = `ZERO_WORD;
            inst_o = `ZERO_WORD;
            stall_req_o = `Enable;
        end
    end

endmodule