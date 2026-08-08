//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 07/27/2026 12:34:50 AM
//// Design Name: 
//// Module Name: tb_asyncfifo
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns / 1ps

//module tb_asyncfifo;

//  // Parameters
//  parameter DATA_SIZE = 8;
//  parameter ADDR_SIZE = 4; // Depth = 16

//  // Clock Periods: Fast Write (10ns = 100MHz), Slow Read (100ns = 10MHz)
//  localparam WCLK_PERIOD = 10;
//  localparam RCLK_PERIOD = 100;

//  // DUT Signals
//  reg  w_clk = 0;
//  reg  r_clk = 0;
//  reg  w_rstn = 0;
//  reg  r_rstn = 0;
//  reg  w_incr = 0;
//  reg  r_incr = 0;
//  reg  [DATA_SIZE-1:0] w_data = 0;
//  wire [DATA_SIZE-1:0] r_data;
//  wire w_full;
//  wire r_empty;

//  // Data Generator Counter
//  integer data_counter = 1;

//  // Device Under Test (DUT)
//  asyncfifo #(
//      .DATA_SIZE(DATA_SIZE),
//      .ADDR_SIZE(ADDR_SIZE)
//  ) dut (
//      .w_clk  (w_clk),
//      .r_clk  (r_clk),
//      .w_rstn (w_rstn),
//      .r_rstn (r_rstn),
//      .w_incr (w_incr),
//      .r_incr (r_incr),
//      .w_data (w_data),
//      .r_data (r_data),
//      .w_full (w_full),
//      .r_empty(r_empty)
//  );

//  // Clock Generators
//  always #(WCLK_PERIOD / 2) w_clk = ~w_clk;
//  always #(RCLK_PERIOD / 2) r_clk = ~r_clk;

//  // -------------------------------------------------------------
//  // Stimulus Sequence
//  // -------------------------------------------------------------
//  integer i;

//  initial begin
//    // Optional dump file generation for Icarus Verilog / GTKWave
//    $dumpfile("tb_asyncfifo.vcd");
//    $dumpvars(0, tb_asyncfifo);

//    // 1. Reset Phase
//    w_rstn = 0;
//    r_rstn = 0;
//    w_incr = 0;
//    r_incr = 0;
//    w_data = 0;
//    #(WCLK_PERIOD * 5);
    
//    w_rstn = 1;
//    r_rstn = 1;
//   #(WCLK_PERIOD * 2);

//    // 2. PHASE 1: Fast Burst Write (20 items driven to overflow a 16-deep FIFO)
////    for (i = 0; i < 20; i = i + 1) begin
////      @(posedge w_clk);
////      #1;
////      w_incr = 1'b1;
////      w_data = data_counter[DATA_SIZE-1:0]; // Clean incremental pattern: 1, 2, 3...
////      data_counter = data_counter + 1;
////    end
//    // Recommended Synchronous Testbench Loop (No #1 Delay Required)
//for (i = 0; i < 20; i = i + 1) begin
//    @(posedge w_clk);
//    w_incr <= 1'b1;
//    w_data <= data_counter[DATA_SIZE-1:0];
//    data_counter <= data_counter + 1;
//end
//    // Stop writing
//    @(posedge w_clk);
//    w_incr <= 1'b0;
//    w_data <= 0;

//    // 3. PHASE 2: Idle Buffer Time (Observe synchronized flags in waveform)
//    #(WCLK_PERIOD * 20);

//    // 4. PHASE 3: Slow Read Drain (Drain all items from FIFO)
//    for (i = 0; i < 16; i = i + 1) begin
//      @(posedge r_clk);
//      if (!r_empty) begin
//        r_incr <= 1'b1;
//        @(posedge r_clk);
//        r_incr <= 1'b0;
//      end
//    end

//    // Hold final state for visual inspection
//    #(RCLK_PERIOD * 10);
//    $finish;
//  end

//endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// tb_case7_maxrate_writes
// Minimal, standalone test for ONE thing only:
//   Case 7 - back-to-back max-rate writes, w_incr held high every single
//            cycle with no idle gaps, well past the FIFO's actual depth.
// Confirms:
//   - no off-by-one in the address/pointer increment logic
//   - exactly DEPTH writes are accepted, no more, no fewer
//   - excess writes past full are cleanly ignored, never wrap into
//     occupied memory
//   - data that DID get written comes back out in the correct order,
//     with correct values, once drained
//////////////////////////////////////////////////////////////////////////////////
module tb_asyncfifio;

  parameter DATA_SIZE = 8;
  parameter ADDR_SIZE = 4;
  localparam DEPTH = (1 << ADDR_SIZE);
  localparam WCLK_PERIOD = 10;
  localparam RCLK_PERIOD = 25;
  localparam EXTRA_ATTEMPTS = 20; // writes attempted well past DEPTH

  reg  w_clk = 0;
  reg  r_clk = 0;
  reg  w_rstn = 0;
  reg  r_rstn = 0;
  reg  w_incr = 0;
  reg  r_incr = 0;
  reg  [DATA_SIZE-1:0] w_data = 0;
  wire [DATA_SIZE-1:0] r_data;
  wire w_full;
  wire r_empty;

  integer i;
  integer data_counter = 1;
  integer errors = 0;

  reg [DATA_SIZE-1:0] expect_q[0:255];
  integer q_head, q_tail;

  asyncfifo #(.DATA_SIZE(DATA_SIZE), .ADDR_SIZE(ADDR_SIZE)) dut (
      .w_clk  (w_clk),
      .r_clk  (r_clk),
      .w_rstn (w_rstn),
      .r_rstn (r_rstn),
      .w_incr (w_incr),
      .r_incr (r_incr),
      .w_data (w_data),
      .r_data (r_data),
      .w_full (w_full),
      .r_empty(r_empty)
  );

  always #(WCLK_PERIOD/2) w_clk = ~w_clk;
  always #(RCLK_PERIOD/2) r_clk = ~r_clk;

  // Write-side scoreboard monitor: mirrors the DUT's exact write-gating
  // condition at the SAME edge the DUT itself samples it, so this can
  // never drift out of sync with what actually landed in memory.
  always @(posedge w_clk) begin
    if (w_rstn && w_incr && !w_full) begin
      expect_q[q_tail] = w_data;
      q_tail = q_tail + 1;
    end
  end

  initial begin
    $dumpfile("tb_asyncfifo.vcd");
    $dumpvars(0, tb_asyncfifo);

    // ---- Reset ----
    w_rstn = 0; r_rstn = 0;
    w_incr = 0; r_incr = 0;
    #(WCLK_PERIOD*5);
    w_rstn = 1; r_rstn = 1;
    #(WCLK_PERIOD*2);
    q_head = 0; q_tail = 0;

    // ---- Hold w_incr high continuously, no idle cycles, well past DEPTH ----
    $display("[%0t] Holding w_incr high for %0d back-to-back cycles (DEPTH=%0d)...",
              $time, DEPTH + EXTRA_ATTEMPTS, DEPTH);
    w_incr <= 1'b1;
    for (i = 0; i < DEPTH + EXTRA_ATTEMPTS; i = i + 1) begin
      @(posedge w_clk);
      w_data <= data_counter[DATA_SIZE-1:0];
      data_counter = data_counter + 1;
    end
    @(posedge w_clk);
    w_incr <= 1'b0;

    #(WCLK_PERIOD*4);

    // ---- Check: FIFO must be full, and exactly DEPTH writes accepted ----
    if (!w_full) begin
      $display("[%0t] ERROR: FIFO should be full after %0d back-to-back writes",
                $time, DEPTH + EXTRA_ATTEMPTS);
      errors = errors + 1;
    end else begin
      $display("[%0t] OK: w_full=1 after saturating back-to-back writes", $time);
    end

    if (q_tail - q_head != DEPTH) begin
      $display("[%0t] ERROR: expected exactly %0d writes accepted, scoreboard shows %0d",
                $time, DEPTH, q_tail - q_head);
      errors = errors + 1;
    end else begin
      $display("[%0t] OK: exactly %0d writes accepted, %0d excess attempts correctly ignored",
                $time, DEPTH, EXTRA_ATTEMPTS);
    end

    // ---- Drain everything and verify correct order/values, back-to-back ----
    $display("[%0t] Draining %0d words back-to-back (fast reader)...", $time, DEPTH);
    for (i = 0; i < DEPTH; i = i + 1) begin
      while (r_empty) @(posedge r_clk);
      #1; // check BEFORE popping - r_data valid for the current front item
      if (r_data !== expect_q[q_head]) begin
        $display("[%0t] ERROR: drain item %0d mismatch: expected 0x%0h got 0x%0h",
                  $time, i, expect_q[q_head], r_data);
        errors = errors + 1;
      end
      q_head = q_head + 1;
      r_incr <= 1'b1;
      @(posedge r_clk);
      r_incr <= 1'b0;
    end

    #(RCLK_PERIOD*3);
    if (!r_empty) begin
      $display("[%0t] ERROR: FIFO not empty after draining all %0d items", $time, DEPTH);
      errors = errors + 1;
    end else begin
      $display("[%0t] OK: fully drained, all %0d values correct and in order", $time, DEPTH);
    end

    if (errors == 0) begin
      $display("\n===== CASE 7 PASSED (0 errors) =====");
    end else begin
      $display("\n===== CASE 7 FAILED: %0d error(s) =====", errors);
    end
    $finish;
  end

  // watchdog
  initial begin
    #100000;
    $display("[%0t] WATCHDOG TIMEOUT", $time);
    $finish;
  end

endmodule