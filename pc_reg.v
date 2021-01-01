module PCReg(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire jump_enable_i, // sure to jump
    input wire[`AddrLen - 1: 0] jump_pc_i,
    // prediction feedback signals
    input wire is_branch_i, // is a jal/branch inst.
    input wire branch_taken_i, // this branch is taken
    input wire[`AddrLen - 1: 0] branch_pc_i,
    input wire[`AddrLen - 1: 0] branch_target_i,

    // from IF
    input wire icache_hitted_i,
    input wire inst_ready_i,

    // to IF
    output reg[`AddrLen - 1: 0] pc_o,
    output reg pc_jump_enable_o
);
    reg[`AddrLen - 1: 0] BTB[127: 0];
    reg[10: 0] BHT[127: 0]; // [10: 2] is the tag, [1: 0] is a 2-bit predictor

    integer i;
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) begin
                    pc_o <= jump_pc_i;
                end
                else if(!stall_enable && (inst_ready_i || icache_hitted_i)) begin
                    if(BHT[pc_o[8: 2]][10: 2] == pc_o[17: 9] && BHT[pc_o[8: 2]][1] == 1'b1) begin
                        pc_o <= BTB[pc_o[8: 2]];
                    end
                    else pc_o <= pc_o + 4; // if stalled, do not add pc
                end
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
        end
    end

    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(is_branch_i) begin
                    BTB[branch_pc_i[8: 2]] <= branch_target_i;
                    BHT[branch_pc_i[8: 2]][10: 2] <= branch_pc_i[17: 9];
                    if(branch_taken_i && BHT[branch_pc_i[8: 2]][1: 0] < 2'b11)
                        BHT[branch_pc_i[8: 2]][1: 0] <= BHT[branch_pc_i[8: 2]][1: 0] + 1;
                    else if(!branch_taken_i && BHT[branch_pc_i[8: 2]][1: 0] > 2'b00)
                        BHT[branch_pc_i[8: 2]][1: 0] <= BHT[branch_pc_i[8: 2]][1: 0] - 1;
                end
            end
        end
        else begin
            for(i = 0; i < 128; i = i + 1) begin
                BHT[i][10] <= 1'b1;
                BHT[i][1: 0] <= 2'b01; // initially 01
            end
        end
    end

    always @(*) begin
        if(rst) pc_jump_enable_o = `Disable;
        else if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) pc_jump_enable_o = `Enable;
        else pc_jump_enable_o = `Disable;
    end
endmodule