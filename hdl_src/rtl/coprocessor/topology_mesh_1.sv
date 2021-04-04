module old_topology_mesh #(
    parameter  BB_N_X                   = 2 ,
    parameter  BB_N_Y                   = 2 ,
    parameter  PC_WIDTH                 = 8 ,
    parameter  LATENCY_COUNT_WIDTH      = 8 ,
    parameter  FIFO_COUNT_WIDTH         = 6 ,
    parameter  CHARACTER_WIDTH          = 8 ,
    parameter  MEMORY_WIDTH             = 16,
    parameter  MEMORY_ADDR_WIDTH        = 11,
    parameter  CACHE_WIDTH_BITS         = 0, 
    parameter  CACHE_BLOCK_WIDTH_BITS   = 2 ,
    parameter  PIPELINED                = 0,
    parameter  CONSIDER_PIPELINE_FIFO   = 0
)(
    input   wire                            clk,
    input   wire                            rst,

    input   wire [CHARACTER_WIDTH-1  :0]    cur_cc, 
    input   wire                            cur_is_even_character,

    memory_read_iface.out                   memory,
    channel_iface.in                        override,
    memory_read_iface.in                    memory_cc,
    input   wire                            enable,
    output  logic                           any_bb_accept,
    output  logic                           any_bb_running,
    output  logic                           all_bb_full    
);
    //2. provide memory access for BB (note that to create a tree of arbiters  are required 2*#BB -1 arbiters)
    memory_read_iface               #(.MEMORY_ADDR_WIDTH(MEMORY_ADDR_WIDTH), .MEMORY_WIDTH(MEMORY_WIDTH))  memory_bb [BB_N_Y*BB_N_X-1:0] ();
    //signals for basic blocks
    wire  [BB_N_X*BB_N_Y-1:0]       bb_running, bb_accepts, bb_full ;
    //station for each bb.
    channel_iface                   #(.N(PC_WIDTH+1), .LATENCY_COUNT_WIDTH(LATENCY_COUNT_WIDTH))           channel_x [(BB_N_Y+1)*(BB_N_X+1):0] ();
    channel_iface                   #(.N(PC_WIDTH+1), .LATENCY_COUNT_WIDTH(LATENCY_COUNT_WIDTH))           channel_y [(BB_N_Y+1)*(BB_N_X+1):0] ();

    /// sub modules 
    genvar x,y;
    
    for (y = 0; y < BB_N_Y; y+=1) 
        for (x = 0; x < BB_N_X; x+=1) 
        begin
            
            engine_and_station_xy #(
                .PC_WIDTH               (PC_WIDTH                       ),
                .LATENCY_COUNT_WIDTH    (LATENCY_COUNT_WIDTH            ),
                .FIFO_COUNT_WIDTH       (FIFO_COUNT_WIDTH               ),
                .CHARACTER_WIDTH        (CHARACTER_WIDTH                ),
                .MEMORY_WIDTH           (MEMORY_WIDTH                   ),
                .MEMORY_ADDR_WIDTH      (MEMORY_ADDR_WIDTH              ),
                .CACHE_WIDTH_BITS       (CACHE_WIDTH_BITS               ),
                .CACHE_BLOCK_WIDTH_BITS (CACHE_BLOCK_WIDTH_BITS         ),
                .PIPELINED              (PIPELINED                      ),
                .CONSIDER_PIPELINE_FIFO (CONSIDER_PIPELINE_FIFO         )
            )engine_and_station_i(
                .clk                    (clk                            ),
                .rst                    (rst                            ),
                .cur_cc                 (cur_cc                         ), 
                .cur_is_even_character  (cur_is_even_character          ),
                .memory                 (memory_bb  [   y *(BB_N_X  ) +x  ]     ),
                .x_in                   (channel_x  [   y *(BB_N_X+1) +x  ].in  ),
                .x_out                  (channel_x  [   y *(BB_N_X+1) +x+1].out ),
                .y_in                   (channel_y  [   y *(BB_N_X+1) +x  ].in  ),
                .y_out                  (channel_y  [(y+1)*(BB_N_X+1) +x  ].out ),
                .enable                 (enable                                 ),
                .bb_accepts             (bb_accepts [   y *BB_N_X     +x]       ),      
                .bb_running             (bb_running [   y *BB_N_X     +x]       ),      
                .bb_full                (bb_full    [   y *BB_N_X     +x]       )
            );

        end

    //              +---+   +---+
    //     +---+    |   |   |   |
    //+--->+ M |  +-v-+ | +-v-+ |
    //     | U +-->CPU+--->CPU+----+
    //   +-> X |  +---+ | +---+ |  |
    //   | +---+    |   |   |   |  |
    //   +-------------------------+
    //              |   |   |   |
    //            +-v-+ | +-v-+ |
    //        +--->CPU+--->CPU+----+
    //        |   +---+ | +---+ |  |
    //        |     |   |   |   |  |
    //        |     +---+   +---+  |
    //        |                    |
    //        +--------------------+

    arbiter_2_fixed #(
        .DWIDTH(PC_WIDTH+1)
    ) arbiter_tree_to_cope_with_pc_insertion (
        .in_0_ready  ( override.ready            ),
        .in_0_data   ( override.data             ),
        .in_0_valid  ( override.valid            ),
        .in_1_ready  ( channel_x[BB_N_X].ready   ),
        .in_1_data   ( channel_x[BB_N_X].data    ),
        .in_1_valid  ( channel_x[BB_N_X].valid   ),
        .out_ready   ( channel_x[0].ready        ),
        .out_data    ( channel_x[0].data         ),
        .out_valid   ( channel_x[0].valid        )
    );
    assign override.latency             = channel_x[0].latency;
    assign channel_x[BB_N_X].latency    = channel_x[0].latency;
    
    //   +----+
    //   |    |
    // +-v-+  |
    // |   |  |
    // +---+  |
    //   |    |
    // +-v-+  |
    // |   |  |
    // +---+  |
    //   |    |
    // +-v-+  |
    // |   |  |
    // +---+  |
    //   |    |
    //   +----+

    for (x = 0; x < BB_N_X ; x+=1 )
    begin
        assign channel_y[BB_N_Y*(BB_N_X+1)+x].ready           = channel_y[0     *x].ready;
        assign channel_y[0     *(BB_N_X+1)+x].data            = channel_y[BB_N_Y*x].data ;
        assign channel_y[0     *(BB_N_X+1)+x].valid           = channel_y[BB_N_Y*x].valid;        
        assign channel_y[BB_N_Y*(BB_N_X+1)+x].latency         = channel_y[0     *x].latency;
    end 

    //      +------+    +------+     +------+     +------+
    // +--->+      +--->+      +---->+      +---->+      +----+
    // |    |      |    |      |     |      |     |      |    |
    // |    +------+    +------+     +------+     +------+    |
    // |                                                      |
    // +------------------------------------------------------+

    for (y = 1; y < BB_N_Y ; y+=1 )
    begin
        assign channel_x[y*(BB_N_X+1)+BB_N_X].ready           = channel_x[y*(BB_N_X+1)+0     ].ready;
        assign channel_x[y*(BB_N_X+1)+0     ].data            = channel_x[y*(BB_N_X+1)+BB_N_X].data ;
        assign channel_x[y*(BB_N_X+1)+0     ].valid           = channel_x[y*(BB_N_X+1)+BB_N_X].valid;        
        assign channel_x[y*(BB_N_X+1)+BB_N_X].latency         = channel_x[y*(BB_N_X+1)+0     ].latency;
    end 

    //accept signal is simply or reduction of bb_accepts
    assign any_bb_accept  =  |bb_accepts;
    //running signal is defined high if any bb/channel contain an instruction
    assign any_bb_running =  |bb_running;
    assign all_bb_full    =  &(bb_full); 
    

    //wires to connect to generic bit arbiter remember there are BB_N_Y*BB_N_X + 1 (memory_cc) requests
    wire                               memory_ready_muxed [BB_N_Y*BB_N_X:0];
    wire [MEMORY_ADDR_WIDTH-1:0]       memory_addr_muxed  [BB_N_Y*BB_N_X:0];
    wire                               memory_valid_muxed [BB_N_Y*BB_N_X:0];

    for (y = 0; y < BB_N_Y ; y+=1 ) 
        for (x = 0; x < BB_N_X ; x+=1 ) 
        begin
            assign memory_bb             [y*BB_N_X+x].ready  = memory_ready_muxed    [y*BB_N_X+x];
            assign memory_addr_muxed     [y*BB_N_X+x]        = memory_bb[y*BB_N_X+x].addr              ;
            assign memory_valid_muxed    [y*BB_N_X+x]        = memory_bb[y*BB_N_X+x].valid             ;
        end
    assign     memory_cc.ready                    = memory_ready_muxed [BB_N_Y*BB_N_X]    ;
    assign     memory_addr_muxed  [BB_N_Y*BB_N_X] = memory_cc.addr                        ;
    assign     memory_valid_muxed [BB_N_Y*BB_N_X] = memory_cc.valid                       ;


    arbiter_rr_n #(
        .DWIDTH(MEMORY_ADDR_WIDTH),
        .N(BB_N_Y*BB_N_X+1) //memory_.*for_cc is mixed with memory_.*for_bb
    ) arbiter_tree_to_cope_with_memory_contention (
        .clk         ( clk                       ),
        .rst         ( rst                       ),
        .in_ready    ( memory_ready_muxed        ),
        .in_data     ( memory_addr_muxed         ),
        .in_valid    ( memory_valid_muxed        ),
        .out_ready   ( memory.ready              ),
        .out_data    ( memory.addr               ),
        .out_valid   ( memory.valid              )
    );

    //memory data is broadcasted but only the module 
    //which receives also a ready knows that it has
    //won the arbitration 
    assign memory_cc.data  = memory.data;
    for (y = 0; y < BB_N_Y ; y+=1 ) 
        for (x = 0; x < BB_N_X ; x+=1 ) 
        begin
            assign memory_bb[y*BB_N_X+x].data  = memory.data;
        end

    

endmodule
