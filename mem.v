module MemoryAccess(
    // from EX_MEM
    input wire wr_enable_i,
    input wire wr_i,
    input wire[`Funct3Len - 1: 0] funct3_i, // for LOAD/STORE in MEM
    input wire[`RegAddrLen - 1: 0] rd_addr_i,
    input wire rd_write_enable_i,
    input wire[`RegLen - 1: 0] rd_data_i, // to rd

    output reg stall_req_o,

    // to MEMCTRL
    output reg wr_enable_o,
    output reg wr_o,
    // from MEMCTRL
    input wire is_mem_output_i,
    input wire load_store_ready_i,
    input wire[`RegLen - 1: 0] load_data_i,

    // to WB & MEM forwarding signals
    output reg[`RegLen - 1: 0] rd_data_o,
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    output reg rd_write_enable_o
);
    // rd addr/enable WB
    always @(*) begin
        rd_addr_o = rd_addr_i;
        rd_write_enable_o = rd_write_enable_i;
    end

    always @(*) begin
        if(wr_enable_i) begin
            if(load_store_ready_i) begin // LOAD/STORE is ready now
                if(wr_i == `Write) rd_data_o = `ZERO_WORD;
                else begin // LOAD
                    case(funct3_i)
                        // MEMCTRL only fetches data. Data extending here(signed/unsigned)
                        `LB:    rd_data_o = {{24{load_data_i[7]}}, load_data_i[7: 0]};
                        `LH:    rd_data_o = {{16{load_data_i[15]}}, load_data_i[15: 0]};
                        `LW:    rd_data_o = load_data_i;
                        `LBU:   rd_data_o = {24'b0, load_data_i[7: 0]};
                        `LHU:   rd_data_o = {16'b0, load_data_i[15: 0]};
                        default:rd_data_o = `ZERO_WORD;
                    endcase
                end
            end
            else rd_data_o = `ZERO_WORD;
        end
        else rd_data_o = rd_data_i;
    end

    // wr_enable for MEMCTRL: when ready, disable FIXME: may cause bugs
    always @(*) begin
        if(wr_enable_i) begin
            if(load_store_ready_i) begin
                wr_enable_o = `Disable;
                wr_o = `Read;
            end
            else begin
                wr_enable_o = wr_enable_i;
                wr_o = wr_i;
            end
        end
        else begin
            wr_enable_o = `Disable;
            wr_o = `Read;
        end
    end

    always @(*) begin
        if(wr_enable_i && is_mem_output_i) begin
            stall_req_o = ~load_store_ready_i;
        end
        else stall_req_o = `Disable;
    end

endmodule