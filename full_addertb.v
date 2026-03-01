`timescale 1ns/1ps

// Strict self-checking testbench for full_adder
// Expected DUT interface:
//   module full_adder(input wire a, input wire b, input wire cin,
//                     output wire sum, output wire cout);

module full_adder_tb;

  reg  a, b, cin;
  wire sum, cout;

  integer errors;
  integer i;

  // DUT
  full_adder dut (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
  );

  reg exp_sum, exp_cout;

  task apply_and_check;
    input reg ta;
    input reg tb;
    input reg tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      // Strict expected (bitwise ops propagate X/Z)
      exp_sum  = a ^ b ^ cin;
      exp_cout = (a & b) | (a & cin) | (b & cin);

      if (sum !== exp_sum) begin
        errors = errors + 1;
        $display("[%0t] ERROR(sum): a=%b b=%b cin=%b | sum=%b exp=%b",
                 $time, a, b, cin, sum, exp_sum);
      end
      if (cout !== exp_cout) begin
        errors = errors + 1;
        $display("[%0t] ERROR(cout): a=%b b=%b cin=%b | cout=%b exp=%b",
                 $time, a, b, cin, cout, exp_cout);
      end
    end
  endtask

  initial begin
    errors = 0;

    $dumpfile("full_adder_tb.vcd");
    $dumpvars(0, full_adder_tb);

    // 1) Exhaustive binary truth table (8 combos)
    for (i = 0; i < 8; i = i + 1)
      apply_and_check(i[2], i[1], i[0]);

    // 2) X/Z robustness (strict)
    // Unknown on each input, plus mixed cases
    apply_and_check(1'bx, 1'b0, 1'b0);
    apply_and_check(1'b0, 1'bx, 1'b0);
    apply_and_check(1'b0, 1'b0, 1'bx);
    apply_and_check(1'bx, 1'b1, 1'b0);
    apply_and_check(1'b1, 1'bx, 1'b0);
    apply_and_check(1'b1, 1'b0, 1'bx);
    apply_and_check(1'bx, 1'bx, 1'b0);
    apply_and_check(1'bx, 1'b0, 1'bx);
    apply_and_check(1'b0, 1'bx, 1'bx);
    apply_and_check(1'bx, 1'bx, 1'bx);

    apply_and_check(1'bz, 1'b0, 1'b0);
    apply_and_check(1'b0, 1'bz, 1'b0);
    apply_and_check(1'b0, 1'b0, 1'bz);
    apply_and_check(1'bz, 1'b1, 1'b0);
    apply_and_check(1'b1, 1'bz, 1'b0);
    apply_and_check(1'b1, 1'b0, 1'bz);
    apply_and_check(1'bz, 1'bz, 1'b0);
    apply_and_check(1'bz, 1'b0, 1'bz);
    apply_and_check(1'b0, 1'bz, 1'bz);
    apply_and_check(1'bz, 1'bz, 1'bz);

    // 3) Random stress incl. occasional X/Z injection
    repeat (5000) begin
      a   = $random; a   = a   & 1'b1;
      b   = $random; b   = b   & 1'b1;
      cin = $random; cin = cin & 1'b1;

      if (($random % 101) == 0) a   = 1'bx;
      if (($random % 211) == 0) b   = 1'bz;
      if (($random % 307) == 0) cin = 1'bx;

      #1;

      exp_sum  = a ^ b ^ cin;
      exp_cout = (a & b) | (a & cin) | (b & cin);

      if (sum !== exp_sum)   errors = errors + 1;
      if (cout !== exp_cout) errors = errors + 1;
    end

    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;
  end

endmodule