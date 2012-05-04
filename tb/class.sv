`timescale 1ns / 1ns

`define ENABLE      8'd1
`define DISABLE     8'd0
`define TRUE        8'd1
`define FALSE       8'd0

// Randomization Modes
`define ENABLE_SET  8'd2
//`define ENABLE_SEQ      8'd1
`define DISABLE     8'd0

`define BAD_LENGTH  8'd0
`define GOOD_LENGTH 8'd1

`define BAD_FCS     8'd0
`define GOOD_FCS    8'd1
    
`define BAD_DA      8'd0
`define GOOD_DA     8'd1

class int_constraint;
    // variables (properties)
    byte unsigned mode;
    byte unsigned max;
    byte unsigned min;

    // functions (methods)
    function new();
        constraint_mode_i(`ENABLE);
        set_max_constraint(8'd255);
        set_min_constraint(8'd0);
    endfunction

    function void constraint_mode_i(input byte unsigned _mode);
        this.mode = _mode;
    endfunction

    function void set_max_constraint(input byte unsigned _max);
        this.max = _max;
    endfunction

    function void set_min_constraint(input byte unsigned _min);
        this.min = _min;
    endfunction
endclass : int_constraint

class randi;
    // properties
    byte unsigned mode;
    byte unsigned value;
    int_constraint cons;
    static byte unsigned empty_set[];
    byte unsigned set[];

    // methods
    function new (byte unsigned _mode = `ENABLE, byte unsigned _value = 8'h00, byte unsigned _set [] = empty_set);
        this.mode  = _mode;
        this.set   = _set;
        this.value = _value;
        cons = new();
    endfunction

    function void rand_mode_i(input byte unsigned _mode);
        this.mode = _mode;
    endfunction

    function byte unsigned randomize_i( );
        if (this.mode == `ENABLE) begin
            if (this.cons.mode == `DISABLE) begin
                // set random value
                this.value = {$random};
                return `TRUE;
            end
            else begin
                // set random value
                for (int i = 0; i < 20; i++) begin
                    this.value = this.cons.min + {$random} % (this.cons.max - this.cons.min + 1);
                    if ((this.value >= this.cons.min) && (this.value <= cons.max)) begin
                        return `TRUE;
                        break;
                    end
                    else begin
                        $display("%m: could not generate constrained random value: %d >= %d <= %d", this.cons.min, this.value, this.cons.max);
                        return `FALSE;
                    end
                end
            end
        end
        else if (this.mode == `ENABLE_SET) begin
            this.value = set [{$random} % set.size];
            return `TRUE;
        end
        else begin
            $display("randi mode is disabled. enable to use randomize_i");
            return `FALSE;
        end
    endfunction : randomize_i
endclass : randi

class Packet;        
    randi fcs_kind; // Used as part of constraining packet type
    randi length_kind;
    randi length;
    randi da_kind;
    randi da;
    randi sa;
    randi data[]; //Payload using Maximum array,size is generated on the fly
    randi fcs;                                     
    int pkt_id;
    static int tot_pkts = 0;
    byte unsigned set[];

    function new(byte unsigned port_addrs[]);
        bit status = `TRUE;
        integer i;
        begin  
            pkt_id = tot_pkts++;
        
            this.fcs_kind = new();
            this.fcs_kind.cons.set_min_constraint(`BAD_FCS);
            this.fcs_kind.cons.set_max_constraint(`GOOD_FCS);
            this.fcs_kind.cons.constraint_mode_i(`ENABLE);
            status = status & this.fcs_kind.randomize_i();      
        
            this.length_kind = new();
            this.length_kind.cons.set_min_constraint(`BAD_LENGTH);
            this.length_kind.cons.set_max_constraint(`GOOD_LENGTH);
            this.length_kind.cons.constraint_mode_i(`ENABLE);        
            status = status & this.length_kind.randomize_i();
            
            this.length = new();
            this.length.cons.set_min_constraint(8'd254);
            this.length.cons.set_max_constraint(8'd255);
            this.length.cons.constraint_mode_i(`ENABLE);        
            status = status & this.length.randomize_i();
                                                           
            this.da_kind = new();
            this.da_kind.cons.set_min_constraint(`BAD_DA);
            this.da_kind.cons.set_max_constraint(`GOOD_DA);
            this.da_kind.cons.constraint_mode_i(`ENABLE);
            //status = status & this.da_kind.randomize_i();  
                
            /*set = new[4];
            set[0] = 8'h00;
            set[1] = 8'h11;
            set[2] = 8'h22;
            set[3] = 8'h33;*/
            this.da = new(`ENABLE_SET, port_addrs[0], port_addrs);
            //this.da.cons.set_min_constraint(8'd0);
            //this.da.cons.set_max_constraint(8'd255);
            //this.da.cons.constraint_mode_i(`DISABLE);
            status = status & this.da.randomize_i();
        
            this.sa = new();
            this.sa.cons.set_min_constraint(8'd0);
            this.sa.cons.set_max_constraint(8'd255);
            this.sa.cons.constraint_mode_i(`ENABLE);        
            status = status & this.sa.randomize_i();
        
            this.data = new[this.length.value];
            for(i = 0; i < this.length.value; i++) begin
                this.data[i] = new();
                this.data[i].cons.set_min_constraint(8'd0);
                this.data[i].cons.set_max_constraint(8'd255);
                this.data[i].cons.constraint_mode_i(`ENABLE);        
                status = status & this.data[i].randomize_i( ); 
            end
        
            fcs = new();
            fcs.cons.set_min_constraint(8'd0);
            fcs.cons.set_max_constraint(8'd255);
            fcs.cons.constraint_mode_i(`ENABLE);
        end
    endfunction : new
    
    function bit randomize_o();
        bit status = `TRUE;
        integer i = 0;
        begin
            status = status & length_kind.randomize_i();
            status = status & length.randomize_i(); 
            //status = status & da_kind.randomize_i();
            status = status & da.randomize_i();
            status = status & sa.randomize_i();
            this.data = new[this.length.value - 4];
            foreach (this.data[i]) begin
                this.data[i] = new ( );
                status = status & this.data[i].randomize_i();
            end
            status = status & fcs_kind.randomize_i();
            return status;
        end
    endfunction : randomize_o;

    /* method to calculate the fcs */
    function byte cal_fcs();
        byte unsigned result;
        begin
            result = 0;
            result = result ^ this.da.value;
            result = result ^ this.sa.value;
            result = result ^ this.length.value;
            for (int i = 0; i < data.size; i++) 
                result = result ^ this.data[i].value;
            // If we are generating a bad Frame Sequence Check Field, we will 
            // XOR a value of 1 into this field to create an invalid result. 
            // Otherwise, we will XOR a value of 0 into this field which will 
            // result in a valid Frame Sequence Check. 
            result = (result ^ this.fcs_kind.value);
            return result;
        end
    endfunction : cal_fcs

    /* method to print the packet fields */
    function void display();
    int line_wrap_cnt = 0;
    begin
        $display("+---------------------- PACKET  KIND -------------------------+ ");
        $display("| fcs_kind    : %s ", this.fcs_kind.value ? "GOOD_FCS" : "BAD_FCS");
        $display("| length_kind : %s ", this.length_kind.value ? "GOOD_LENGTH" : "BAD_LENGTH"); 
        $display("| da_kind     : %s ", this.da_kind.value ? "GOOD_DA" : "BAD_DA");
        $display("+---------------------- PACKET HEADER ------------------------+ ");
        $display("| Destination : %h ", this.da.value); 
        $display("| Source      : %02x ", this.sa.value);
        $display("| Length      : %02x ", this.length.value);
        $display("+---------------------- PACKET DATA --------------------------+ ");
        $display("        +0  +1  +2  +3  +4  +5  +6  +7  +8  +9  +A  +B  +C  +D  +E  +F");
        foreach (data[i]) begin    
            if (line_wrap_cnt == 0) begin
                $write("[0x%02x0]", i / 16);
                $write(" %02x ", this.data[i].value[07:00]);
                line_wrap_cnt++;
            end
            else if (line_wrap_cnt == 15) begin     
                line_wrap_cnt = 0;
                $write(" %02x ", this.data[i].value[07:00]);
                $display("");    
            end
            else begin
                $write(" %02x ", this.data[i].value[07:00]); 
                line_wrap_cnt++;
            end
        end 
        $display("");    
        $display(" Frame Check : %02x ", this.cal_fcs( ));
        $display("--------------------------------------------------------------+");
    end
    endfunction : display

    /* method to pack the packet into bytes */
    function int unsigned byte_pack(ref logic unsigned [7:0] bytes[]);
        begin
            bytes = new[this.data.size + 4];
            bytes[0] = this.da.value;
            bytes[1] = this.sa.value;
            bytes[2] = this.length.value;
            foreach (this.data[i])
                bytes[3 + i] = this.data[i].value;
        end
        bytes[this.data.size + 3] = this.cal_fcs( );
        $display("FCS packed value: 0x%02x", bytes[this.data.size + 3]);
        
        // this.fcs.value = bytes[this.data.size + 3];
        byte_pack = bytes.size + 4;
        return byte_pack;
    endfunction : byte_pack
    
    /* method to unpack the bytes in to packet */
    function void byte_unpack(ref logic [7:0] bytes[]);
        begin
            this.da.value = bytes[0];
            this.sa.value = bytes[1];
            this.length.value = bytes[2];
            this.data = new[bytes.size - 4];
            foreach (this.data[i]) begin
                this.data[i] = new ( );
                this.data[i].value = bytes[i + 3];
            end
            // We don't know that there is an error in this packet,
            // so we set the Frame Check Sequence Flag to good. Then
            // we do a comparison on the FCS field we received against 
            // the calculated one we do in  the comparison below.
            this.fcs.value = bytes[bytes.size - 1];
            if (this.fcs.value != this.cal_fcs()) 
                $display("Error: Packed FCS 0x%02x doesn't match unpacked FCS 0x%02x", this.fcs.value, this.cal_fcs());
            this.fcs.value = `BAD_FCS; // Should this be within the if statement above?
        end
    endfunction : byte_unpack

    /* method to compare the packets */                            
    function bit compare(Packet pkt);
        begin
            compare = 1;
            if (pkt == null) begin
                $display(" ** ERROR ** : pkt : received a null object ");
                compare = 0;
            end
            else begin
                if (pkt.da.value !== this.da.value) begin
                    $display (" ** ERROR DA**: pkt : Pkt : 0x%02h, this : 0x%02h", pkt.da.value, this.da.value);
                    compare = 0;
                end
                if (pkt.sa.value !== this.sa.value) begin
                    $display (" ** ERROR SA **: pkt : Pkt : 0x%02h, this : 0x%02h", pkt.sa.value, this.sa.value);
                    compare = 0;
                end
                if (pkt.length.value !== this.length.value) begin
                    $display (" ** ERROR Length**: pkt : Pkt : 0x%02x, this : 0x%02x", pkt.length.value, this.length.value);
                    compare = 0;
                end
                if (pkt.data.size !== this.data.size) begin
                    $display (" ** ERROR **: pkt : data.size : %02d, this : data.size   : %02d, these do not match", pkt.data.size, this.data.size);
                    compare = 0;
                end
                foreach (this.data[i])
                    if (pkt.data[i].value !== this.data[i].value) begin
                        $display (" ** ERROR **: Packet:[0x%02x] 0x%02x != 0x%02x", i, pkt.data[i].value, this.data[i].value);
                        compare = 0;
                    end
                if (pkt.fcs.value !== this.fcs.value) begin
                    $display(" ** ERROR **: pkt : fcs field did not match 0x%02h 0x%02h", pkt.fcs.value, this.fcs.value);
                    compare = 0;
                end
            end
        end
    endfunction : compare

endclass : Packet

class Receiver;
    mailbox #(Packet) rcvr2sb;
    reg [01:00] port_id;
    int packets_rcvd;
    
    // constructor method
    function new(mailbox #(Packet) _rcvr2sb, bit [01:00] _port_id);
        if (_rcvr2sb == null) begin
            $display("%09d[RECEIVER   ]: **ERROR**: rcvr2sb is null", $time);
            $finish;
        end
        else begin
        this.packets_rcvd = 0;
            this.rcvr2sb = _rcvr2sb;
            port_id = _port_id;
        end
    endfunction : new  

    task start(byte unsigned port_addrs[]);
        logic [7:0] bytes[];
        Packet pkt;
        randi do_stall;
        randi stall_length;
        
        // Random stalls on output (2.2.1)
        do_stall = new();
        do_stall.cons.set_min_constraint(`FALSE);
        do_stall.cons.set_max_constraint(`TRUE);
        do_stall.cons.constraint_mode_i(`ENABLE);
        
        stall_length = new();
        stall_length.cons.set_min_constraint(`FALSE);
        stall_length.cons.set_max_constraint(`TRUE);
        stall_length.cons.constraint_mode_i(`ENABLE);
        
        forever begin
            bytes = new();
            case(port_id)
                0: begin
                    while (~$root.output_intf[0].ready) @(posedge $root.output_intf[0].clock);
                    $root.output_intf[0].read = 1; 
                    @(posedge $root.output_intf[0].clock);
                    @(posedge $root.output_intf[0].clock);                      
                            while ($root.output_intf[0].ready) begin
                    bytes = new[bytes.size + 1](bytes);
                    bytes[bytes.size - 1] = $root.output_intf[0].data_out;
                    @(posedge $root.output_intf[0].clock);
                    end 
                    $root.output_intf[0].read = 0;
                end
                1: begin
                    while (~$root.output_intf[1].ready) @(posedge $root.output_intf[1].clock);
                    $root.output_intf[1].read = 1; 
                    @(posedge $root.output_intf[1].clock);
                    @(posedge $root.output_intf[1].clock);                      
                    while ($root.output_intf[1].ready) begin
                        bytes = new[bytes.size + 1](bytes);
                        bytes[bytes.size - 1] = $root.output_intf[1].data_out;
                        @(posedge $root.output_intf[1].clock);
                    end 
                    $root.output_intf[1].read = 0;
                end
                2: begin
                    while (~$root.output_intf[2].ready) @(posedge $root.output_intf[2].clock);
                    $root.output_intf[2].read = 1; 
                    @(posedge $root.output_intf[2].clock);
                    @(posedge $root.output_intf[2].clock);                      
                    while ($root.output_intf[2].ready) begin
                        bytes = new[bytes.size + 1](bytes);
                        bytes[bytes.size - 1] = $root.output_intf[2].data_out;
                        @(posedge $root.output_intf[2].clock);
                    end 
                    $root.output_intf[2].read = 0;
                end
                3: begin
                    while (~$root.output_intf[3].ready) @(posedge $root.output_intf[3].clock);
                    $root.output_intf[3].read = 1; 
                    @(posedge $root.output_intf[3].clock);
                    @(posedge $root.output_intf[3].clock);                      
                    while ($root.output_intf[3].ready) begin
                        bytes = new[bytes.size + 1](bytes);
                        bytes[bytes.size - 1] = $root.output_intf[3].data_out;
                        @(posedge $root.output_intf[3].clock);
                    end 
                    $root.output_intf[3].read = 0;
                end
            endcase
            // Create a new packet for which to pass to the mailbox
            pkt = new(port_addrs);              
            $display("%09d[RECEIVER   ]: Received a packet of length %0d", $time, bytes.size);
            pkt.byte_unpack(bytes);
    
            pkt.display();                          
            rcvr2sb.put(pkt);                   
            $display("%09d[RECEIVER   ]: Put the received packet in the mailbox", $time);
            bytes.delete();        
            packets_rcvd++;    
        end
    endtask : start
endclass : Receiver

class Scoreboard;
    Packet        PacketInQueue[$];
    mailbox #(Packet) drvr2sb;
    mailbox #(Packet) rcvr2sb;
    int           packets_comp;
    
    function new (ref mailbox #(Packet) _drvr2sb, ref mailbox #(Packet) _rcvr2sb, ref Packet _drvr2queue[$]); // constructor method
        this.drvr2sb = _drvr2sb;
        this.rcvr2sb = _rcvr2sb;
        this.PacketInQueue = _drvr2queue;
    endfunction : new

    task start();
        Packet pkt_rcv, pkt_exp;
        forever begin            
            drvr2sb.get(pkt_exp);
            $display("%09d[SCOREBOARD ]: Scoreboard received a packet from driver ", $time);
            $display("%09d[SCOREBOARD ]: The packet sent from driver is as follows ", $time);
            pkt_exp.display();
                
            rcvr2sb.get(pkt_rcv);
            $display("%09d[SCOREBOARD ]: Scoreboard received a packet from receiver ", $time);
            $display("%09d[SCOREBOARD ]: The captured packet from receiver is as follows ", $time);
            pkt_rcv.display ();                                             
                
            if (pkt_rcv.compare(pkt_exp) == 1) begin
                $display("%09d[SCOREBOARD ]: Packet matched ",$time);
            end
            else begin
                $display("%09d[SCOREBOARD ]: Packet did NOT match ",$time);
                $root.error++;
            end 
            packets_comp++;
        end
    endtask : start
endclass // scoreboard

class Driver;
    Packet        PacketInQueue[$];
    mailbox #(Packet) drvr2sb;
    //Packet        gpkt;
    int           packets_sent;
    
    function new(ref mailbox #(Packet) _drvr2sb, ref Packet _drvr2queue[$]); // constructor method
        if (_drvr2sb == null) begin
            $display("%09d[DRIVER    ]: **ERROR**: drvr2sb is null", $time);
            $finish;
        end
        else begin
            this.drvr2sb = _drvr2sb; // Point our mailbox handle to the global mailbox handle
            this.PacketInQueue = _drvr2queue;
            //this.gpkt = new(); // Initialize the local Packet Object
            this.packets_sent = 0;
        end
    endfunction : new  

    // method to send the packet to DUT ////////
    task start(byte unsigned port_addrs[]);
    Packet      pkt/*,pkt2*/;
    int         length;
    logic [7:0] bytes[];                   
    begin
        $display("%09d[DRIVER     ]: Number of packets : %0d", $time, $root.num_of_pkts);
        repeat ($root.num_of_pkts) begin
            repeat (3) @(posedge $root.input_intf.clock);
            $display("%09d[DRIVER     ]: Packet number : %0d", $time, this.packets_sent);
            pkt = new(port_addrs);
        
            // Randomize the packet //
            if (pkt.randomize_o())  begin
                $display("%09d[DRIVER     ]: Randomization successful. ", $time);
                // Pack the packet in tp stream of bytes
                length = pkt.byte_pack(bytes);
                    
                // assert the data_status signal and send the packed bytes
                foreach (bytes[i]) begin
                    @(posedge $root.input_intf.clock);
                    $root.input_intf.cb.data_valid <= 1;
                    $root.input_intf.cb.data <= bytes[i];  
                end
        
                // Stop sending data
                @(posedge $root.input_intf.clock);
                $root.input_intf.cb.data_valid <= 0; // deassert the data_status singal
                $root.input_intf.cb.data <= 0;  
                
                $display("%09d[DRIVER     ]: Put the sent packet in the mailbox", $time);
                drvr2sb.put(pkt); // Push the packet in to mailbox for scoreboard
                $display("%09d[DRIVER     ]: Finished driving the packet with length %0d", $time, length); 
                pkt.display();
                $display("%09d[DRIVER     ]: The above is the packet that was put into the mailbox", $time);
                this.packets_sent++;
                
                // We need to keep each packet at least two clock cycles apart.
                repeat(3) @(posedge $root.input_intf.clock);
            end
            else begin
                $display("%09d[DRIVER   ]:  ** Randomization failed. **",$time);
                // Increment the error count in randomization fails ////////
                $root.error++;
                $finish;
            end
        end // end repeat
    end // end function start
    endtask : start
endclass : Driver

class Environment;
    Driver drvr;
    Receiver rcvr[4];
    Scoreboard sb;
    Packet PacketInQueue[$];
    byte unsigned port_addrs[];
    
    mailbox #(Packet) drvr2sb;
    mailbox #(Packet) rcvr2sb;
    
    function new();
        begin
            $display("%09d[ENVIRONMENT]: created env object", $time);
        end
    endfunction : new

    function void build();
        $display("%09d[ENVIRONMENT]: start of build() method", $time);
    
        PacketInQueue = new();
        rcvr2sb = new();
        drvr2sb = new();
        sb = new(drvr2sb, rcvr2sb, PacketInQueue);
                    
        drvr = new(drvr2sb, PacketInQueue);

        foreach (rcvr[i]) 
            rcvr[i]= new(rcvr2sb, i[01:00]);
        
        $display("%09d[ENVIRONMENT]: end of build() method", $time);
    endfunction : build

    task reset();
        $display("%09d[ENVIRONMENT]: start of reset() method", $time);
        // Drive all DUT inputs to a known state
        $root.mem_intf.cb.mem_wdata <= 0;
        $root.mem_intf.cb.mem_addr <= 0;
        $root.mem_intf.cb.mem_en <= 0;
        $root.mem_intf.cb.mem_rd_wr <= 0;
        $root.input_intf.cb.data <= 0;
        $root.input_intf.cb.data_valid <= 0;
        $root.output_intf[0].cb.read <= 0;
        $root.output_intf[1].cb.read <= 0;
        $root.output_intf[2].cb.read <= 0;
        $root.output_intf[3].cb.read <= 0;
    
        // Reset the DUT
        $root.input_intf.reset_b <= 0;
        repeat (4) @ $root.input_intf.clock;
        $root.input_intf.reset_b <= 1;
    
    $display("%09d[ENVIRONMENT]: end of reset() method", $time);
    endtask : reset

    task cfg_dut();
        $display("%09d[ENVIRONMENT]: start of cfg_dut() method", $time);
        
        // Randomization of port addresses (2.2.2)
        this.port_addrs = new[4];
        this.port_addrs[0] = 8'h01;
        this.port_addrs[1] = 8'h12;
        this.port_addrs[2] = 8'h23;
        this.port_addrs[3] = 8'h34;
        
        $root.mem_intf.cb.mem_en <= 1;
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_rd_wr <= 1;
    
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_addr  <= 8'h0;
        $root.mem_intf.cb.mem_wdata <= this.port_addrs[0];
        $display("%09d[ENVIRONMENT]: Port 0 Address %h ", $time, this.port_addrs[0]);
    
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_addr  <= 8'h1;
        $root.mem_intf.cb.mem_wdata <= this.port_addrs[1];
        $display("%09d[ENVIRONMENT]: Port 1 Address %h ", $time, this.port_addrs[1]);
    
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_addr  <= 8'h2;
        $root.mem_intf.cb.mem_wdata <= this.port_addrs[2];
        $display("%09d[ENVIRONMENT]: Port 2 Address %h ", $time, this.port_addrs[2]);
    
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_addr  <= 8'h3;
        $root.mem_intf.cb.mem_wdata <= this.port_addrs[3];
        $display("%09d[ENVIRONMENT]: Port 3 Address %h ",$time, this.port_addrs[3]);
    
        @(posedge $root.mem_intf.clock);
        $root.mem_intf.cb.mem_en <=0;
        $root.mem_intf.cb.mem_rd_wr <= 0;
        $root.mem_intf.cb.mem_addr <= 0;
        $root.mem_intf.cb.mem_wdata <= 0;
    
        $display("%09d[ENVIRONMENT]: end of cfg_dut() method", $time);
    endtask : cfg_dut

    task start();
        $display("%09d[ENVIRONMENT]:  start of start() method", $time);
        fork
            sb.start();
            drvr.start(this.port_addrs);
            rcvr[0].start(this.port_addrs);
            rcvr[1].start(this.port_addrs);
            rcvr[2].start(this.port_addrs);
            rcvr[3].start(this.port_addrs);
        join_any
        $display("%09d[ENVIRONMENT]:  End of Receiver  method", $time);
    endtask : start

    task wait_for_end();
        $display("%09d[ENVIRONMENT]: start of wait_for_end() method", $time);
        repeat (10000) @($root.input_intf.clock);
        $display("%09d[ENVIRONMENT]: end of wait_for_end() method", $time);
    endtask : wait_for_end

    task run();
    int packet_in_cnt = 0;
    int packet_out_cnt = 0; 
    int packet_cmp_cnt = 0;
    begin
        $display("%09d[ENVIRONMENT]: start of run() method", $time);
        build();
        reset();
        cfg_dut();
        start();
        wait_for_end();
        // We need to check whether or not any packets have been captured
        packet_in_cnt = drvr.packets_sent;
        packet_out_cnt = rcvr[0].packets_rcvd + rcvr[1].packets_rcvd + rcvr[2].packets_rcvd + rcvr[3].packets_rcvd;
        packet_cmp_cnt =  sb.packets_comp;
        $display("%09d[ENVIRONMENT]: The Driver sent %03d packets and the Receiver(s) captured %03d packets and the Scoreboard compared %03d packets", $time, packet_in_cnt, packet_out_cnt, packet_cmp_cnt);
        if (packet_in_cnt != packet_out_cnt) begin
            $root.error = 1;
            $display("%09d[ENVIRONMENT]: ERROR: The number of packets driven into the scoreboard did not match the number of packets received by the scoreboard", $time());
        end
        if (packet_in_cnt != packet_cmp_cnt) begin
            $root.error = 1;
            $display("%09d[ENVIRONMENT]: ERROR: The number of packets driven into the scoreboard did not match the number of packets compared by the scoreboard", $time());
        end
        report();
        $display("%09d[ENVIRONMENT]: end of run() method", $time);
    end
    endtask : run

    task report();
        $display("\n*************************************************");
        if( 0 == $root.error) $display("********        TEST PASSED     *********");
        else              $display("********    TEST Failed with %03d errors *********", $root.error);
        $display("*************************************************\n");
    endtask : report 

endclass : Environment
