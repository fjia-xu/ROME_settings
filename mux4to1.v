`timescale 1ns/1ps

module mux4to1tb;

  reg  [3:0] in;
  reg  [1:0] sel;
  wire out;

  integer errors;
  integer i, j;
  reg exp_out;

  // DUT: module mux4to1(input [1:0] sel, input [3:0] in, output reg out);
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

      // Expected mapping: sel=0..3 -> in[0]..in[3]
      case (t_sel)
        2'b00: exp_out = t_in[0];
        2'b01: exp_out = t_in[1];
        2'b10: exp_out = t_in[2];
        2'b11: exp_out = t_in[3];
      endcase

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

    // Exhaustive binary test: 16 input patterns * 4 selects
    for (i = 0; i < 16; i = i + 1)
      for (j = 0; j < 4; j = j + 1)
        apply_and_check(i[3:0], j[1:0]);

    // Random binary stress (no X/Z)
    repeat (1000) begin
      in  = $random; in  = in  & 4'hF;
      sel = $random; sel = sel & 2'h3;
      apply_and_check(in, sel);
    end

    // Notebook looks for this exact substring:
    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;
  end

endmodule
