`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2026 07:56:52 PM
// Design Name: 
// Module Name: sync_w2r
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


module sync_w2r #(parameter ADDR_SIZE =4)
(input [ADDR_SIZE:0] w_ptr,
input r_clk, r_rstn,
output reg [ADDR_SIZE:0] rq2_w_ptr
    ); 
reg [ADDR_SIZE:0] rq1_w_ptr;
always@(posedge r_clk or negedge r_rstn)
    if(!r_rstn) {rq2_w_ptr, rq1_w_ptr}<= 0;
    else {rq2_w_ptr, rq1_w_ptr} <= {rq1_w_ptr, w_ptr};
endmodule
