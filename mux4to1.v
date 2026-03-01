`timescale 1ns/1ps

module mux4to1tb;

  reg  [3:0] in;
  reg  [1:0] sel;
  wire out;

  integer errors;
  integer i, j;
  reg exp_out;

  mux4to1 dut (
    .sel(sel),
    .in(in),
    .out(out)
  );

  task apply_and_check;
    input [3:0] t_in;
    input [1:0] t_sel;
    begin
      in  = t_in;
      sel = t_sel;
      #1;

      // Expected mapping for your hierarchical design: sel=0..3 -> in[0]..in[3]
      exp_out = in[sel];

      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in=%b sel=%b | out=%b exp=%b",
                 $time, in, sel, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    $dumpfile("mux4to1tb.vcd");
    $dumpvars(0, mux4to1tb);

    // Exhaustive binary test: 16 input patterns * 4 selects = 64 checks
    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        apply_and_check(i[3:0], j[1:0]);
      end
    end

    // Random binary stress (no X/Z)
    repeat (1000) begin
      in  = $random;
      sel = $random;
      in  = in  & 4'hF;
      sel = sel & 2'h3;
      #1;

      exp_out = in[sel];
      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR(RND): in=%b sel=%b | out=%b exp=%b",
                 $time, in, sel, out, exp_out);
      end
    end

    if (errors == 0) begin
      $display("passed!");
    end else begin
      $display("failed! errors=%0d", errors);
    end

    $finish;
  end

endmodule
