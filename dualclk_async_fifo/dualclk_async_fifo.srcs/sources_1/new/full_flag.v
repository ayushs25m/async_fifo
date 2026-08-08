`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 12:44:49 PM
// Design Name: 
// Module Name: full_flag
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
module full_flag #(parameter ADDR_SIZE = 4)(
input [ADDR_SIZE:0] wq2_r_ptr,
input w_clk, w_rstn, w_incr,
output reg w_full,
output reg [ADDR_SIZE:0] w_ptr,
output [ADDR_SIZE-1:0] w_addr
 );
reg [ADDR_SIZE:0] w_binary;
wire [ADDR_SIZE:0] w_binarynext, w_graynext;
wire w_full_val;
always@(posedge w_clk or negedge w_rstn)
    if(!w_rstn) {w_binary, w_ptr} <= 0;
    else {w_binary, w_ptr} <= {w_binarynext, w_graynext};
assign w_addr = w_binary[ADDR_SIZE-1:0];
assign w_binarynext = w_binary + (w_incr & ~w_full);
assign w_graynext = (w_binarynext>>1) ^ w_binarynext;
assign w_full_val = {w_graynext == {~wq2_r_ptr[ADDR_SIZE:ADDR_SIZE-1],wq2_r_ptr[ADDR_SIZE-2:0]}};
always@(posedge w_clk or negedge w_rstn)
    if(!w_rstn) w_full <= 1'b0;
    else w_full<= w_full_val;
endmodule
