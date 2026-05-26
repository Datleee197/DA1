// tb_trivial_rotator.sv
// Self-checking testbench for trivial_rotator.
// Tests all 4 rot_sel values with 4 signed vectors.

`timescale 1ns/1ps

module tb_trivial_rotator;

    parameter int DATA_W = 16;

    logic [1:0]               rot_sel;
    logic signed [DATA_W-1:0] in_re, in_im;
    logic signed [DATA_W-1:0] out_re, out_im;

    trivial_rotator #(.DATA_W(DATA_W)) dut (
        .rot_sel (rot_sel),
        .in_re   (in_re),
        .in_im   (in_im),
        .out_re  (out_re),
        .out_im  (out_im)
    );

    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check(
        input string label,
        input signed [DATA_W-1:0] exp_re,
        input signed [DATA_W-1:0] exp_im
    );
        #1;
        if (out_re !== exp_re || out_im !== exp_im) begin
            $display("FAIL %s: rot=%0d in=(%0d,%0d) exp=(%0d,%0d) got=(%0d,%0d)",
                     label, rot_sel, in_re, in_im, exp_re, exp_im, out_re, out_im);
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("OK   %s: rot=%0d (%0d,%0d)->(%0d,%0d)",
                     label, rot_sel, in_re, in_im, out_re, out_im);
            pass_cnt = pass_cnt + 1;
        end
    endtask

    initial begin
        // --- Vector 1: 1 + j2 ---
        in_re = 16'sd1; in_im = 16'sd2;
        rot_sel = 0; check("v1r0",  16'sd1,   16'sd2);
        rot_sel = 1; check("v1r1",  16'sd2,  -16'sd1);
        rot_sel = 2; check("v1r2", -16'sd1,  -16'sd2);
        rot_sel = 3; check("v1r3", -16'sd2,   16'sd1);

        // --- Vector 2: -3 + j4 ---
        in_re = -16'sd3; in_im = 16'sd4;
        rot_sel = 0; check("v2r0", -16'sd3,   16'sd4);
        rot_sel = 1; check("v2r1",  16'sd4,   16'sd3);
        rot_sel = 2; check("v2r2",  16'sd3,  -16'sd4);
        rot_sel = 3; check("v2r3", -16'sd4,  -16'sd3);

        // --- Vector 3: 1000 - j2000 ---
        in_re = 16'sd1000; in_im = -16'sd2000;
        rot_sel = 0; check("v3r0",  16'sd1000, -16'sd2000);
        rot_sel = 1; check("v3r1", -16'sd2000, -16'sd1000);
        rot_sel = 2; check("v3r2", -16'sd1000,  16'sd2000);
        rot_sel = 3; check("v3r3",  16'sd2000,  16'sd1000);

        // --- Vector 4: -12000 - j7000 ---
        in_re = -16'sd12000; in_im = -16'sd7000;
        rot_sel = 0; check("v4r0", -16'sd12000, -16'sd7000);
        rot_sel = 1; check("v4r1", -16'sd7000,   16'sd12000);
        rot_sel = 2; check("v4r2",  16'sd12000,  16'sd7000);
        rot_sel = 3; check("v4r3",  16'sd7000,  -16'sd12000);

        // --- Summary ---
        $display("\n=== trivial_rotator: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
        if (fail_cnt > 0) $fatal(1, "FAIL");
        else $display("PASS");
        $finish;
    end

endmodule
