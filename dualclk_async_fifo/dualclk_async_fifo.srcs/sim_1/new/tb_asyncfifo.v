`timescale 1ns / 1ps
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

//   all 8 corner cases
//   1. Simultaneous read+write at FULL
//   2. Simultaneous read+write at EMPTY
//   3. Full -> empty -> full, repeated (pointer wraparound x4)
//   4. Reset asserted mid-transfer (both domains)
//   5. Asymmetric reset (write side only)
//   6. Extreme clock ratio, both directions (6a fast-write/slow-read,
//      6b slow-write/fast-read) - run LAST since it reconfigures clocks
//   7. Back-to-back max-rate writes (no idle cycles)
//   8. Single-entry FIFO edge case
//
module tb_asyncfifo;

  parameter DATA_SIZE = 8;
  parameter ADDR_SIZE = 4;
  localparam DEPTH = (1 << ADDR_SIZE);


  real WCLK_PERIOD = 10;
  real RCLK_PERIOD = 25;

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
  integer accepted_count = 0;

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

  always @(posedge w_clk) begin
    if (w_rstn && w_incr && !w_full) begin
      accepted_count = accepted_count + 1;
    end
  end


  task reset_both;
    begin
      w_rstn = 0; r_rstn = 0;
      w_incr = 0; r_incr = 0;
      #(WCLK_PERIOD*5);
      w_rstn = 1; r_rstn = 1;
      #(WCLK_PERIOD*2);
      q_head = 0; q_tail = 0;
      accepted_count = 0;
    end
  endtask

  task single_write(input [DATA_SIZE-1:0] data);
    begin
      @(posedge w_clk);
      w_incr <= 1'b1;
      w_data <= data;
      @(posedge w_clk);
      w_incr <= 1'b0;
    end
  endtask

  task check_read(input [DATA_SIZE-1:0] expected);
    begin
      while (r_empty) @(posedge r_clk);
      #1;
      if (r_data !== expected) begin
        $display("[%0t] ERROR: read mismatch: expected 0x%0h got 0x%0h",
                  $time, expected, r_data);
        errors = errors + 1;
      end else begin
        $display("[%0t] OK: read correct value 0x%0h", $time, r_data);
      end
      r_incr <= 1'b1;
      @(posedge r_clk);
      r_incr <= 1'b0;
    end
  endtask

  task check(input cond, input [8*60-1:0] msg);
    begin
      if (!cond) begin
        $display("[%0t] ERROR: %0s", $time, msg);
        errors = errors + 1;
      end else begin
        $display("[%0t] OK: %0s", $time, msg);
      end
    end
  endtask


  initial begin
    $dumpfile("tb_asyncfifo.vcd");
    $dumpvars(0, tb_asyncfifo);

    reset_both;

    // CASE 8: single-entry edge case

    $display("\n===== CASE 8: single-entry write/read =====");
    check(r_empty, "FIFO starts empty");
    single_write(8'h7E);
    #(RCLK_PERIOD*4);
    check(!r_empty, "r_empty deasserts after single write");
    check_read(8'h7E);
    #(RCLK_PERIOD*3);
    check(r_empty, "r_empty reasserts after draining the single entry");


    // CASE 7: back-to-back max-rate writes (no idle cycles), well past DEPTH

    $display("\n===== CASE 7: back-to-back max-rate write, full FIFO =====");
    reset_both;
    w_data <= data_counter[DATA_SIZE-1:0]; // prime the FIRST value before the burst starts
    data_counter = data_counter + 1;
    w_incr <= 1'b1;
    for (i = 0; i < DEPTH + 20; i = i + 1) begin
      @(posedge w_clk);
      w_data <= data_counter[DATA_SIZE-1:0]; // prime the NEXT value for the FOLLOWING edge
      data_counter = data_counter + 1;
    end
    @(posedge w_clk);
    w_incr <= 1'b0;
    #(WCLK_PERIOD*4);
    check(w_full, "FIFO full after back-to-back writes past depth");
    check(accepted_count == DEPTH, "exactly DEPTH writes accepted, excess correctly ignored");

    begin : drain7
      reg [DATA_SIZE-1:0] prev_val, cur_val;
      for (i = 0; i < DEPTH; i = i + 1) begin
        while (r_empty) @(posedge r_clk);
        #1;
        cur_val = r_data;
        if (i > 0 && cur_val !== (prev_val + 1'b1)) begin
          $display("[%0t] ERROR: drain item %0d broke sequence: prev=0x%0h got=0x%0h",
                    $time, i, prev_val, cur_val);
          errors = errors + 1;
        end
        prev_val = cur_val;
        r_incr <= 1'b1;
        @(posedge r_clk);
        r_incr <= 1'b0;
      end
    end
    #(RCLK_PERIOD*3);
    check(r_empty, "FIFO empty after draining all DEPTH items, gap-free sequence confirmed");

    // CASE 1: simultaneous read+write at FULL
    
    $display("\n===== CASE 1: simultaneous read+write at FULL =====");
    reset_both;
    w_data <= data_counter[DATA_SIZE-1:0]; 
    data_counter = data_counter + 1;
    w_incr <= 1'b1;
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge w_clk);
      w_data <= data_counter[DATA_SIZE-1:0];
      data_counter = data_counter + 1;
    end
    @(posedge w_clk);
    w_incr <= 1'b0;
    #(WCLK_PERIOD*4);
    check(w_full, "FIFO full before concurrent R/W test");

    fork
      begin : wr_side
        integer k;
        for (k = 0; k < 5; k = k + 1) begin
          @(posedge w_clk);
          w_incr <= 1'b1;
          w_data <= data_counter[DATA_SIZE-1:0];
          data_counter = data_counter + 1;
        end
        @(posedge w_clk);
        w_incr <= 1'b0;
      end
      begin : rd_side
        @(posedge r_clk);
        if (!r_empty) begin
          r_incr <= 1'b1;
          @(posedge r_clk);
          r_incr <= 1'b0;
        end
      end
    join
    #(WCLK_PERIOD*5);
    check(!w_full, "w_full deasserted after concurrent read freed a slot");

    begin : drain1
      integer cnt;
      cnt = 0;
      while (!r_empty && cnt < DEPTH + 5) begin
        r_incr <= 1'b1;
        @(posedge r_clk);
        r_incr <= 1'b0;
        @(posedge r_clk);
        cnt = cnt + 1;
      end
      check(cnt <= DEPTH, "no overflow: never drained more than DEPTH items");
    end

    // CASE 3: full -> empty -> full, repeated x4 (wraparound)

    $display("\n===== CASE 3: repeated full-drain-fill cycles (wraparound) =====");
    reset_both;
    begin : wrap3
      integer cyc;
      for (cyc = 0; cyc < 4; cyc = cyc + 1) begin
        for (i = 0; i < DEPTH; i = i + 1) begin
          @(posedge w_clk);
          w_incr <= 1'b1;
          w_data <= data_counter[DATA_SIZE-1:0];
          expect_q[q_tail] = data_counter[DATA_SIZE-1:0]; 
          q_tail = q_tail + 1;
          data_counter = data_counter + 1;
        end
        @(posedge w_clk);
        w_incr <= 1'b0;
        #(WCLK_PERIOD*4);
        check(w_full, "full asserted after complete fill (wraparound check)");

        for (i = 0; i < DEPTH; i = i + 1) begin
          while (r_empty) @(posedge r_clk);
          #1;
          if (r_data !== expect_q[q_head]) begin
            $display("[%0t] ERROR: wrap cyc %0d item %0d mismatch: expected 0x%0h got 0x%0h",
                      $time, cyc, i, expect_q[q_head], r_data);
            errors = errors + 1;
          end
          q_head = q_head + 1;
          r_incr <= 1'b1;
          @(posedge r_clk);
          r_incr <= 1'b0;
        end
        #(RCLK_PERIOD*4);
        check(r_empty, "empty asserted after complete drain (wraparound check)");
      end
    end

    // CASE 2: simultaneous read+write at EMPTY

    $display("\n===== CASE 2: simultaneous read+write at EMPTY =====");
    reset_both;
    check(r_empty, "FIFO starts empty before Case 2");
    fork
      begin : wr_side2
        single_write(8'hA5);
      end
      begin : rd_side2
        @(posedge r_clk);
        r_incr <= 1'b1;
        @(posedge r_clk);
        r_incr <= 1'b0;
      end
    join
    #(RCLK_PERIOD*4);
    check(!r_empty, "exactly the 1 written item visible, bogus read did not eat it");
    check_read(8'hA5);
    #(RCLK_PERIOD*3);
    check(r_empty, "empty again after draining, no phantom item from bogus read");

    // CASE 4: reset asserted mid-transfer

    $display("\n===== CASE 4: reset mid-transfer =====");
    reset_both;
    for (i = 0; i < 5; i = i + 1) begin
      @(posedge w_clk);
      w_incr <= 1'b1;
      w_data <= data_counter[DATA_SIZE-1:0];
      data_counter = data_counter + 1;
    end
    w_rstn <= 0; r_rstn <= 0;
    @(posedge w_clk); w_incr <= 1'b0;
    #(WCLK_PERIOD*5);
    w_rstn <= 1; r_rstn <= 1;
    #(WCLK_PERIOD*3);
    q_head = 0; q_tail = 0;
    check(r_empty, "r_empty=1 immediately after reset recovery");
    check(!w_full, "w_full=0 immediately after reset recovery");
    single_write(8'h5A);
    #(RCLK_PERIOD*4);
    check(!r_empty, "post-reset write visible");
    check_read(8'h5A);
    #(RCLK_PERIOD*3);
    check(r_empty, "clean drain after reset-recovery write");

    // CASE 5: asymmetric reset (write side only)

    $display("\n===== CASE 5: asymmetric reset (write side only) =====");
    reset_both;
    single_write(8'h11);
    single_write(8'h22);
    single_write(8'h33);
    #(RCLK_PERIOD*3);
    check(!r_empty, "read side sees data before asymmetric reset");
    w_rstn <= 0;
    #(WCLK_PERIOD*5);
    check(r_rstn === 1'b1, "read domain reset line untouched by write-side reset");
    check(r_empty !== 1'bx, "r_empty stayed a clean logic value during asymmetric reset");
    w_rstn <= 1;
    #(WCLK_PERIOD*3);
    q_head = 0; q_tail = 0;
    single_write(8'h3C);
    #(RCLK_PERIOD*4);
    check(!r_empty, "write visible after w_rstn recovery");
    check_read(8'h3C);

    // CASE 6a: extreme ratio - fast write / slow read (25:1)
    
    $display("\n===== CASE 6a: fast write (10ns) / slow read (250ns) =====");
    WCLK_PERIOD = 10;
    RCLK_PERIOD = 250;
    reset_both;
    w_data <= data_counter[DATA_SIZE-1:0]; 
    data_counter = data_counter + 1;
    w_incr <= 1'b1;
    for (i = 0; i < DEPTH + 4; i = i + 1) begin
      @(posedge w_clk);
      w_data <= data_counter[DATA_SIZE-1:0]; 
      data_counter = data_counter + 1;
    end
    @(posedge w_clk);
    w_incr <= 1'b0;
    #(RCLK_PERIOD*3); 
    check(w_full, "fast writer fills, held at full by slow reader");
    check(accepted_count == DEPTH, "exactly DEPTH writes accepted despite 25:1 ratio burst");

    begin : drain6a
      for (i = 0; i < DEPTH; i = i + 1) begin
        while (r_empty) @(posedge r_clk);
        r_incr <= 1'b1;
        @(posedge r_clk);
        r_incr <= 1'b0;
      end
    end
    #(RCLK_PERIOD*2);
    check(r_empty, "slow reader eventually drains fully, no data lost");

    // CASE 6b: extreme ratio - slow write / fast read
    
    $display("\n===== CASE 6b: slow write (250ns) / fast read (10ns) =====");
    WCLK_PERIOD = 250;
    RCLK_PERIOD = 10;
    reset_both;
    check(r_empty, "FIFO starts empty for 6b");

    for (i = 0; i < 5; i = i + 1) begin
      single_write(data_counter[DATA_SIZE-1:0]);
      data_counter = data_counter + 1;
      begin : poll6b
        integer poll_count;
        poll_count = 0;
        while (r_empty && poll_count < 200) begin
          @(posedge r_clk);
          poll_count = poll_count + 1;
        end
        check(!r_empty, "fast reader sees the slow write show up");
        r_incr <= 1'b1;
        @(posedge r_clk);
        r_incr <= 1'b0;
      end
    end
    #(RCLK_PERIOD*4);
    check(r_empty, "fast reader keeps up with slow writer, stays empty");

    // restore defaults
    WCLK_PERIOD = 10;
    RCLK_PERIOD = 25;

    #(WCLK_PERIOD*10);

    if (errors == 0) begin
      $display("\n=========================================");
      $display("ALL 8 CASES PASSED (0 errors total)");
      $display("=========================================");
    end else begin
      $display("\n=========================================");
      $display("STRESS SUITE FAILED: %0d error(s) total", errors);
      $display("=========================================");
    end
    $finish;
  end


  initial begin
    #2000000;
    $display("[%0t] WATCHDOG TIMEOUT", $time);
    $finish;
  end

endmodule