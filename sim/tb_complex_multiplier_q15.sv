// tb_complex_multiplier_q15.sv
// Self-checking testbench for complex_multiplier_q15.
// Compares against an inline Q1.15 golden model with truncation.
// 1-cycle pipeline: drive on negedge, check previous result on next negedge.

`timescale 1ns/1ps

module tb_complex_multiplier_q15;

    parameter int DATA_W = 16;
    localparam int PROD_W = 2 * DATA_W;
    localparam int ACC_W  = PROD_W + 1;
    localparam int SHIFT  = DATA_W - 1;

    logic                      clk, rst_n;
    logic                      valid_in, sync_in;
    logic signed [DATA_W-1:0]  z_re, z_im, tw_re, tw_im;
    logic                      valid_out, sync_out;
    logic signed [DATA_W-1:0]  y_re, y_im;

    complex_multiplier_q15 #(.DATA_W(DATA_W)) dut (.*);

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    int pass_cnt = 0;
    int fail_cnt = 0;

    // Golden model
    function automatic signed [DATA_W-1:0] gold_re(
        input signed [DATA_W-1:0] zr, zi, tr, ti
    );
        logic signed [PROD_W-1:0] p_rr, p_ii;
        logic signed [ACC_W-1:0]  acc;
        p_rr = zr * tr;
        p_ii = zi * ti;
        acc  = {p_rr[PROD_W-1], p_rr} - {p_ii[PROD_W-1], p_ii};
        gold_re = (acc >>> SHIFT);
    endfunction

    function automatic signed [DATA_W-1:0] gold_im(
        input signed [DATA_W-1:0] zr, zi, tr, ti
    );
        logic signed [PROD_W-1:0] p_ri, p_ir;
        logic signed [ACC_W-1:0]  acc;
        p_ri = zr * ti;
        p_ir = zi * tr;
        acc  = {p_ri[PROD_W-1], p_ri} + {p_ir[PROD_W-1], p_ir};
        gold_im = (acc >>> SHIFT);
    endfunction

    // Pipeline tracking
    logic signed [DATA_W-1:0] prev_exp_re, prev_exp_im;
    string                    prev_label;
    logic                     prev_pending;

    task automatic drive_and_check(
        input string label,
        input signed [DATA_W-1:0] zr, zi, tr, ti,
        input logic vi, si
    );
        // Check previous result (output is registered, so it's ready now)
        if (prev_pending) begin
            if (y_re !== prev_exp_re || y_im !== prev_exp_im) begin
                $display("FAIL %s: exp=(%0d,%0d) got=(%0d,%0d)",
                         prev_label, prev_exp_re, prev_exp_im, y_re, y_im);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("OK   %s: y=(%0d,%0d)", prev_label, y_re, y_im);
                pass_cnt = pass_cnt + 1;
            end
        end

        // Drive new inputs at negedge
        @(negedge clk);
        z_re = zr; z_im = zi; tw_re = tr; tw_im = ti;
        valid_in = vi; sync_in = si;

        // Compute expected for this vector
        prev_exp_re = gold_re(zr, zi, tr, ti);
        prev_exp_im = gold_im(zr, zi, tr, ti);
        prev_label  = label;
        prev_pending = vi;

        // Wait for output to register
        @(posedge clk); #1;
    endtask

    initial begin
        rst_n = 0; valid_in = 0; sync_in = 0;
        z_re = 0; z_im = 0; tw_re = 0; tw_im = 0;
        prev_pending = 0;
        @(posedge clk); @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        // 1. 0.5 * 0.5 (16384 * 16384)
        drive_and_check("half_x_half", 16'sd16384, 16'sd0, 16'sd16384, 16'sd0, 1, 1);

        // 2. Multiply by ~1.0 (32767)
        drive_and_check("by_one", 16'sd10000, 16'sd5000, 16'sd32767, 16'sd0, 1, 0);

        // 3. Multiply by -1.0 (-32768)
        drive_and_check("by_neg1", 16'sd10000, 16'sd5000, -16'sd32768, 16'sd0, 1, 0);

        // 4. Multiply by j (tw = 0 + j*32767)
        drive_and_check("by_j", 16'sd10000, 16'sd5000, 16'sd0, 16'sd32767, 1, 0);

        // 5. Multiply by -j (tw = 0 - j*32768)
        drive_and_check("by_neg_j", 16'sd10000, 16'sd5000, 16'sd0, -16'sd32768, 1, 0);

        // 6. Safe-range values
        drive_and_check("safe_1", 16'sd8000, -16'sd6000, 16'sd20000, 16'sd15000, 1, 0);

        // 7. Another safe-range
        drive_and_check("safe_2", -16'sd12000, 16'sd9000, -16'sd18000, 16'sd11000, 1, 0);

        // 8. Both zero
        drive_and_check("zero", 16'sd0, 16'sd0, 16'sd0, 16'sd0, 1, 0);

        // 9. Pure imaginary × pure imaginary
        drive_and_check("imag_x_imag", 16'sd0, 16'sd16384, 16'sd0, 16'sd16384, 1, 0);

        // 10. Negative small
        drive_and_check("neg_small", -16'sd100, -16'sd200, 16'sd300, -16'sd400, 1, 0);

        // Flush: check the last result
        drive_and_check("flush", 16'sd0, 16'sd0, 16'sd32767, 16'sd0, 0, 0);

        // --- Summary ---
        $display("\n=== complex_multiplier_q15: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
        if (fail_cnt > 0) $fatal(1, "FAIL");
        else $display("PASS");
        $finish;
    end

endmodule
