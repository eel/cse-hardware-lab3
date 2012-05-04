`timescale 1ns / 1ns

///////////////////////////////////////////////////////////////////////////////
// Interface declaration for the memory                                      //
///////////////////////////////////////////////////////////////////////////////
interface mem_interface (input bit clock); 
    logic [07:00] mem_rdata; 
    logic [07:00] mem_wdata; 
    logic [01:00] mem_addr; 
    logic         mem_en; 
    logic         mem_rd_wr; 
   
    clocking cb@(posedge clock); 
        default input #1 output #1; 
        output mem_wdata; 
        input  mem_rdata; 
        output mem_addr; 
        output mem_en; 
        output mem_rd_wr; 
    endclocking
   
    modport MEM (clocking cb, input clock); 
    
endinterface

///////////////////////////////////////////////////////////////////////////////
// Interface for the input side of switch. Reset signal is also passed hear. //
///////////////////////////////////////////////////////////////////////////////
interface input_interface (input bit clock); 
    logic         data_stall; 
    logic         data_valid; 
    logic [07:00] data; 
    logic         reset_b; 
 
    clocking cb@(posedge clock); 
    default input #1 output #1; 
        input        data_stall;
        output       data_valid; 
        output       data; 
    endclocking 
    
    modport IP(clocking cb, output reset_b, input clock);  
endinterface

///////////////////////////////////////////////////////////////////////////////
// Interface for the output side of the switch output_interface is for only  //
// one output port                                                           //
///////////////////////////////////////////////////////////////////////////////

interface output_interface (input bit clock); 
    logic [7:0] data_out; 
    logic       ready; 
    logic       read; 
    
    clocking cb@(posedge clock); 
        default input #1 output #1; 
        input     data_out; 
        input     ready; 
        output    read; 
    endclocking 
    
    modport OP(clocking cb, input clock); 
  
endinterface
