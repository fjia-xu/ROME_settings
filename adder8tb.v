`timescale 1ns/1ps

// Strict self-checking testbench for adder8
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
  integer i;
  integer seed;
  integer nrand;

  reg  [8:0] exp;      // {cout,sum}
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

  // Exact check for binary-only inputs
  task apply_and_check_bin;
    input [7:0] ta;
    input [7:0] tb;
    input       tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      exp      = {1'b0, ta} + {1'b0, tb} + {{8{1'b0}}, tcin};
      exp_sum  = exp[7:0];
      exp_cout = exp[8];

      if (sum !== exp_sum) begin
        errors = errors + 1;
        $display("[%0t] ERROR(sum): a=%h b=%h cin=%b | sum=%h exp=%h",
                 $time, a, b, cin, sum, exp_sum);
      end
      if (cout !== exp_cout) begin
        errors = errors + 1;
        $display("[%0t] ERROR(cout): a=%h b=%h cin=%b | cout=%b exp=%b",
                 $time, a, b, cin, cout, exp_cout);
      end
    end
  endtask

  // Strict-ish X/Z propagation check:
  // If any input contains X/Z, output should not be fully-known (all 0/1) for BOTH sum and cout.
  task apply_and_check_xprop;
    input [7:0] ta;
    input [7:0] tb;
    input       tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      if ( (^ta === 1'bx) || (^tb === 1'bx) || (tcin === 1'bx) || (tcin === 1'bz) ) begin
        if ( (^sum !== 1'bx) && (cout === 1'b0 || cout === 1'b1) ) begin
          errors = errors + 1;
          $display("[%0t] ERROR(XPROP): a=%b b=%b cin=%b | sum=%b cout=%b (expected some X/Z)",
                   $time, a, b, cin, sum, cout);
        end
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional knobs: +SEED=1234 +NRAND=50000
    seed  = 32'hADD38ADD;
    nrand = 50000;
    if ($value$plusargs("SEED=%d", seed))   $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    $dumpfile("adder8_tb.vcd");
    $dumpvars(0, adder8_tb);

    // 1) Exhaustive over a reduced but strong set:
    // - All 256 values for a, with b patterns that stress carries
    // - Both cin values
    for (i = 0; i < 256; i = i + 1) begin
      apply_and_check_bin(i[7:0], 8'h00, 1'b0);
      apply_and_check_bin(i[7:0], 8'h00, 1'b1);

      apply_and_check_bin(i[7:0], 8'h01, 1'b0);
      apply_and_check_bin(i[7:0], 8'h01, 1'b1);

      apply_and_check_bin(i[7:0], 8'h0F, 1'b0);
      apply_and_check_bin(i[7:0], 8'h0F, 1'b1);

      apply_and_check_bin(i[7:0], 8'hF0, 1'b0);
      apply_and_check_bin(i[7:0], 8'hF0, 1'b1);

      apply_and_check_bin(i[7:0], 8'hFF, 1'b0);
      apply_and_check_bin(i[7:0], 8'hFF, 1'b1);

      apply_and_check_bin(i[7:0], ~i[7:0], 1'b0);
      apply_and_check_bin(i[7:0], ~i[7:0], 1'b1);
    end

    // 2) Corner cases
    apply_and_check_bin(8'h00, 8'h00, 1'b0);
    apply_and_check_bin(8'hFF, 8'h00, 1'b0);
    apply_and_check_bin(8'hFF, 8'h01, 1'b0);
    apply_and_check_bin(8'hFF, 8'hFF, 1'b0);
    apply_and_check_bin(8'hFF, 8'hFF, 1'b1);
    apply_and_check_bin(8'h80, 8'h80, 1'b0);
    apply_and_check_bin(8'h7F, 8'h01, 1'b0);

    // 3) X/Z propagation checks (strict-ish)
    apply_and_check_xprop(8'bxxxxxxxx, 8'h00, 1'b0);
    apply_and_check_xprop(8'h00, 8'bzzzzzzzz, 1'b0);
    apply_and_check_xprop(8'hA5, 8'h5A, 1'bx);
    apply_and_check_xprop(8'h00, 8'h00, 1'bz);
    apply_and_check_xprop(8'b10x10101, 8'h55, 1'b0);
    apply_and_check_xprop(8'hAA, 8'b01z10110, 1'b1);

    // 4) Random stress: mostly binary, with occasional X/Z injection
    repeat (nrand) begin
      seed = seed * 1103515245 + 12345; a   = seed[7:0];
      seed = seed * 1103515245 + 12345; b   = seed[7:0];
      seed = seed * 1103515245 + 12345; cin = seed[0];

      // occasionally inject X/Z on bits
      if (($random % 257) == 0) a[ $random % 8 ] = 1'bx;
      if (($random % 509) == 0) b[ $random % 8 ] = 1'bz;
      if (($random % 997) == 0) cin = 1'bx;

      #1;

      if ( (^a !== 1'bx) && (^b !== 1'bx) && (cin === 1'b0 || cin === 1'b1) ) begin
        exp      = {1'b0, a} + {1'b0, b} + {{8{1'b0}}, cin};
        exp_sum  = exp[7:0];
        exp_cout = exp[8];
        if (sum !== exp_sum)   errors = errors + 1;
        if (cout !== exp_cout) errors = errors + 1;
      end else begin
        if ( (^sum !== 1'bx) && (cout === 1'b0 || cout === 1'b1) ) begin
          errors = errors + 1;
          $display("[%0t] ERROR(XPROP-RND): a=%b b=%b cin=%b | sum=%b cout=%b",
                   $time, a, b, cin, sum, cout);
        end
      end
    end

    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;
  end

endmodule