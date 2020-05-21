`timescale 1ns/1ps

import AXI_package::*;

module AXI_top(
    input  logic                               clk,
    input  logic                             reset, //reset has to be implemented using cmd_register?
    input  logic [REG_WIDTH-1:0]  data_in_register,
    input  logic [REG_WIDTH-1:0]  address_register,
//  input  logic [REG_WIDTH-1:0] start_pc_register,
    input  logic [REG_WIDTH-1:0] start_cc_pointer_register,
    input  logic [REG_WIDTH-1:0]      cmd_register,
    output logic [REG_WIDTH-1:0]   status_register,
    output logic [REG_WIDTH-1:0]   data_o_register
);
logic reset_master;
///// AXI
logic [REG_WIDTH-1:0]   status_register_next;

///// BRAM
parameter BRAM_READ_WIDTH            = 18;
parameter BRAM_WRITE_WIDTH           = 36;
parameter BRAM_READ_WIDTH_PARITY     =  2;
parameter BRAM_ADDR_WIDTH            = 11;
parameter BRAM_WE_WIDTH              =  4;

logic     [ BRAM_READ_WIDTH-1:0] bram_out;
logic     [ BRAM_READ_WIDTH-3:0] bram_payload;
logic     [BRAM_WRITE_WIDTH-1:0] bram_in;
logic     [ BRAM_ADDR_WIDTH-1:0] bram_addr;
logic     [   BRAM_WE_WIDTH-1:0] bram_we;
logic                            bram_valid_in;

assign bram_payload     = {bram_out[15+1:8+1],bram_out[7:0]};
assign data_o_register  = { {(32-BRAM_READ_WIDTH-BRAM_READ_WIDTH_PARITY){1'b0}},bram_payload};
///// Coprocessor
localparam PC_WIDTH                  = 8;
localparam CHARACTER_WIDTH           = 8;

logic                            memory_addr_from_coprocessor_ready;
logic     [ BRAM_ADDR_WIDTH-1:0] memory_addr_from_coprocessor;
logic                            memory_addr_from_coprocessor_valid;
logic                            start_valid, finish, accept;
//logic             [PC_WIDTH-1:0] start_pc; 
logic     [ BRAM_ADDR_WIDTH-1:0] start_cc_pointer;
logic                            start_ready;

/////

///// Sequential logic 
always_ff @(posedge clk) 
begin 
    if(reset || cmd_register == CMD_RESET)
    begin
        status_register <= STATUS_IDLE;
    end
    else
    begin
        status_register <= status_register_next;
    end
end

//// Combinational logic
always_comb 
begin
    if(reset)   reset_master           = 1'b1;
    else        reset_master           = 1'b0;

    status_register_next               = status_register;
    bram_addr                          = { (BRAM_ADDR_WIDTH) {1'b0} };
    bram_in                            = { (BRAM_WRITE_WIDTH){1'b0} };
    bram_valid_in                      = 1'b0;
    bram_we                            = { (BRAM_WE_WIDTH){1'b0}};

    memory_addr_from_coprocessor_ready = 1'b0;
    
    start_ready                        = 1'b0;
    start_cc_pointer                   = { (BRAM_ADDR_WIDTH){1'b0} }; 

    case(status_register)
    STATUS_IDLE:
    begin   
        case(cmd_register)
        CMD_WRITE: // to write the content of memory write in seuqence addr_0, cmd_write, data_0, 
        begin      // addr_1, data_1, ..., cmd_nop.
            
            bram_addr     = address_register[0+:BRAM_ADDR_WIDTH]; //use low
            bram_in       = { ^(data_in_register[31:24]),data_in_register[31:24], ^(data_in_register[23:16]), data_in_register[23:16], ^(data_in_register[15:8]), data_in_register[15:8],  ^(data_in_register[7:0]), data_in_register[7:0] };
            bram_valid_in = 1'b1;
            bram_we       = { (BRAM_WE_WIDTH){1'b1}};
        end
        CMD_READ:
        begin      
            bram_addr     = address_register[0+:BRAM_ADDR_WIDTH]; //use low
            bram_valid_in = 1'b1;
            memory_addr_from_coprocessor_ready = 1'b0;
        end
        CMD_RESET:
        begin
            reset_master = 1'b1;
        end
        CMD_START:
        begin
            start_cc_pointer    = start_cc_pointer_register[0+:BRAM_ADDR_WIDTH];
            //start_pc            = start_pc_register[0+:PC_WIDTH];
            start_ready         = 1'b1;
            bram_addr           = memory_addr_from_coprocessor;
            bram_valid_in       = memory_addr_from_coprocessor_valid;
            memory_addr_from_coprocessor_ready = 1'b1;
            if( start_valid )
            begin
                status_register_next = STATUS_RUNNING;
            end
        end
        endcase
    end
    STATUS_RUNNING:
    begin 
        // leave memory control to coprocessor
        bram_addr            = memory_addr_from_coprocessor;
        bram_valid_in        = memory_addr_from_coprocessor_valid;
        memory_addr_from_coprocessor_ready = 1'b1;
        if( finish )
        begin
            if(accept)  status_register_next = STATUS_ACCEPTED;
            else        status_register_next = STATUS_REJECTED;
        end
    end
    endcase

end

//////////////////////////
//   Module instances   //
//////////////////////////

bram #(
    .READ_WIDTH ( BRAM_READ_WIDTH ),            
    .WRITE_WIDTH( BRAM_WRITE_WIDTH),          
    .ADDR_WIDTH ( BRAM_ADDR_WIDTH ),            
    .WE_WIDTH   ( BRAM_WE_WIDTH   )           
) abram (
    .clk(     clk           ),
    .reset(   reset_master  ),
    .addr_i(  bram_addr     ),
    .data_i(  bram_in       ),
    .we(      bram_we       ),
    .valid_i( bram_valid_in ),
    .data_o(  bram_out      )
);

regex_coprocessor_single_bb #(
    .PC_WIDTH         (PC_WIDTH         ),
    .CHARACTER_WIDTH  (CHARACTER_WIDTH  ),
    .MEMORY_WIDTH     (BRAM_READ_WIDTH-BRAM_READ_WIDTH_PARITY),
    .MEMORY_ADDR_WIDTH(BRAM_ADDR_WIDTH  )
) a_regex_coprocessor (
    .clk                (clk),
    .reset              (reset_master),
    .memory_ready       (memory_addr_from_coprocessor_ready ),
    .memory_addr        (memory_addr_from_coprocessor       ),
    .memory_data        (bram_payload),
    .memory_valid       (memory_addr_from_coprocessor_valid ),
    .start_ready        (start_ready),
    //.start_pc           (start_pc),
    .start_cc_pointer   (start_cc_pointer),
    .start_valid        (start_valid),
    .finish             (finish),
    .accept             (accept)
);


endmodule
