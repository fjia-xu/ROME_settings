`timescale 1ns/1ps

// Comprehensive self-checking testbench for mux2to1
// Expected DUT interface (from your notebook):
//   module mux2to1(input wire in1, input wire in2, input wire select, output wire out);

module mux2to1tb;

  reg  in1;
  reg  in2;
  reg  select;
  wire out;

  // ---- DUT ----
  mux2to1 dut (
    .in1(in1),
    .in2(in2),
    .select(select),
    .out(out)
  );

  integer i;
  integer errors;
  integer seed;
  integer nrand;

  // Compute expected using Verilog mux semantics (handles X/Z like a typical "?:")
  reg exp_out;

  task apply_and_check;
    input reg t_in1;
    input reg t_in2;
    input reg t_sel;
    begin
      in1    = t_in1;
      in2    = t_in2;
      select = t_sel;
      #1; // allow combinational settle

      exp_out = (select ? in2 : in1);

      // Case-inequality catches mismatches including X/Z differences
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in1=%b in2=%b sel=%b | out=%b exp=%b",
                 $time, in1, in2, select, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional runtime controls:
    //   +SEED=1234 +NRAND=5000
    seed  = 32'hC0FFEE;
    nrand = 2000;
    if ($value$plusargs("SEED=%d", seed))  $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    // Waveform
    $dumpfile("mux2to1tb.vcd");
    $dumpvars(0, mux2to1tb);

    // ---- 0) Initialize ----
    in1 = 0; in2 = 0; select = 0;
    #2;

    // ---- 1) Exhaustive binary truth-table (all 8 combos) ----
    for (i = 0; i < 8; i = i + 1) begin
      apply_and_check(i[2], i[1], i[0]); // {in1,in2,sel}
    end

    // ---- 2) Structured stress patterns (toggle each input repeatedly) ----
    in1 = 0; in2 = 0; select = 0; #1;
    for (i = 0; i < 16; i = i + 1) begin
      in1    = i[0];
      in2    = i[1];
      select = i[2];
      #1;
      exp_out = (select ? in2 : in1);
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(PAT): in1=%b in2=%b sel=%b | out=%b exp=%b",
                 $time, in1, in2, select, out, exp_out);
      end
    end

    // ---- 3) X/Z robustness checks (helps catch incorrect default/case handling) ----
    // These expectations match the conditional operator semantics.
    apply_and_check(1'b0, 1'b1, 1'bx);
    apply_and_check(1'b1, 1'b0, 1'bx);
    apply_and_check(1'b0, 1'b0, 1'bx); // should resolve to 0 for a ?: mux
    apply_and_check(1'b1, 1'b1, 1'bx); // should resolve to 1 for a ?: mux
    apply_and_check(1'bz, 1'b0, 1'b0);
    apply_and_check(1'b0, 1'bz, 1'b1);
    apply_and_check(1'bx, 1'b1, 1'b0);
    apply_and_check(1'b1, 1'bx, 1'b1);
    apply_and_check(1'bx, 1'bz, 1'bx);

    // ---- 4) Randomized torture ----
    for (i = 0; i < nrand; i = i + 1) begin
      // Use seed so results can be reproduced
      seed   = (seed * 1103515245 + 12345);
      in1    = seed[0];
      seed   = (seed * 1103515245 + 12345);
      in2    = seed[0];
      seed   = (seed * 1103515245 + 12345);
      select = seed[0];

      // Occasionally inject X/Z
      if ((i % 97) == 0)  select = 1'bx;
      if ((i % 193) == 0) in1    = 1'bx;
      if ((i % 389) == 0) in2    = 1'bz;

      #1;
      exp_out = (select ? in2 : in1);
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(RND #%0d): in1=%b in2=%b sel=%b | out=%b exp=%b",
                 $time, i, in1, in2, select, out, exp_out);
      end
    end

    // ---- Summary ----
    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;

  end

endmodule

