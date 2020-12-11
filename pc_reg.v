module PCReg(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire jump_enable_i,
    input wire[`AddrLen - 1: 0] jump_pc_i,

    // from MEMCTRL
    input wire pc_plus4_ready_i,
    input wire inst_ready_i,

    // to MEMCTRL
    output reg pc_enable_o,
    output reg[`AddrLen - 1: 0] pc_o, // also to IF
    output reg pc_jump_enable_o
);
    // pc enable
    always @(posedge clk) begin
        if(!rst) begin
            if(!stall_enable || pc_plus4_ready_i) pc_enable_o <= `Enable;
            else pc_enable_o <= `Disable; // pc stalled because of Read after LOAD: temporarily disable pc
        end
        else pc_enable_o <= `Disable;
    end

    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                pc_jump_enable_o <= `Disable;
                if(pc_plus4_ready_i)
                    pc_o <= pc_o + 4;
                else if(jump_enable_i && !inst_ready_i) begin
                    pc_jump_enable_o <= `Enable;
                    pc_o <= jump_pc_i; // JUMP!
                end
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
            pc_jump_enable_o <= `Disable;
        end
    end
endmodule