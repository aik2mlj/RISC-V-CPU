module Register(
    input wire clk,
    input wire rst,

    input wire rs1_enable_i,
    input wire rs2_enable_i,
    input wire[`RegAddrLen - 1: 0] rs1_addr_i,
    input wire[`RegAddrLen - 1: 0] rs2_addr_i,
    output reg[`RegLen - 1: 0] rs1_data_o,
    output reg[`RegLen - 1: 0] rs2_data_o,

    input wire rd_enable_i,
    input wire[`RegAddrLen - 1: 0] rd_addr_i,
    input wire[`RegLen - 1: 0] rd_data_i
);
    reg[`RegLen - 1: 0] regs[0 : `RegNum - 1];

    // TODO: add data dependency
    // read 1
    always @(*) begin
        if(!rst && rs1_enable_i) begin
            if(s == `X0) begin
                s = `ZERO_WORD;
            end
            else if(s == rd_addr_i && rd_enable_i) begin // When read addr == write addr
                s = rd_data_i;
            end
            else begin
                s = regs[s];
            end
        end
        else begin
            s = `ZERO_WORD;
        end
    end
    // read 2
    always @(*) begin
        if(!rst && rs2_enable_i) begin
            if(s == `X0) begin
                s = `ZERO_WORD;
            end
            else if(s == rd_addr_i && rd_enable_i) begin // When read addr == write addr
                s = rd_data_i;
            end
            else begin
                s = regs[s];
            end
        end
        else begin
            s = `ZERO_WORD;
        end
    end
    // write FIXME: sequential or combinational?
    always @(*) begin
        if(!rst && rd_enable_i) begin
            if(rd_addr_i != `X0) regs[rd_addr_i] = rd_data_i;
        end
    end

endmodule