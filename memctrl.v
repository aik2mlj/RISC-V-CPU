module MemCtrl(
    input wire clk,
    input wire rst,
    input wire rdy,

    // connect to RAM
    input wire[`ByteLen - 1: 0] ram_data_i,
    output reg[`ByteLen - 1: 0] ram_data_o,
    output reg[`AddrLen - 1: 0] ram_addr_o,
    output reg ram_wr_o,

    // from IF
    input wire if_from_ram_enable_i,
    input wire[`AddrLen - 1: 0] if_pc_i,
    input wire if_pc_jump_enable_i,
    // to IF
    output reg is_if_output_o,
    output reg if_inst_ready_o,
    output reg[`RegLen - 1: 0] if_inst_o,

    input wire id_stall_req_i, // for Read after LOAD stall
    // from ID
    input wire[`AddrLen - 1: 0] id_stall_pc_i, // used for id_stall_resume check
    // to ID
    output reg id_stall_req_resume_o, // Enabled after LOAD is ready

    // from MEM
    input wire mem_wr_enable_i,
    input wire mem_wr_i, // write/read signal (1 for write)
    input wire[`AddrLen - 1: 0] mem_next_pc_i, // used for id_stall_resume check
    // from EX_MEM
    input wire[`AddrLen - 1: 0] load_store_addr_i,
    input wire[1: 0] load_store_type_i, // how many bytes are required
    input wire[`RegLen - 1: 0] store_data_i,

    // to MEM
    output reg is_mem_output_o,
    output reg load_store_ready_o,
    output reg[`RegLen - 1: 0] load_data_o
);
    // finite state machine
    parameter RW0 = 1, RW1 = 2, RW2 = 3, RW3 = 4, RW4 = 5, OFF = 0;
    reg[2: 0] state, next_state;

    parameter NOout = 0, LOADout = 1, STOREout = 2, IFout = 3;
    reg[1: 0] output_state, next_output_state; // which output

    reg[`AddrLen - 1: 0] current_addr, next_addr;

    reg already_jumped, next_already_jumped;

// ----------- state transition logic -------------
    // state
    always @(*) begin
        if(!rst) begin
            if(output_state == IFout && if_pc_jump_enable_i && !already_jumped) begin // if pc jump, reset RW
                if(!if_from_ram_enable_i) next_state = OFF;
                else next_state = RW0;
            end
            else begin
                case(state)
                    OFF: begin
                        if(output_state != NOout) next_state = OFF;
                        else if(mem_wr_enable_i) next_state = RW0;
                        else if(if_from_ram_enable_i) next_state = RW0;
                        else next_state = OFF;
                    end

                    RW0: begin
                        if(output_state == STOREout && load_store_type_i == `LSB) next_state = OFF;
                        else next_state = RW1;
                    end
                    RW1: begin
                        if((output_state == LOADout && load_store_type_i == `LSB)
                        || (output_state == STOREout && load_store_type_i == `LSH)) next_state = OFF;
                        else next_state = RW2;
                    end
                    RW2: begin
                        if(output_state == LOADout && load_store_type_i == `LSH) next_state = OFF;
                        else next_state = RW3;
                    end
                    RW3: begin
                        if(output_state == STOREout) next_state = OFF;
                        else next_state = RW4;
                    end
                    RW4: next_state = OFF;
                    default: next_state = OFF;
                endcase
            end
        end
        else next_state = OFF;
    end

    // already jumped state
    always @(*) begin
        if(!rst) begin
            if(!already_jumped) begin
                if(output_state == IFout && if_pc_jump_enable_i) next_already_jumped = `True;
                else next_already_jumped = `False;
            end
            else begin
                if(state == OFF) next_already_jumped = `False;
                else next_already_jumped = `True;
            end
        end
        else next_already_jumped = `False;
    end

    // output state
    always @(*) begin
        if(!rst) begin
            if(output_state == IFout && if_pc_jump_enable_i && !already_jumped && !if_from_ram_enable_i)
                next_output_state = NOout;
            else begin
                case(state)
                    OFF: begin
                        if(output_state != NOout) next_output_state = NOout;
                        else if(mem_wr_enable_i) next_output_state = mem_wr_i? STOREout: LOADout;
                        else if(if_from_ram_enable_i) next_output_state = IFout;
                        else next_output_state = NOout;
                    end

                    default: next_output_state = output_state;
                endcase
            end
        end
        else next_output_state = NOout;
    end

    // addr
    always @(*) begin
        if(!rst) begin
            if(output_state == IFout && if_pc_jump_enable_i && !already_jumped) begin // if pc jump, update addr
                if(!if_from_ram_enable_i) next_addr = `ZERO_WORD;
                else next_addr = if_pc_i;
            end
            else begin
                case(state)
                    OFF: begin
                        if(mem_wr_enable_i) next_addr = load_store_addr_i;
                        else if(if_from_ram_enable_i) next_addr = if_pc_i;
                        else next_addr = `ZERO_WORD;
                    end

                    default: next_addr = current_addr + 1;
                endcase
            end
        end
        else next_addr = `ZERO_WORD;
    end

    // output state to IF/MEM
    always @(*) begin
        is_if_output_o = `False;
        is_mem_output_o = `False;
        if(output_state == IFout || output_state == NOout) is_if_output_o = `True;
        if(output_state != IFout) is_mem_output_o = `True;
    end

// ---------------- state flip-flops --------------------
    // LOAD/IF output data
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                case(state) // old value
                    RW1: begin
                        case(output_state) // old value(same)
                            LOADout: load_data_o[7: 0] <= ram_data_i;
                            IFout: if_inst_o[7: 0] <= ram_data_i;
                        endcase
                    end
                    RW2: begin
                        case(output_state)
                            LOADout: load_data_o[15: 8] <= ram_data_i;
                            IFout: if_inst_o[15: 8] <= ram_data_i;
                        endcase
                    end
                    RW3: begin
                        case(output_state)
                            LOADout: load_data_o[23: 16] <= ram_data_i;
                            IFout: if_inst_o[23: 16] <= ram_data_i;
                        endcase
                    end
                    RW4: begin
                        case(output_state)
                            LOADout: load_data_o[31: 24] <= ram_data_i;
                            IFout: if_inst_o[31: 24] <= ram_data_i;
                        endcase
                    end
                endcase
            end
        end
        else begin
            load_data_o <= `ZERO_WORD;
            if_inst_o <= `ZERO_WORD;
        end
    end

    // state/output/addr/already_jumped
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                state <= next_state;
                output_state <= next_output_state;
                current_addr <= next_addr;
                already_jumped <= next_already_jumped;
            end
        end
        else begin
            state <= OFF;
            output_state <= NOout;
            current_addr <= `ZERO_WORD;
            already_jumped <= `False;

            // next_state <= OFF;
            // next_output_state <= NOout;
            // next_addr <= `ZERO_WORD;
            // next_already_jumped <= `False;
        end
    end

    // resume ex/id/if when LOAD is ready (id stall caused by Read after LOAD)
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(id_stall_req_i && next_output_state == LOADout && next_state == OFF && id_stall_pc_i == mem_next_pc_i)
                    // LOAD off && is the last load.
                    id_stall_req_resume_o <= `Enable;
                else id_stall_req_resume_o <= `Disable;
            end
        end
        else id_stall_req_resume_o <= `Disable;
    end

    // LOAD/IF ready or not
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                load_store_ready_o <= `Disable;
                if_inst_ready_o <= `Disable;
                if(next_state == OFF) begin
                    if(next_output_state == LOADout || next_output_state == STOREout)
                        load_store_ready_o <= `Enable;
                    else if(next_output_state == IFout)
                        if_inst_ready_o <= `Enable;
                end
            end
        end
        else begin
            load_store_ready_o <= `Disable;
            if_inst_ready_o <= `Disable;
        end
    end

    // LOAD/IF/STORE addr_o/wr_o
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(next_state != OFF && next_state != RW4) begin // OFF/RW4: do not request read from RAM
                    case(next_output_state)
                        LOADout: begin
                            ram_addr_o <= next_addr;
                            ram_wr_o <= `Read;
                        end
                        IFout: begin
                            ram_addr_o <= next_addr;
                            ram_wr_o <= `Read;
                        end
                        STOREout: begin
                            ram_addr_o <= next_addr;
                            ram_wr_o <= `Write;
                        end
                        default: begin
                            ram_addr_o <= `ZERO_WORD;
                            ram_wr_o <= `Read;
                        end
                    endcase
                end
                else if(next_state == OFF) begin // when OFF, just read 0x0. hci has a bug causing consecutive write on 0x30000 failed.
                    ram_addr_o <= `ZERO_WORD;
                    ram_wr_o <= `Read;
                end
            end
        end
    end
    // STORE data out
    always @(posedge clk) begin
        if(!rst) begin
            if(rdy) begin
                if(next_output_state == STOREout) begin
                    case(next_state)
                        RW0: ram_data_o <= store_data_i[7: 0];
                        RW1: ram_data_o <= store_data_i[15: 8];
                        RW2: ram_data_o <= store_data_i[23: 16];
                        RW3: ram_data_o <= store_data_i[31: 24];
                    endcase
                end
            end
        end
    end

endmodule
