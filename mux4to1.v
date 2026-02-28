```verilog
`timescale 1ns/1ps

// Comprehensive self-checking testbench for mux4to1
// Assumed DUT interface (consistent with your mux2to1 style):
//   module mux4to1(
//     input  wire in1, in2, in3, in4,
//     input  wire [1:0] select,
//     output wire out
//   );
//
// If your port names/order differ, only edit the DUT instantiation section.

module mux4to1tb;

  reg  in1, in2, in3, in4;
  reg  [1:0] select;
  wire out;

  // ---- DUT ----
  mux4to1 dut (
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .in4(in4),
    .select(select),
    .out(out)
  );

  integer errors;
  integer i, j;
  integer seed;
  integer nrand;

  reg exp_out;

  function automatic reg expected_mux4;
    input reg t_in1, t_in2, t_in3, t_in4;
    input reg [1:0] t_sel;
    begin
      // Use case equality so X/Z in select propagate in a controlled way.
      // If select is X/Z, default to conditional-operator semantics by computing:
      //   ((sel==0)?in1:(sel==1)?in2:(sel==2)?in3:(sel==3)?in4:1'bx)
      // but for X/Z we return the same as nested ?: behavior by using
      // a cascade of (t_sel===...) checks.
      if      (t_sel === 2'b00) expected_mux4 = t_in1;
      else if (t_sel === 2'b01) expected_mux4 = t_in2;
      else if (t_sel === 2'b10) expected_mux4 = t_in3;
      else if (t_sel === 2'b11) expected_mux4 = t_in4;
      else begin
        // If select is partially/fully unknown, nested ?: semantics:
        // in Verilog, (sel ? a : b) with sel==X can resolve when a==b.
        // For 4:1, we approximate by returning X unless all candidates match.
        // This catches incorrect "default 0" implementations.
        if ((t_in1 === t_in2) && (t_in2 === t_in3) && (t_in3 === t_in4))
          expected_mux4 = t_in1;
        else
          expected_mux4 = 1'bx;
      end
    end
  endfunction

  task apply_and_check;
    input reg t_in1, t_in2, t_in3, t_in4;
    input reg [1:0] t_sel;
    begin
      in1 = t_in1; in2 = t_in2; in3 = t_in3; in4 = t_in4; select = t_sel;
      #1; // settle

      exp_out = expected_mux4(in1, in2, in3, in4, select);

      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in={%b,%b,%b,%b} sel=%b | out=%b exp=%b",
                 $time, in1,in2,in3,in4, select, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional knobs:
    //   +SEED=1234 +NRAND=5000
    seed  = 32'hBADC0DE;
    nrand = 5000;
    if ($value$plusargs("SEED=%d", seed))   $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    $dumpfile("mux4to1tb.vcd");
    $dumpvars(0, mux4to1tb);

    // ---- 0) Initialize ----
    in1=0; in2=0; in3=0; in4=0; select=0;
    #2;

    // ---- 1) Exhaustive inputs for each select (binary-only) ----
    // 16 input patterns * 4 selects = 64 checks
    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        apply_and_check(i[3], i[2], i[1], i[0], j[1:0]);
      end
    end

    // ---- 2) One-hot and walking patterns (help catch swapped ports) ----
    apply_and_check(1,0,0,0, 2'b00);
    apply_and_check(1,0,0,0, 2'b01);
    apply_and_check(1,0,0,0, 2'b10);
    apply_and_check(1,0,0,0, 2'b11);

    apply_and_check(0,1,0,0, 2'b00);
    apply_and_check(0,1,0,0, 2'b01);
    apply_and_check(0,1,0,0, 2'b10);
    apply_and_check(0,1,0,0, 2'b11);

    apply_and_check(0,0,1,0, 2'b00);
    apply_and_check(0,0,1,0, 2'b01);
    apply_and_check(0,0,1,0, 2'b10);
    apply_and_check(0,0,1,0, 2'b11);

    apply_and_check(0,0,0,1, 2'b00);
    apply_and_check(0,0,0,1, 2'b01);
    apply_and_check(0,0,0,1, 2'b10);
    apply_and_check(0,0,0,1, 2'b11);

    // ---- 3) X/Z select robustness ----
    apply_and_check(0,1,0,1, 2'bxx);
    apply_and_check(1,0,1,0, 2'bx1);
    apply_and_check(1,1,0,0, 2'b1x);
    apply_and_check(0,0,0,0, 2'bxx); // should be 0 (all equal)
    apply_and_check(1,1,1,1, 2'bxx); // should be 1 (all equal)

    // ---- 4) X/Z on data inputs ----
    apply_and_check(1'bx,0,0,0, 2'b00);
    apply_and_check(0,1'bz,0,0, 2'b01);
    apply_and_check(0,0,1'bx,0, 2'b10);
    apply_and_check(0,0,0,1'bz, 2'b11);

    // ---- 5) Random torture (binary + occasional X/Z injection) ----
    for (i = 0; i < nrand; i = i + 1) begin
      seed = seed * 1103515245 + 12345; in1 = seed[0];
      seed = seed * 1103515245 + 12345; in2 = seed[0];
      seed = seed * 1103515245 + 12345; in3 = seed[0];
      seed = seed * 1103515245 + 12345; in4 = seed[0];
      seed = seed * 1103515245 + 12345; select = seed[1:0];

      // occasional unknowns
      if ((i % 101) == 0) select = 2'bxx;
      if ((i % 233) == 0) in2    = 1'bx;
      if ((i % 389) == 0) in4    = 1'bz;

      #1;
      exp_out = expected_mux4(in1, in2, in3, in4, select);
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(RND #%0d): in={%b,%b,%b,%b} sel=%b | out=%b exp=%b",
                 $time, i, in1,in2,in3,in4, select, out, exp_out);
      end
    end

    // ---- Summary ----
    if (errors == 0) $display("PASS: mux4to1tb finished with 0 errors.");
    else             $display("FAIL: mux4to1tb finished with %0d errors.", errors);

    $finish;
  end

endmodule
```
