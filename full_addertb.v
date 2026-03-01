`timescale 1ns/1ps

// Binary-strict testbench for full_adder, optional X/Z checking.
// Default: DO_XZ=0 (skip checks when any input is X/Z)
// Enable X/Z checking: run vvp with +DO_XZ=1
//
// Expected DUT:
// module full_adder(input wire a, input wire b, input wire cin,
//                   output wire sum, output wire cout);

module full_adder_tb;

  reg  a, b, cin;
  wire sum, cout;

  integer errors;
  integer i;
  integer DO_XZ;

  reg exp_sum, exp_cout;
  reg [1:0] exp2;

  full_adder dut (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
  );

  function automatic bit is01(input reg v);
    begin
      is01 = (v === 1'b0) || (v === 1'b1);
    end
  endfunction

  task apply_and_check;
    input reg ta;
    input reg tb;
    input reg tcin;
    begin
      a   = ta;
      b   = tb;
      cin = tcin;
      #1;

      // If DO_XZ==0, only score when inputs are known 0/1
      if (!DO_XZ && !(is01(a) && is01(b) && is01(cin))) begin
        // skip
      end else begin
        // Binary-golden reference (also works fine for X/Z in DO_XZ mode: will go X if unknown)
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

      // Separate vectors cleanly in time (prevents same-timestep overlap in wave dumps)
      #1;
    end
  endtask

  initial begin
    errors = 0;
    DO_XZ  = 0;
    void'($value$plusargs("DO_XZ=%d", DO_XZ));

    $dumpfile("full_adder_tb.vcd");
    $dumpvars(0, full_adder_tb);

    // 1) Exhaustive binary truth table (strict)
    for (i = 0; i < 8; i = i + 1)
      apply_and_check(i[2], i[1], i[0]);

    // 2) Optional X/Z vectors (only meaningful if +DO_XZ=1)
    apply_and_check(1'bx, 1'b0, 1'b0);
    apply_and_check(1'b0, 1'bx, 1'b0);
    apply_and_check(1'b0, 1'b0, 1'bx);
    apply_and_check(1'bz, 1'b1, 1'b0);
    apply_and_check(1'b1, 1'bz, 1'b1);
    apply_and_check(1'bx, 1'bx, 1'bx);
    apply_and_check(1'bz, 1'bz, 1'bz);

    // 3) Random binary stress (strict, no X/Z injection)
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
