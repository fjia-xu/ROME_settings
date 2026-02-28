```verilog
`timescale 1ns/1ps

// Comprehensive self-checking testbench for mux8to1
// Assumed DUT interface (consistent with mux2to1/mux4to1 style):
//   module mux8to1(
//     input  wire in1,in2,in3,in4,in5,in6,in7,in8,
//     input  wire [2:0] select,
//     output wire out
//   );
//
// If your port names/order differ, only edit the DUT instantiation section.

module mux8to1tb;

  reg  in1,in2,in3,in4,in5,in6,in7,in8;
  reg  [2:0] select;
  wire out;

  // ---- DUT ----
  mux8to1 dut (
    .in1(in1), .in2(in2), .in3(in3), .in4(in4),
    .in5(in5), .in6(in6), .in7(in7), .in8(in8),
    .select(select),
    .out(out)
  );

  integer errors;
  integer i, j;
  integer seed;
  integer nrand;

  reg exp_out;

  function automatic reg expected_mux8;
    input reg t1,t2,t3,t4,t5,t6,t7,t8;
    input reg [2:0] ts;
    begin
      if      (ts === 3'b000) expected_mux8 = t1;
      else if (ts === 3'b001) expected_mux8 = t2;
      else if (ts === 3'b010) expected_mux8 = t3;
      else if (ts === 3'b011) expected_mux8 = t4;
      else if (ts === 3'b100) expected_mux8 = t5;
      else if (ts === 3'b101) expected_mux8 = t6;
      else if (ts === 3'b110) expected_mux8 = t7;
      else if (ts === 3'b111) expected_mux8 = t8;
      else begin
        // Unknown select: if all candidates equal, output resolves to that value; else X.
        if ((t1===t2)&&(t2===t3)&&(t3===t4)&&(t4===t5)&&(t5===t6)&&(t6===t7)&&(t7===t8))
          expected_mux8 = t1;
        else
          expected_mux8 = 1'bx;
      end
    end
  endfunction

  task apply_and_check;
    input reg t1,t2,t3,t4,t5,t6,t7,t8;
    input reg [2:0] ts;
    begin
      in1=t1; in2=t2; in3=t3; in4=t4; in5=t5; in6=t6; in7=t7; in8=t8;
      select=ts;
      #1;
      exp_out = expected_mux8(in1,in2,in3,in4,in5,in6,in7,in8,select);
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in={%b%b%b%b%b%b%b%b} sel=%b | out=%b exp=%b",
                 $time, in1,in2,in3,in4,in5,in6,in7,in8, select, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    // Optional knobs:
    //   +SEED=1234 +NRAND=20000
    seed  = 32'h1BADF00D;
    nrand = 20000;
    if ($value$plusargs("SEED=%d", seed))   $display("Using SEED=%0d", seed);
    if ($value$plusargs("NRAND=%d", nrand)) $display("Using NRAND=%0d", nrand);

    $dumpfile("mux8to1tb.vcd");
    $dumpvars(0, mux8to1tb);

    // ---- 0) Initialize ----
    in1=0;in2=0;in3=0;in4=0;in5=0;in6=0;in7=0;in8=0; select=0;
    #2;

    // ---- 1) Exhaustive for select (binary-only) across representative input patterns ----
    // Full exhaustive of 2^8 inputs is 256 * 8 = 2048 checks (fast). We'll do it.
    for (i = 0; i < 256; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        apply_and_check(i[7],i[6],i[5],i[4],i[3],i[2],i[1],i[0], j[2:0]);
      end
    end

    // ---- 2) One-hot and walking-1 patterns (catch swapped ports) ----
    apply_and_check(1,0,0,0,0,0,0,0, 3'b000);
    apply_and_check(1,0,0,0,0,0,0,0, 3'b001);
    apply_and_check(1,0,0,0,0,0,0,0, 3'b010);
    apply_and_check(1,0,0,0,0,0,0,0, 3'b111);

    apply_and_check(0,1,0,0,0,0,0,0, 3'b001);
    apply_and_check(0,0,1,0,0,0,0,0, 3'b010);
    apply_and_check(0,0,0,1,0,0,0,0, 3'b011);
    apply_and_check(0,0,0,0,1,0,0,0, 3'b100);
    apply_and_check(0,0,0,0,0,1,0,0, 3'b101);
    apply_and_check(0,0,0,0,0,0,1,0, 3'b110);
    apply_and_check(0,0,0,0,0,0,0,1, 3'b111);

    // ---- 3) X/Z select robustness ----
    apply_and_check(0,1,0,1,0,1,0,1, 3'bxxx);
    apply_and_check(1,0,1,0,1,0,1,0, 3'bx01);
    apply_and_check(0,0,0,0,0,0,0,0, 3'bxxx); // should resolve 0
    apply_and_check(1,1,1,1,1,1,1,1, 3'bxxx); // should resolve 1

    // ---- 4) X/Z on data inputs (selected lane only + some noise elsewhere) ----
    apply_and_check(1'bx,0,0,0,0,0,0,0, 3'b000);
    apply_and_check(0,1'bz,0,0,0,0,0,0, 3'b001);
    apply_and_check(0,0,1'bx,0,0,0,0,0, 3'b010);
    apply_and_check(0,0,0,1'bz,0,0,0,0, 3'b011);
    apply_and_check(0,0,0,0,1'bx,0,0,0, 3'b100);
    apply_and_check(0,0,0,0,0,1'bz,0,0, 3'b101);
    apply_and_check(0,0,0,0,0,0,1'bx,0, 3'b110);
    apply_and_check(0,0,0,0,0,0,0,1'bz, 3'b111);

    // ---- 5) Random torture (binary + occasional X/Z injection) ----
    for (i = 0; i < nrand; i = i + 1) begin
      seed = seed * 1103515245 + 12345; in1 = seed[0];
      seed = seed * 1103515245 + 12345; in2 = seed[0];
      seed = seed * 1103515245 + 12345; in3 = seed[0];
      seed = seed * 1103515245 + 12345; in4 = seed[0];
      seed = seed * 1103515245 + 12345; in5 = seed[0];
      seed = seed * 1103515245 + 12345; in6 = seed[0];
      seed = seed * 1103515245 + 12345; in7 = seed[0];
      seed = seed * 1103515245 + 12345; in8 = seed[0];
      seed = seed * 1103515245 + 12345; select = seed[2:0];

      // occasional unknowns to stress "case/default" behavior
      if ((i % 127) == 0) select = 3'bxxx;
      if ((i % 257) == 0) in3    = 1'bx;
      if ((i % 509) == 0) in8    = 1'bz;

      #1;
      exp_out = expected_mux8(in1,in2,in3,in4,in5,in6,in7,in8,select);
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(RND #%0d): in={%b%b%b%b%b%b%b%b} sel=%b | out=%b exp=%b",
                 $time, i, in1,in2,in3,in4,in5,in6,in7,in8, select, out, exp_out);
      end
    end

    // ---- Summary ----
    if (errors == 0) $display("PASS: mux8to1tb finished with 0 errors.");
    else             $display("FAIL: mux8to1tb finished with %0d errors.", errors);

    $finish;
  end

endmodule
```
