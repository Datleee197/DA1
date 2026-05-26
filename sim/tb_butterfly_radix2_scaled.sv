// tb_butterfly_radix2_scaled.sv
// Self-checking testbench for butterfly_radix2_scaled.
// Tests: pos+pos, pos+neg, neg+neg, near-boundary Q1.15, small random.

`timescale 1ns/1ps

module tb_butterfly_radix2_scaled;

    parameter int DATA_W = 16;

    logic signed [DATA_W-1:0] a_re, a_im, b_re, b_im;
    logic signed [DATA_W-1:0] y0_re, y0_im, y1_re, y1_im;

    butterfly_radix2_scaled #(.DATA_W(DATA_W)) dut (
        .a_re(a_re), .a_im(a_im),
        .b_re(b_re), .b_im(b_im),
        .y0_re(y0_re), .y0_im(y0_im),
        .y1_re(y1_re), .y1_im(y1_im)
    );

    int pass_cnt = 0;
    int fail_cnt = 0;

    // Reference model: sign-extend to 17 bits, add/sub, arithmetic shift right 1,
    // then take lower DATA_W bits.
    function automatic signed [DATA_W-1:0] ref_scaled_sum(
        input signed [DATA_W-1:0] a,
        input signed [DATA_W-1:0] b
    );
        logic signed [DATA_W:0] ext_a, ext_b, s;
        ext_a = {a[DATA_W-1], a};
        ext_b = {b[DATA_W-1], b};
        s = ext_a + ext_b;
        ref_scaled_sum = (s >>> 1);
    endfunction

    function automatic signed [DATA_W-1:0] ref_scaled_diff(
        input signed [DATA_W-1:0] a,
        input signed [DATA_W-1:0] b
    );
        logic signed [DATA_W:0] ext_a, ext_b, d;
        ext_a = {a[DATA_W-1], a};
        ext_b = {b[DATA_W-1], b};
        d = ext_a - ext_b;
        ref_scaled_diff = (d >>> 1);
    endfunction

    task automatic check(input string label);
        logic signed [DATA_W-1:0] ey0_re, ey0_im, ey1_re, ey1_im;
        #1;
        ey0_re = ref_scaled_sum(a_re, b_re);
        ey0_im = ref_scaled_sum(a_im, b_im);
        ey1_re = ref_scaled_diff(a_re, b_re);
        ey1_im = ref_scaled_diff(a_im, b_im);

        if (y0_re !== ey0_re || y0_im !== ey0_im ||
            y1_re !== ey1_re || y1_im !== ey1_im) begin
            $display("FAIL %s: a=(%0d,%0d) b=(%0d,%0d)", label, a_re, a_im, b_re, b_im);
            $display("  y0 exp=(%0d,%0d) got=(%0d,%0d)", ey0_re, ey0_im, y0_re, y0_im);
            $display("  y1 exp=(%0d,%0d) got=(%0d,%0d)", ey1_re, ey1_im, y1_re, y1_im);
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("OK   %s: a=(%0d,%0d) b=(%0d,%0d) y0=(%0d,%0d) y1=(%0d,%0d)",
                     label, a_re, a_im, b_re, b_im, y0_re, y0_im, y1_re, y1_im);
            pass_cnt = pass_cnt + 1;
        end
    endtask

    initial begin
        // 1. pos + pos
        a_re = 16'sd1000;  a_im = 16'sd2000;
        b_re = 16'sd3000;  b_im = 16'sd4000;
        check("pos_pos");

        // 2. pos + neg
        a_re = 16'sd5000;  a_im = -16'sd3000;
        b_re = -16'sd2000; b_im = 16'sd1000;
        check("pos_neg");

        // 3. neg + neg
        a_re = -16'sd6000; a_im = -16'sd7000;
        b_re = -16'sd8000; b_im = -16'sd9000;
        check("neg_neg");

        // 4. Near Q1.15 positive boundary (32767)
        a_re = 16'sd32767; a_im = 16'sd32767;
        b_re = 16'sd32766; b_im = 16'sd32766;
        check("near_max");

        // 5. Near Q1.15 negative boundary (avoid -32768 sign flip)
        a_re = -16'sd32767; a_im = -16'sd32767;
        b_re = -16'sd32766; b_im = -16'sd32766;
        check("near_min");

        // 6. Zero inputs
        a_re = 16'sd0; a_im = 16'sd0;
        b_re = 16'sd0; b_im = 16'sd0;
        check("zero");

        // 7. Small positive
        a_re = 16'sd1; a_im = 16'sd1;
        b_re = 16'sd1; b_im = 16'sd1;
        check("small_pos");

        // 8. Odd sum (truncation test: (3+2)>>>1 = 2)
        a_re = 16'sd3; a_im = 16'sd5;
        b_re = 16'sd2; b_im = 16'sd4;
        check("odd_sum");

        // 9. Mixed large values
        a_re = 16'sd16384; a_im = -16'sd16384;
        b_re = -16'sd16384; b_im = 16'sd16384;
        check("mixed_large");

        // 10. Random small amplitude
        a_re = 16'sd123;  a_im = -16'sd456;
        b_re = -16'sd789; b_im = 16'sd101;
        check("random_small");

        // --- Summary ---
        $display("\n=== butterfly_radix2_scaled: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
        if (fail_cnt > 0) $fatal(1, "FAIL");
        else $display("PASS");
        $finish;
    end

endmodule
