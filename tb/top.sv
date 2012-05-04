module top();
    /////////////////////////////////////////////////////
    // Clock Declaration and Generation                //
    /////////////////////////////////////////////////////
    bit fast_clk;
    bit slow_clk;
    int error = 0;
    int num_of_pkts = 4;
    
    initial
        fork
            forever #1 fast_clk = ~fast_clk;
            forever #9 slow_clk = ~slow_clk;
        join
    
    /////////////////////////////////////////////////////
    //  Memory interface instance                      //
    /////////////////////////////////////////////////////
    mem_interface mem_intf(fast_clk);
    
    /////////////////////////////////////////////////////
    //  Input interface instance                       //
    /////////////////////////////////////////////////////
    input_interface input_intf(fast_clk);
    
    /////////////////////////////////////////////////////
    //  output interface instance                      //
    /////////////////////////////////////////////////////
    output_interface output_intf[4](slow_clk);
    
    /////////////////////////////////////////////////////
    //  Program block Testcase instance                //
    /////////////////////////////////////////////////////
    Testcase TC ( );
    
    /////////////////////////////////////////////////////
    //  DUT instance and signal connection             //
    /////////////////////////////////////////////////////
    
    switch DUT        
        (// Global Interface                     // ------------
        .fast_clk     (fast_clk),                // I
        .slow_clk     (slow_clk),                // I
        .reset_b      (input_intf.reset_b),      // I
        // Input Port                           // ------------
        .data_stall  (input_intf.data_stall),   // I
        .data_valid  (input_intf.data_valid),   // I
        .data        (input_intf.data),         // I [07:00]
        // Port 0                               // ------------
        .port0       (output_intf[0].data_out), // O [07:00]
        .read_0      (output_intf[0].read),     // O
        .ready_0     (output_intf[0].ready),    // I
        // Port 1                               // ------------
        .port1       (output_intf[1].data_out), // O [07:00]
        .ready_1     (output_intf[1].ready),    // O
        .read_1      (output_intf[1].read),     // I
        // Port 2                               // ------------
        .port2       (output_intf[2].data_out), // O [07:00]
        .ready_2     (output_intf[2].ready),    // O
        .read_2      (output_intf[2].read),     // I
        // Port 3                               // ------------
        .port3       (output_intf[3].data_out), // O [07:00]
        .ready_3     (output_intf[3].ready),    // O
        .read_3      (output_intf[3].read),     // I
        // Memory Interface                     // ------------
        .mem_en      (mem_intf.mem_en),         // I
        .mem_rd_wr   (mem_intf.mem_rd_wr),      // I
        .mem_addr    (mem_intf.mem_addr),       // I [07:00]
        .mem_wdata   (mem_intf.mem_wdata),      // I [07:00]
        .mem_rdata   (mem_intf.mem_rdata));     // O [07:00]
endmodule
