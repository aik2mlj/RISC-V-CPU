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
    reg[`RegLen - 1: 0] regs[0: `RegNum - 1];

    // rst
    always @(posedge clk) begin
        if(rst) begin
            for (integer i = 0; i < `RegNum; i = i + 1) begin
                regs[i] <= `ZERO_WORD;
            end
        end
    end

    // TODO: add data dependency
    // read 1
    always @(*) begin
        if(!rst && rs1_enable_i) begin
            if(rs1_addr_i == `X0) begin
                rs1_data_o = `ZERO_WORD;
            end
            else if(rs1_addr_i == rd_addr_i && rd_enable_i) begin // When read addr == write addr
                rs1_data_o = rd_data_i;
            end
            else begin
                rs1_data_o = regs[rs1_addr_i];
            end
        end
        else begin
            rs1_data_o = `ZERO_WORD;
        end
    end
    // read 2
    always @(*) begin
        if(!rst && rs2_enable_i) begin
            if(rs2_addr_i == `X0) begin
                rs2_data_o = `ZERO_WORD;
            end
            else if(rs2_addr_i == rd_addr_i && rd_enable_i) begin // When read addr == write addr
                rs2_data_o = rd_data_i;
            end
            else begin
                rs2_data_o = regs[rs2_addr_i];
            end
        end
        else begin
            rs2_data_o = `ZERO_WORD;
        end
    end

    // write FIXME: sequential or combinational?
    always @(*) begin
        if(!rst && rd_enable_i) begin
            if(rd_addr_i != `X0)  begin
                regs[rd_addr_i] = rd_data_i;
            end
        end
    end

    // assign dbgregs_o = regs;

endmodule