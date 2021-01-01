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
    reg[12: 0] BHT[127: 0]; // [12: 4] is the tag, [1: 0] is the 0 2-bit predictor, [3: 2] is the 1 2-bit
    reg global_BHT; // 1 bit global BHT patern

    integer i;
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) begin
                    pc_o <= jump_pc_i;
                end
                else if(!stall_enable && (inst_ready_i || icache_hitted_i)) begin
                    if(BHT[pc_o[8: 2]][12: 4] == pc_o[17: 9] &&
                    ((global_BHT == 1'b0 && BHT[pc_o[8: 2]][1]) || (global_BHT == 1'b1 && BHT[pc_o[8: 2]][3])))
                        pc_o <= BTB[pc_o[8: 2]];
                    else pc_o <= pc_o + 4;
                end
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
        end
    end

    wire[6: 0] index = branch_pc_i[8: 2];

    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(is_branch_i) begin
                    BTB[index] <= branch_target_i;
                    BHT[index][12: 4] <= branch_pc_i[17: 9];
                    // local BHT feedback
                    if(global_BHT == 1'b0) begin
                        if(branch_taken_i && BHT[index][1: 0] < 2'b11)
                            BHT[index][1: 0] <= BHT[index][1: 0] + 1;
                        else if(!branch_taken_i && BHT[index][1: 0] > 2'b00)
                            BHT[index][1: 0] <= BHT[index][1: 0] - 1;
                    end
                    else begin
                        if(branch_taken_i && BHT[index][3: 2] < 2'b11)
                            BHT[index][3: 2] <= BHT[index][3: 2] + 1;
                        else if(!branch_taken_i && BHT[index][3: 2] > 2'b00)
                            BHT[index][3: 2] <= BHT[index][3: 2] - 1;
                    end
                    // global BHT feedback
                    if(branch_taken_i) global_BHT <= 1'b1;
                    else global_BHT <= 1'b0;
                end
            end
        end
        else begin
            global_BHT <= 1'b0;
            for(i = 0; i < 128; i = i + 1) begin
                BHT[i][12] <= 1'b1;
                BHT[i][3: 0] <= 4'b0101; // initially 01
            end
        end
    end

    always @(*) begin
        if(rst) pc_jump_enable_o = `Disable;
        else if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) pc_jump_enable_o = `Enable;
        else pc_jump_enable_o = `Disable;
    end
endmodule