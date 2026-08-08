`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 03:04:55 PM
// Design Name: 
// Module Name: asyncfifo
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


module asyncfifo #(parameter DATA_SIZE = 8,
parameter ADDR_SIZE = 4)
(input w_clk, r_clk, w_rstn, r_rstn,w_incr, r_incr,
  input [DATA_SIZE-1:0] w_data, 
  output [DATA_SIZE-1:0] r_data,
  output w_full, r_empty
);
wire [ADDR_SIZE-1:0] w_addr, r_addr;
wire [ADDR_SIZE:0] w_ptr, r_ptr, wq2_r_ptr, rq2_w_ptr;

asyncfifo_mem #(DATA_SIZE, ADDR_SIZE)
asyncfifo_mem(.r_data(r_data), .w_data(w_data), .w_addr(w_addr), 
.r_addr(r_addr), .w_en(w_incr), .w_clk(w_clk), .w_full(w_full));

sync_r2w #(ADDR_SIZE) sync_r2w(.w_clk(w_clk), .w_rstn(w_rstn),
.r_ptr(r_ptr), .wq2_r_ptr(wq2_r_ptr));

sync_w2r #(ADDR_SIZE) sync_w2r(.r_clk(r_clk), .r_rstn(r_rstn),
 .w_ptr(w_ptr), .rq2_w_ptr(rq2_w_ptr));

empty_flag #(ADDR_SIZE) empty_flag(.rq2_w_ptr(rq2_w_ptr), .r_clk(r_clk), 
.r_rstn(r_rstn),.r_incr(r_incr), .r_addr(r_addr), .r_ptr(r_ptr), .r_empty(r_empty));

full_flag #(ADDR_SIZE) full_flag( .wq2_r_ptr(wq2_r_ptr), .w_clk(w_clk), .w_rstn(w_rstn),
.w_incr(w_incr), .w_full(w_full), .w_addr(w_addr), .w_ptr(w_ptr));

endmodule
