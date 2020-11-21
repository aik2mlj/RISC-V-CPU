// Manage stall requests & stall enable signals
module StallBus(
    input wire if_stall_req_i,
    input wire id_stall_req_i,
    input wire mem_stall_req_i,
    input wire if_ctrl_stall_req_i,

    output wire if_stall_enable_o,
    output wire id_stall_enable_o,
    output wire ex_stall_enable_o,

    output wire id_reset_enable_o,
    output wire ex_reset_enable_o,
    output wire wb_reset_enable_o
);
    // stall all the stages BEFORE a stall requests.
    assign if_stall_enable_o = id_stall_req_i | mem_stall_req_i | if_ctrl_stall_req_i;
    assign id_stall_enable_o = id_stall_req_i | mem_stall_req_i;
    assign ex_stall_enable_o = mem_stall_req_i;

    assign id_reset_enable_o = if_stall_req_i;
    assign ex_reset_enable_o = id_stall_req_i;
    assign wb_reset_enable_o = mem_stall_req_i;
endmodule
