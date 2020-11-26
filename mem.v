module MEM(
    input wire rst, // needed for initializing counter

    input wire[`RegLen - 1: 0] rd_data_i, // to rd
    input wire[`RegLen - 1: 0] store_data_i, // to RAM
    input wire load_enable_i,
    input wire store_enable_i,
    input wire[`AddrLen - 1: 0] load_store_addr_i,
    input wire[`Funct3Len - 1: 0] funct3_i, // for LOAD/STORE in MEM
    input wire[`RegAddrLen - 1: 0] rd_addr_i,
    input wire rd_write_enable_i,

    output reg stall_req_o,

    // from/to MEMCTRL
    output reg wr_enable_o, // TODO: necessary?
    output reg wr_o, // write/read signal (1 for write)
    output reg[`AddrLen - 1: 0] load_store_addr_o,
    input wire[`ByteLen - 1: 0] load_data_8bit_i,
    output reg[`ByteLen - 1: 0] store_data_8bit_o,

    // to WB & MEM forwarding signals
    output reg[`RegLen - 1: 0] rd_data_o,
    output reg[`RegAddrLen - 1: 0] rd_addr_o,
    output reg rd_write_enable_o
);
    reg[2: 0] counter;

    // rd WB
    always @(*) begin
        rd_addr_o = rd_addr_i;
        rd_write_enable_o = rd_write_enable_i;
    end

    always @(*) begin
        if(rst) counter = 3'b000;
        else begin
            if(load_enable_i) begin
                wr_enable_o = `Enable;
                wr_o = `Read;
                case(funct3_i)
                    `LB: begin
                        if(counter == 3'b000) begin
                            load_store_addr_o = load_store_addr_i;
                            stall_req_o = `Enable;
                            counter = counter + 1;
                        end
                        else begin
                            rd_data_o = {{24{load_data_8bit_i[7]}}, load_data_8bit_i};
                            stall_req_o = `Disable;
                            counter = 3'b000;
                        end
                    end
                    `LH: begin
                        case(counter)
                            3'b000: begin
                                load_store_addr_o = load_store_addr_i;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b001: begin
                                rd_data_o[7: 0] = load_data_8bit_i;
                                load_store_addr_o = load_store_addr_i + 1;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            default: begin
                                rd_data_o[31: 8] = {{16{load_data_8bit_i[7]}}, load_data_8bit_i};
                                stall_req_o = `Disable;
                                counter = 3'b000;
                            end
                        endcase
                    end
                    `LW: begin
                        case(counter)
                            3'b000: begin
                                load_store_addr_o = load_store_addr_i;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b001: begin
                                rd_data_o[7: 0] = load_data_8bit_i;
                                load_store_addr_o = load_store_addr_i + 1;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b010: begin
                                rd_data_o[15: 8] = load_data_8bit_i;
                                load_store_addr_o = load_store_addr_i + 2;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b011: begin
                                rd_data_o[23: 16] = load_data_8bit_i;
                                load_store_addr_o = load_store_addr_i + 3;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            default: begin
                                rd_data_o[31: 24] = load_data_8bit_i;
                                stall_req_o = `Disable;
                                counter = 3'b000;
                            end
                        endcase
                    end
                    `LBU: begin
                        if(counter == 3'b000) begin
                            load_store_addr_o = load_store_addr_i;
                            stall_req_o = `Enable;
                            counter = counter + 1;
                        end
                        else begin
                            rd_data_o = {{24{1'b0}}, load_data_8bit_i};
                            stall_req_o = `Disable;
                            counter = 3'b000;
                        end
                    end
                    default: begin // LHU
                        case(counter)
                            3'b000: begin
                                load_store_addr_o = load_store_addr_i;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b001: begin
                                rd_data_o[7: 0] = load_data_8bit_i;
                                load_store_addr_o = load_store_addr_i + 1;
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            default: begin
                                rd_data_o[31: 8] = {{16{1'b0}}, load_data_8bit_i};
                                stall_req_o = `Disable;
                                counter = 3'b000;
                            end
                        endcase
                    end
                endcase
            end
            else if(store_enable_i) begin
                wr_enable_o = `Enable;
                wr_o = `Write;
                case(funct3_i)
                    `SB: begin
                        load_store_addr_o = load_store_addr_i;
                        store_data_8bit_o = store_data_i[7: 0];
                        stall_req_o = `Disable;
                    end
                    `SH: begin
                        if(counter == 3'b000) begin
                            load_store_addr_o = load_store_addr_i;
                            store_data_8bit_o = store_data_i[7: 0];
                            stall_req_o = `Enable;
                            counter = counter + 1;
                        end
                        else begin
                            load_store_addr_o = load_store_addr_i + 1;
                            store_data_8bit_o = store_data_i[15: 8];
                            stall_req_o = `Disable;
                            counter = 3'b000;
                        end
                    end
                    `SW: begin
                        case(counter)
                            3'b000: begin
                                load_store_addr_o = load_store_addr_i;
                                store_data_8bit_o = store_data_i[7: 0];
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b001: begin
                                load_store_addr_o = load_store_addr_i + 1;
                                store_data_8bit_o = store_data_i[15: 8];
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            3'b010: begin
                                load_store_addr_o = load_store_addr_i + 2;
                                store_data_8bit_o = store_data_i[23: 16];
                                stall_req_o = `Enable;
                                counter = counter + 1;
                            end
                            default: begin
                                load_store_addr_o = load_store_addr_i + 3;
                                store_data_8bit_o = store_data_i[31: 24];
                                stall_req_o = `Disable;
                                counter = 3'b000;
                            end
                        endcase
                    end
                endcase
            end
            else begin
                wr_enable_o = `Disable;
                rd_data_o = rd_data_i;
            end
        end
    end
endmodule