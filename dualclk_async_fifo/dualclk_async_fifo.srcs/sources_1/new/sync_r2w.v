`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2026 08:35:06 PM
// Design Name: 
// Module Name: sync_r2w
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


module sync_r2w #(parameter ADDR_SIZE=4)(
input [ADDR_SIZE:0] r_ptr,
output reg [ADDR_SIZE:0] wq2_r_ptr,
input w_clk, w_rstn);
reg [ADDR_SIZE:0] wq1_r_ptr;
always@(posedge w_clk or negedge w_rstn)
    if(!w_rstn){wq2_r_ptr, wq1_r_ptr} <=0;
    else {wq2_r_ptr, wq1_r_ptr} <= {wq1_r_ptr, r_ptr};
endmodule
