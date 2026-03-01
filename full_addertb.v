`timescale 1ns/1ps

// Verilog-2001 compatible testbench for full_adder
// Prints "passed!" on success.

module full_adder_tb;

  reg  a, b, cin;
  wire sum, cout;

  integer errors;
  integer i;
  integer DO_XZ;
  integer tmp;

  reg [1:0] exp2;
  reg exp_sum, exp_cout;

  // DUT
  full_adder dut (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
  );

  function is01;
    input v;
    begin
      is01 = (v === 1'b0) || (v === 1'b1);
    end
  endfunction

  task apply_and_check;
    input ta;
    input tb;
    input tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      // If DO_XZ==0, only score checks when inputs are 0/1
      if ((DO_XZ == 0) && !(is01(a) && is01(b) && is01(cin))) begin
        // skip
      end else begin
        exp2     = {1'b0, a} + {1'b0, b} + {1'b0, cin};
        exp_sum  = exp2[0];
        exp_cout = exp2[1];

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

      #1;
    end
  endtask

  initial begin
    errors = 0;
    DO_XZ  = 0;
    tmp = $value$plusargs("DO_XZ=%d", DO_XZ); // optional: vvp a.out +DO_XZ=1

    $dumpfile("full_adder_tb.vcd");
    $dumpvars(0, full_adder_tb);

    // 1) Exhaustive binary truth table (strict)
    for (i = 0; i < 8; i = i + 1)
      apply_and_check(i[2], i[1], i[0]);

    // 2) Optional X/Z vectors (only scored if +DO_XZ=1)
    apply_and_check(1'bx, 1'b0, 1'b0);
    apply_and_check(1'b0, 1'bx, 1'b0);
    apply_and_check(1'b0, 1'b0, 1'bx);
    apply_and_check(1'bz, 1'b1, 1'b0);
    apply_and_check(1'b1, 1'bz, 1'b1);
    apply_and_check(1'bx, 1'bx, 1'bx);
    apply_and_check(1'bz, 1'bz, 1'bz);

    // 3) Random binary stress (always scored)
    repeat (5000) begin
      a   = $random; a   = a   & 1'b1;
      b   = $random; b   = b   & 1'b1;
      cin = $random; cin = cin & 1'b1;
      apply_and_check(a, b, cin);
    end

    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);
    $display("done");

    $finish;
  end

endmodule
