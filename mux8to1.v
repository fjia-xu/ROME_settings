`timescale 1ns/1ps

module mux8to1tb;

  reg  [7:0] in;
  reg  [2:0] sel;
  wire out;

  integer errors;
  integer i, j;
  reg exp_out;

  // Expected DUT interface:
  // module mux8to1(input [2:0] sel, input [7:0] in, output reg out);
  mux8to1 dut (
    .sel(sel),
    .in(in),
    .out(out)
  );

  task apply_and_check;
    input [7:0] t_in;
    input [2:0] t_sel;
    begin
      in  = t_in;
      sel = t_sel;
      #1;

      // sel=0..7 -> in[0]..in[7]
      case (t_sel)
        3'd0: exp_out = t_in[0];
        3'd1: exp_out = t_in[1];
        3'd2: exp_out = t_in[2];
        3'd3: exp_out = t_in[3];
        3'd4: exp_out = t_in[4];
        3'd5: exp_out = t_in[5];
        3'd6: exp_out = t_in[6];
        3'd7: exp_out = t_in[7];
        default: exp_out = 1'b0;
      endcase

      if (out !== exp_out) begin
        errors = errors + 1;
        $display("[%0t] ERROR: in=%b sel=%0d | out=%b exp=%b",
                 $time, in, sel, out, exp_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    $dumpfile("mux8to1tb.vcd");
    $dumpvars(0, mux8to1tb);

    // Exhaustive: 256 input patterns * 8 selects = 2048 checks
    for (i = 0; i < 256; i = i + 1)
      for (j = 0; j < 8; j = j + 1)
        apply_and_check(i[7:0], j[2:0]);

    // Random stress (binary-only)
    repeat (2000) begin
      in  = $random;
      sel = $random;
      in  = in  & 8'hFF;
      sel = sel & 3'h7;
      apply_and_check(in, sel);
    end

    if (errors == 0) $display("passed!");
    else             $display("failed! errors=%0d", errors);

    $finish;
  end

endmodule
