module PCReg(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire jump_enable_i,
    input wire[`AddrLen - 1: 0] jump_pc_i,

    // from IF
    input wire inst_ready_i,

    // to IF
    output reg pc_enable_o,
    output reg[`AddrLen - 1: 0] pc_o,
    output reg pc_jump_enable_o
);
    // pc enable
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) pc_enable_o <= `Enable;
        end
        else pc_enable_o <= `Disable;
    end

    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                pc_jump_enable_o <= `Disable;
                if(jump_enable_i && !inst_ready_i) begin
                    pc_jump_enable_o <= `Enable;
                    pc_o <= jump_pc_i; // JUMP!
                end
                else if(!stall_enable && inst_ready_i) pc_o <= pc_o + 4; // if stalled, do not add pc
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
            pc_jump_enable_o <= `Disable;
        end
    end
endmodule