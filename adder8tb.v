`timescale 1ns/1ps

// Stricter self-checking testbench for adder8
// Expected DUT interface:
//   module adder8(
//     input  wire [7:0] a,
//     input  wire [7:0] b,
//     input  wire       cin,
//     output wire [7:0] sum,
//     output wire       cout
//   );

module adder8_tb;

  reg  [7:0] a, b;
  reg        cin;
  wire [7:0] sum;
  wire       cout;

  integer errors;
  integer ia, ib, ic;
  integer i;
  integer seed;
  integer nrand;
  integer bit;
  integer idx;

  reg  [7:0] exp_sum;
  reg        exp_cout;

  // DUT
  adder8 dut (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
  );

  // Ripple-carry golden model (bit-accurate, 4-state friendly)
  task compute_expected;
    input [7:0] ta;
    input [7:0] tb;
    input       tcin;
    reg c;
    begin
      c = tcin;
      for (bit = 0; bit < 8; bit = bit + 1) begin
        exp_sum[bit] = ta[bit] ^ tb[bit] ^ c;
        c = (ta[bit] & tb[bit]) | (ta[bit] & c) | (tb[bit] & c);
      end
      exp_cout = c;
    end
  endtask

  // Strict check: must match at delta-cycle (#0) and remain stable/matching after #1
  task apply_and_check_strict;
    input [7:0] ta;
    input [7:0] tb;
    input       tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;

      compute_expected(ta, tb, tcin);

      // 1) Delta-cycle correctness (catches clocked logic / delayed assignments)
      #0;
      if (sum !== exp_sum) begin
        errors = errors + 1;
        $display("[%0t] ERROR(#0 sum): a=%b b=%b cin=%b | sum=%b exp=%b",
                 $time, a, b, cin, sum, exp_sum);
      end
      if (cout !== exp_cout) begin
        errors = errors + 1;
        $display("[%0t] ERROR(#0 cout): a=%b b=%b cin=%b | cout=%b exp=%b",
                 $time, a, b, cin, cout, exp_cout);
      end

      // 2) Stability / no delayed change
      #1;
      if (sum !== exp_sum) begin
        errors = errors + 1;
        $display("[%0t] ERROR(#1 sum): a=%b b=%b cin=%b | sum=%b exp=%b",
                 $time, a, b, cin, sum, exp_sum);
      end
      if (cout !== exp_cout) begin
        errors = errors + 1;
        $display("[%0t] ERROR(#1 cout): a=%b b=%b cin=%b | cout=%b exp=%b",
                 $time, a, b, cin, cout, exp_cout);
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional knobs: +SEED=1234 +NRAND=80000
    seed  = 32'hADD38ADD;
    nrand = 80000;
    if ($value$plusargs("SEED=%d", seed))   $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    $dumpfile("adder8_tb.vcd");
    $dumpvars(0, adder8_tb);

    // ------------------------------------------------------------
    // 1) FULL exhaustive binary test (harder to pass)
    //    256 * 256 * 2 = 131072 vectors
    // ------------------------------------------------------------
    for (ia = 0; ia < 256; ia = ia + 1) begin
      for (ib = 0; ib < 256; ib = ib + 1) begin
        for (ic = 0; ic < 2; ic = ic + 1) begin
          apply_and_check_strict(ia[7:0], ib[7:0], ic[0]);
        end
      end
    end

    // ------------------------------------------------------------
    // 2) Directed carry-chain torture (very sensitive to wiring mistakes)
    // ------------------------------------------------------------
    apply_and_check_strict(8'h00, 8'h00, 1'b0);
    apply_and_check_strict(8'h00, 8'h00, 1'b1);
    apply_and_check_strict(8'hFF, 8'h00, 1'b0);
    apply_and_check_strict(8'hFF, 8'h00, 1'b1);
    apply_and_check_strict(8'hFF, 8'h01, 1'b0);
    apply_and_check_strict(8'h7F, 8'h01, 1'b0); // ripple across bits 0..6
    apply_and_check_strict(8'h80, 8'h80, 1'b0); // MSB carry
    apply_and_check_strict(8'h55, 8'hAA, 1'b0);
    apply_and_check_strict(8'hAA, 8'h55, 1'b1);

    // Toggle-only-cin sensitivity (catches missing cin in sensitivity list)
    a = 8'h3C; b = 8'hA7; cin = 1'b0;
    apply_and_check_strict(8'h3C, 8'hA7, 1'b0);
    apply_and_check_strict(8'h3C, 8'hA7, 1'b1);

    // ------------------------------------------------------------
    // 3) Random stress with X/Z injection (harder than your previous xprop-only rule)
    //    This uses the ripple reference model for X/Z too.
    // ------------------------------------------------------------
    for (i = 0; i < nrand; i = i + 1) begin
      // LCG for reproducibility
      seed = seed * 1103515245 + 12345; a   = seed[7:0];
      seed = seed * 1103515245 + 12345; b   = seed[7:0];
      seed = seed * 1103515245 + 12345; cin = seed[0];

      // Occasionally inject X/Z on random bits (makes it much stricter)
      if ((i % 211) == 0) begin
        idx = ($random & 7);
        a[idx] = 1'bx;
      end
      if ((i % 397) == 0) begin
        idx = ($random & 7);
        b[idx] = 1'bz;
      end
      if ((i % 997) == 0) cin = 1'bx;

      apply_and_check_strict(a, b, cin);
    end

    // Keep "passed!" unchanged (plus a final line to keep parsers happy)
    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);
    $display("done");

    $finish;
  end

endmodule
