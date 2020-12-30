module PCReg(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire jump_enable_i,
    input wire[`AddrLen - 1: 0] jump_pc_i,

    // from IF
    input wire icache_hitted_i,
    input wire inst_ready_i,

    // to IF
    output reg[`AddrLen - 1: 0] pc_o,
    output reg pc_jump_enable_o
);

    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                // pc_jump_enable_o <= `Disable;
                if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) begin
                    // pc_jump_enable_o <= `Enable;
                    pc_o <= jump_pc_i;
                end
                else if(!stall_enable && (inst_ready_i || icache_hitted_i)) pc_o <= pc_o + 4; // if stalled, do not add pc
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
            // pc_jump_enable_o <= `Disable;
        end
    end

    always @(*) begin
        if(rst) pc_jump_enable_o = `Disable;
        else if(jump_enable_i && (icache_hitted_i || (!icache_hitted_i && !inst_ready_i))) pc_jump_enable_o = `Enable;
        else pc_jump_enable_o = `Disable;
    end
endmodule