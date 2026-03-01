`timescale 1ns/1ps

// Strict self-checking testbench for adder4
// Expected DUT interface:
//   module adder4(
//     input  wire [3:0] a,
//     input  wire [3:0] b,
//     input  wire       cin,
//     output wire [3:0] sum,
//     output wire       cout
//   );

module adder4_tb;

  reg  [3:0] a, b;
  reg        cin;
  wire [3:0] sum;
  wire       cout;

  integer errors;
  integer i;
  integer seed;
  integer nrand;

  reg  [4:0] exp;      // {cout,sum}
  reg  [3:0] exp_sum;
  reg        exp_cout;

  // DUT
  adder4 dut (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
  );

  task apply_and_check_bin;
    input [3:0] ta;
    input [3:0] tb;
    input       tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      exp      = {1'b0, ta} + {1'b0, tb} + {4'b0, tcin};
      exp_sum  = exp[3:0];
      exp_cout = exp[4];

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

  // Strict X/Z tests:
  // We DON'T attempt to define arithmetic truth for X/Z; we require that if any input bit is X/Z,
  // the DUT must not produce a clean 0/1-only result for BOTH sum and cout (i.e., some unknown should propagate).
  task apply_and_check_xprop;
    input [3:0] ta;
    input [3:0] tb;
    input       tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      // "Strict" propagation check: if any X/Z in inputs, output should contain some X/Z.
      if ( (^ta === 1'bx) || (^tb === 1'bx) || (tcin === 1'bx) || (tcin === 1'bz) ) begin
        if ( (sum === 4'b0000 || sum === 4'b0001 || sum === 4'b0010 || sum === 4'b0011 ||
              sum === 4'b0100 || sum === 4'b0101 || sum === 4'b0110 || sum === 4'b0111 ||
              sum === 4'b1000 || sum === 4'b1001 || sum === 4'b1010 || sum === 4'b1011 ||
              sum === 4'b1100 || sum === 4'b1101 || sum === 4'b1110 || sum === 4'b1111 ) &&
             (cout === 1'b0 || cout === 1'b1) ) begin
          errors = errors + 1;
          $display("[%0t] ERROR(XPROP): a=%b b=%b cin=%b | sum=%b cout=%b (expected some X/Z)",
                   $time, a, b, cin, sum, cout);
        end
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional knobs: +SEED=1234 +NRAND=20000
    seed  = 32'hA44D3R04;
    nrand = 20000;
    if ($value$plusargs("SEED=%d", seed))   $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    $dumpfile("adder4_tb.vcd");
    $dumpvars(0, adder4_tb);

    // 1) Exhaustive binary: 16*16*2 = 512 vectors
    for (i = 0; i < 512; i = i + 1) begin
      apply_and_check_bin(i[8:5], i[4:1], i[0]);
    end

    // 2) Corner cases
    apply_and_check_bin(4'h0, 4'h0, 1'b0);
    apply_and_check_bin(4'hF, 4'h0, 1'b0);
    apply_and_check_bin(4'hF, 4'h1, 1'b0);
    apply_and_check_bin(4'hF, 4'hF, 1'b0);
    apply_and_check_bin(4'hF, 4'hF, 1'b1);

    // 3) X/Z propagation checks (strict-ish)
    apply_and_check_xprop(4'bxxxx, 4'h0, 1'b0);
    apply_and_check_xprop(4'h0, 4'bzzzz, 1'b0);
    apply_and_check_xprop(4'hA, 4'h5, 1'bx);
    apply_and_check_xprop(4'h0, 4'h0, 1'bz);
    apply_and_check_xprop(4'b1x01, 4'b0101, 1'b0);
    apply_and_check_xprop(4'b1010, 4'b01z1, 1'b1);

    // 4) Random binary stress + occasional X/Z injection
    repeat (nrand) begin
      seed = seed * 1103515245 + 12345; a   = seed[3:0];
      seed = seed * 1103515245 + 12345; b   = seed[3:0];
      seed = seed * 1103515245 + 12345; cin = seed[0];

      // mostly binary; occasionally inject X/Z
      if (($random % 257) == 0) a[ $random % 4 ] = 1'bx;
      if (($random % 509) == 0) b[ $random % 4 ] = 1'bz;
      if (($random % 997) == 0) cin = 1'bx;

      #1;

      // If all inputs are 0/1 only, do exact arithmetic check
      if ( (^a !== 1'bx) && (^b !== 1'bx) && (cin === 1'b0 || cin === 1'b1) ) begin
        exp      = {1'b0, a} + {1'b0, b} + {4'b0, cin};
        exp_sum  = exp[3:0];
        exp_cout = exp[4];
        if (sum !== exp_sum)   errors = errors + 1;
        if (cout !== exp_cout) errors = errors + 1;
      end else begin
        // Otherwise enforce X/Z propagation expectation
        if ( (cout === 1'b0 || cout === 1'b1) && (^sum !== 1'bx) ) begin
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