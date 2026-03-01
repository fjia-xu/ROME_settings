`timescale 1ns/1ps

// Strict self-checking testbench for half_adder
// Expected DUT interface:
//   module half_adder(input wire a, input wire b, output wire sum, output wire carry);

module half_adder_tb;

  reg  a, b;
  wire sum, carry;

  integer errors;
  integer i;

  // DUT
  half_adder dut (
    .a(a),
    .b(b),
    .sum(sum),
    .carry(carry)
  );

  // Strict expected (supports X/Z propagation via bitwise ops)
  reg exp_sum, exp_carry;

  task apply_and_check;
    input reg ta;
    input reg tb;
    begin
      a = ta;
      b = tb;
      #1;

      exp_sum   = a ^ b;
      exp_carry = a & b;

      if (sum !== exp_sum) begin
        errors = errors + 1;
        $display("[%0t] ERROR(sum): a=%b b=%b | sum=%b exp=%b", $time, a, b, sum, exp_sum);
      end
      if (carry !== exp_carry) begin
        errors = errors + 1;
        $display("[%0t] ERROR(carry): a=%b b=%b | carry=%b exp=%b", $time, a, b, carry, exp_carry);
      end
    end
  endtask

  initial begin
    errors = 0;

    $dumpfile("half_adder_tb.vcd");
    $dumpvars(0, half_adder_tb);

    // 1) Exhaustive binary truth-table
    for (i = 0; i < 4; i = i + 1)
      apply_and_check(i[1], i[0]);

    // 2) X/Z robustness (strict)
    apply_and_check(1'bx, 1'b0);
    apply_and_check(1'b0, 1'bx);
    apply_and_check(1'bx, 1'b1);
    apply_and_check(1'b1, 1'bx);
    apply_and_check(1'bx, 1'bx);

    apply_and_check(1'bz, 1'b0);
    apply_and_check(1'b0, 1'bz);
    apply_and_check(1'bz, 1'b1);
    apply_and_check(1'b1, 1'bz);
    apply_and_check(1'bz, 1'bz);

    // 3) Random stress incl. occasional X/Z
    repeat (2000) begin
      a = $random; a = a & 1'b1;
      b = $random; b = b & 1'b1;

      if (($random % 97)  == 0) a = 1'bx;
      if (($random % 193) == 0) b = 1'bz;

      #1;

      exp_sum   = a ^ b;
      exp_carry = a & b;

      if (sum !== exp_sum)   errors = errors + 1;
      if (carry !== exp_carry) errors = errors + 1;
    end

    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;
  end

endmodule