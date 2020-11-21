module InstFetch(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire stall_enable,

    input wire jump_enable_i,
    input wire[`AddrLen - 1: 0] jump_pc_i,

    output reg stall_req_o,

    // from/to MEMCTRL
    output reg pc_enable_o,
    output reg[`AddrLen - 1: 0] pc_o,
    input wire[`ByteLen - 1: 0] inst_8bit_i,

    // to ID
    output reg[`AddrLen - 1: 0] next_pc_o, // pc_o + 4, to if_id
    output reg[`InstLen - 1: 0] inst_o // Send to IF_ID
);

    reg[1: 0] counter4;
    // pc enable
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                pc_enable_o = `Enable;
            end
            else begin
                pc_enable_o = `Disable;
            end
        end
        else begin
            pc_enable_o = `Enable; // still enable
        end
    end

    // pc
    always @(posedge clk) begin
        next_pc_o <= pc_o + 4;
        if(!rst) begin
            if(rdy && !stall_enable) begin
                if(jump_enable_i) begin // jump
                    pc_o <= jump_pc_i;
                end
                else begin // 4 * (pc_o + 1)
                    pc_o <= pc_o + 1;
                end
            end
        end
        else begin
            pc_o <= `ZERO_WORD;
            next_pc_o <= `ZERO_WORD;
        end
    end
    // counter4
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                if(jump_enable_i) counter4 <= 2'b00;
                else counter4 <= counter4 + 1;
            end
        end
        else counter4 <= 2'b00;
    end
    // data & enable
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy && !stall_enable) begin
                case(counter4)
                    2'b00: begin
                        inst_o[7: 0] <= inst_8bit_i;
                        stall_req_o <= `Enable;
                    end
                    2'b01: begin
                        inst_o[15: 8] <= inst_8bit_i;
                        stall_req_o <= `Enable;
                    end
                    2'b10: begin
                        inst_o[23: 16] <= inst_8bit_i;
                        stall_req_o <= `Enable;
                    end
                    default: begin // loop ends, inst is ready.
                        inst_o[31: 24] <= inst_8bit_i;
                        stall_req_o <= `Disable;
                    end
                endcase
            end
            else stall_req_o <= `Disable; // IF is stalled, there's no need to perform another if-stall-request.
        end
        else stall_req_o <= `Disable; //FIXME:
    end

endmodule