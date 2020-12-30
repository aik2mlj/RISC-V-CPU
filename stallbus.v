// Manage stall requests & stall enable signals
module StallBus(
    input wire if_stall_req_i,
    input wire id_stall_req_i,
    input wire mem_stall_req_i,

    output wire if_stall_enable_o,
    output wire id_stall_enable_o,
    output wire ex_stall_enable_o,
    output wire mem_stall_enable_o,
    output wire wb_stall_enable_o
);
    // stall all the stages BEFORE a stall requests.
    assign if_stall_enable_o = if_stall_req_i | id_stall_req_i | mem_stall_req_i;
    assign id_stall_enable_o = if_stall_req_i | id_stall_req_i | mem_stall_req_i;
    assign ex_stall_enable_o = if_stall_req_i | id_stall_req_i | mem_stall_req_i;
    assign mem_stall_enable_o= if_stall_req_i | mem_stall_req_i;
    assign wb_stall_enable_o = mem_stall_req_i;
endmodule
