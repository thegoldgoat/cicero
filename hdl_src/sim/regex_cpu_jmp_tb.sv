`timescale 1ns / 10ps

import instruction_package::*;

module regex_cpu_jmp_tb();
    parameter CLOCK_SEMI_PERIOD = 5  ;

    parameter  PC_WIDTH          = 8;
    parameter  CC_ID_BITS        = 2;
    parameter  CHARACTER_WIDTH   = 8;
    parameter  MEMORY_WIDTH      = 16;
    parameter  MEMORY_ADDR_WIDTH = 11;

    logic                             clk                               ;
    logic                             rst                               ;
    logic[(2**CC_ID_BITS)*CHARACTER_WIDTH-1:0]        current_characters     ;
    logic                             input_pc_valid                    ;
    logic[CC_ID_BITS-1:0]             input_cc_id                       ;
    logic[PC_WIDTH-1:0]               input_pc                          ;
    logic                             input_pc_ready                    ;
    logic                             memory_ready                      ;
    logic[MEMORY_ADDR_WIDTH-1:0]      memory_addr                       ;
    logic[MEMORY_WIDTH-1     :0]      memory_data                       ;
    logic                             memory_valid                      ;
    logic[CC_ID_BITS-1:0]             output_cc_id                      ;
    logic                             output_pc_valid                   ;
    logic[PC_WIDTH-1:0]               output_pc                         ;
    logic                             output_pc_ready                   ;
    logic                             accepts                           ;

    regex_cpu #(
        .PC_WIDTH          (PC_WIDTH          ),
        .CC_ID_BITS        (CC_ID_BITS        ),
        .CHARACTER_WIDTH   (CHARACTER_WIDTH   ),
        .MEMORY_WIDTH      (MEMORY_WIDTH      ),
        .MEMORY_ADDR_WIDTH (MEMORY_ADDR_WIDTH )
    ) a_cpu (
        .clk                             (  clk                           ),   
        .rst                             (rst                             ),
        .current_characters              (current_characters              ),
        .input_pc_valid                  (input_pc_valid                  ),
        .input_cc_id                     (input_cc_id                     ),
        .input_pc                        (input_pc                        ),
        .input_pc_ready                  (input_pc_ready                  ),
        .memory_ready                    (memory_ready                    ),
        .memory_addr                     (memory_addr                     ),
        .memory_data                     (memory_data                     ),
        .memory_valid                    (memory_valid                    ),
        .output_cc_id                    (output_cc_id                    ),
        .output_pc_valid                 (output_pc_valid                 ),
        .output_pc                       (output_pc                       ),
        .output_pc_ready                 (output_pc_ready                 ),
        .accepts                         (accepts                         )
    );

    // clock generator  
    always begin
        #CLOCK_SEMI_PERIOD clk = ~ clk;
    end

   task load_pc(  input reg[PC_WIDTH-1    :0] pc, 
                  input reg[CC_ID_BITS-1  :0] cc_id);
    begin
        if(input_pc_ready !== 1'b1)
        begin
            $display("basic block does not await pc");
            $stop();
        end
        input_pc_valid <= 1'b1;
        input_cc_id    <= cc_id;
        input_pc       <= pc;
        @(posedge clk);
        input_pc_valid <= 1'b0;
        @(posedge clk);
        if(input_pc_ready == 1'b1)
        begin
            $display("basic block waits a pc immediately after having taken one!");
            $stop();
        end
        @(posedge clk);
    end
    endtask

    task supply_memory(input reg[MEMORY_WIDTH-1     :0] value,
                       input reg[MEMORY_ADDR_WIDTH-1:0] addr);
    begin
        memory_ready <= 1'b1;

        if(memory_valid !== 1'b1)
        begin
            $display("basic block does not wait memory");
            $stop();
        end
        if(memory_addr !== addr)
        begin
            $display("basic block address mismatch %h != %h", memory_addr, addr);
            $stop();
        end
        @(posedge clk);
        memory_data  <= value;
        memory_ready <= 1'b0;
        @(posedge clk);
        if(memory_valid == 1'b1)
        begin
            $display("basic block want something from memory even if it had just fetched!");
            $stop();
        end
        
        
    end
    endtask

    task wait_pc_output( input reg[PC_WIDTH-1:0]          expected_pc,
                         input reg[CC_ID_BITS-1:0]        expected_output_cc_id,
                         input reg                        wait_immediately_after );
    begin
        @(posedge clk);
        output_pc_ready    <= 1'b1;

        if( output_pc_valid !== 1'b1)
        begin
            $display("basic block didn't need to produce pc!");
            $stop();
        end
        if(output_pc !== expected_pc)
        begin
            $display("basic block output pc %h != %h", output_pc, expected_pc);
            $stop();
        end
        if(output_cc_id !== expected_output_cc_id)
        begin
            $display("basic block output pc %h != %h", output_cc_id, expected_output_cc_id);
            $stop();
        end
        @(posedge clk);
        output_pc_ready    <=1'b0;
        @(posedge clk);
        if(output_pc_valid == 1'b1 && wait_immediately_after == 1'b0)
        begin
            $display("basic block outputted a pc immediately after having outputted one!");
            $stop();
        end
        
        
    end
    endtask



    initial begin
        reg [PC_WIDTH-1:0               ] a_pc;
        reg [CC_ID_BITS-1:0             ] a_cc_id;
        reg [CHARACTER_WIDTH-1:0        ] a_character;
        reg [INSTRUCTION_DATA_WIDTH-1:0 ] a_jmp_amount;
        reg [PC_WIDTH-1:0               ] max_pc;
        reg [INSTRUCTION_DATA_WIDTH-1:0 ] max_jmp_amount;
        max_pc          = 255;
        max_jmp_amount  = 255;

        input_pc_valid  = 1'b0;
        memory_ready    = 1'b0;
        output_pc_ready = 1'b0;
        clk             = 1'b0;
        rst          <= 1'b0;
        @(posedge clk);
        rst          <= 1'b1;
        @(posedge clk);
        rst          <= 1'b0;
        repeat(30) @(posedge clk);

        for ( a_pc = 0; a_pc < max_pc ; a_pc +=1 ) begin
            for ( a_jmp_amount=0 ;a_jmp_amount<max_jmp_amount ;a_jmp_amount+=1 ) begin
                for( a_cc_id=0; a_cc_id < (2**CC_ID_BITS)-1; a_cc_id +=1) begin
                
                
                a_character = 8'h00;
                current_characters <= {(2**CC_ID_BITS){a_character}};

                load_pc(a_pc, a_cc_id);
                supply_memory({JMP, a_jmp_amount } ,a_pc);
                wait_pc_output(a_jmp_amount, a_cc_id, 1'b0);
                $display("OK jmp from %d for %d %d", a_pc, a_jmp_amount, a_cc_id);
    
                repeat (10)
                    begin
                        @(posedge clk);
                        if( output_pc_valid == 1'b1)
                        begin
                            $display("basic block didn't need to produce pc!");
                            $stop();
                        end
                        if( input_pc_ready != 1'b1)
                        begin
                            $display("basic block didn't expect a new pc to be executed!");
                            $stop();
                        end
                    end

                end
            end
        end
        

        $display("OK");
        $finish();

    end

endmodule