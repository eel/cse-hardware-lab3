program Testcase ( );

    Environment env;

    Packet pkt1;
    Packet pkt2;

    logic [7:0] bytes[ ];    
    
    initial
        begin
            $display(" ******************* Start of testcase ****************");
        
            env = new( );
        
            env.run();
        
            #1000; 
        
            $finish;
        end
           
    final 
        begin
            $display(" ******************** End of testcase *****************");
        end
              
endprogram
