`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2026 05:16:44 PM
// Design Name: 
// Module Name: asyncfifo_mem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module asyncfifo_mem #(parameter DATA_SIZE = 8,
parameter ADDR_SIZE = 4)(
output [DATA_SIZE -1:0] r_data,
input [DATA_SIZE-1:0] w_data,
input [ADDR_SIZE-1:0] w_addr,
input [ADDR_SIZE-1:0] r_addr,
input w_en, w_clk, w_full);

localparam FIFO_DEPTH = 1<<ADDR_SIZE;
reg [DATA_SIZE-1:0] fifo_mem[0:FIFO_DEPTH-1];
always@(posedge w_clk)
    if(w_en && !w_full)
        fifo_mem[w_addr] <= w_data;
assign r_data = fifo_mem[r_addr];
endmodule
