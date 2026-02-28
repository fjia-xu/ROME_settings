`timescale 1ns/1ps

module mux2to1tb;

  reg  in1, in2, select;
  wire out;

  mux2to1 dut (
    .in1(in1),
    .in2(in2),
    .select(select),
    .out(out)
  );

  integer errors;
  integer i;
  reg exp_out;

  task apply_and_check;
    input reg t_in1;
    input reg t_in2;
    input reg t_sel;   // MUST be 0/1 in this relaxed TB
    begin
      in1 = t_in1;
      in2 = t_in2;
      select = t_sel;
      #1;

      exp_out = (t_sel == 1'b0) ? t_in1 : t_in2;

      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in1=%b in2=%b sel=%b | out=%b exp=%b",
                 $time, in1, in2, select, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    $dumpfile("mux2to1tb.vcd");
    $dumpvars(0, mux2to1tb);

    // Exhaustive binary truth table: 8 combinations
    for (i = 0; i < 8; i = i + 1)
      apply_and_check(i[2], i[1], i[0]);

    // Extra randomized binary testing (no X/Z)
    repeat (1000) begin
      in1    = $random; in1    = in1    & 1'b1;
      in2    = $random; in2    = in2    & 1'b1;
      select = $random; select = select & 1'b1;
      #1;

      exp_out = (select == 1'b0) ? in1 : in2;
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(RND): in1=%b in2=%b sel=%b | out=%b exp=%b",
                 $time, in1, in2, select, out, exp_out);
      end
    end

    if (errors == 0) $display("PASS: mux2to1tb finished with 0 errors.");
    else             $display("FAIL: mux2to1tb finished with %0d errors.", errors);

    $finish;
  end

endmodule
