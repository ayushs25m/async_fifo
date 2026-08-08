`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2026 08:44:10 PM
// Design Name: 
// Module Name: empty_flag
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
module empty_flag #(parameter ADDR_SIZE= 4)
(
input [ADDR_SIZE:0] rq2_w_ptr,
input r_clk, r_rstn,r_incr,
output reg[ADDR_SIZE:0] r_ptr,
output [ADDR_SIZE-1:0] r_addr,
output reg r_empty);

reg [ADDR_SIZE:0] r_binary;
wire [ADDR_SIZE:0] r_graynext, r_binarynext;
wire r_empty_val;
always @(posedge r_clk or negedge r_rstn)
    if(!r_rstn) {r_binary, r_ptr} <= 0;
    else {r_binary, r_ptr} <= {r_binarynext, r_graynext};
assign r_addr = r_binary[ADDR_SIZE-1:0];
assign r_binarynext = r_binary + (r_incr & ~r_empty);
assign r_graynext = r_binarynext^(r_binarynext>>1);
assign r_empty_val = (rq2_w_ptr == r_graynext);
always@(posedge r_clk or negedge r_rstn)
    if(!r_rstn) r_empty <= 1'b1;
    else  r_empty <= r_empty_val;
endmodule
