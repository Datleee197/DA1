// tb_sdf_feedback_delay.sv
// Self-checking testbench for sdf_feedback_delay.
// Tests DELAY = 1, 2, 4, 8.
// Prints PASS only if all checks pass.

`timescale 1ns/1ps

module tb_sdf_feedback_delay;

    localparam int DATA_W = 16;
    localparam int MAX_CYC = 20; // enough for DELAY=8 + extra

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    logic rst_n;
    integer total_errors;

    // ----------------------------------------------------------------
    // DUT instances
    // ----------------------------------------------------------------
    logic en1, en2, en4, en8;
    logic signed [DATA_W-1:0] d1i_re, d1i_im, d1o_re, d1o_im;
    logic signed [DATA_W-1:0] d2i_re, d2i_im, d2o_re, d2o_im;
    logic signed [DATA_W-1:0] d4i_re, d4i_im, d4o_re, d4o_im;
    logic signed [DATA_W-1:0] d8i_re, d8i_im, d8o_re, d8o_im;

    sdf_feedback_delay #(.DATA_W(DATA_W), .DELAY(1)) u1 (
        .clk(clk),.rst_n(rst_n),.en(en1),
        .din_re(d1i_re),.din_im(d1i_im),.dout_re(d1o_re),.dout_im(d1o_im));
    sdf_feedback_delay #(.DATA_W(DATA_W), .DELAY(2)) u2 (
        .clk(clk),.rst_n(rst_n),.en(en2),
        .din_re(d2i_re),.din_im(d2i_im),.dout_re(d2o_re),.dout_im(d2o_im));
    sdf_feedback_delay #(.DATA_W(DATA_W), .DELAY(4)) u4 (
        .clk(clk),.rst_n(rst_n),.en(en4),
        .din_re(d4i_re),.din_im(d4i_im),.dout_re(d4o_re),.dout_im(d4o_im));
    sdf_feedback_delay #(.DATA_W(DATA_W), .DELAY(8)) u8 (
        .clk(clk),.rst_n(rst_n),.en(en8),
        .din_re(d8i_re),.din_im(d8i_im),.dout_re(d8o_re),.dout_im(d8o_im));

    // VCD
    initial begin
        $dumpfile("tb_sdf_feedback_delay.vcd");
        $dumpvars(0, tb_sdf_feedback_delay);
    end

    // ----------------------------------------------------------------
    // Helper: expected output for cycle c with DELAY = D.
    //
    // With D SR stages and combinational output, the standalone latency
    // in this timing model (set inputs → #1 → check → posedge) is
    // D-1 clock cycles.  Data set during cycle c is latched at posedge,
    // propagates through D-1 more posedges, and appears at sr[D-1]
    // starting from cycle c + D - 1.
    //
    // In the SDF feedback loop the effective delay is D cycles because
    // the combinational write-to-read path adds the Dth cycle.
    //
    // Input at cycle c:  re = 10*(c+1),  im = -(5*(c+1)).
    // Standalone output at cycle c: input from cycle c-(D-1), or 0 if
    // c < D-1.
    // ----------------------------------------------------------------
    function automatic logic signed [DATA_W-1:0] exp_re(input int c, input int D);
        int eff;
        eff = D - 1;  // standalone latency
        if (c < eff) return 16'sd0;
        else         return 16'(10 * (c - eff + 1));
    endfunction

    function automatic logic signed [DATA_W-1:0] exp_im(input int c, input int D);
        int eff;
        eff = D - 1;
        if (c < eff) return 16'sd0;
        else         return 16'(-(5 * (c - eff + 1)));
    endfunction

    // ----------------------------------------------------------------
    // Main test
    // ----------------------------------------------------------------
    integer c, errs;
    logic signed [DATA_W-1:0] hold_re, hold_im;

    initial begin
        rst_n = 0;
        en1=0; en2=0; en4=0; en8=0;
        d1i_re=0; d1i_im=0; d2i_re=0; d2i_im=0;
        d4i_re=0; d4i_im=0; d8i_re=0; d8i_im=0;
        total_errors = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ============================================================
        // Test DELAY = 1
        // ============================================================
        $display("--- DELAY=1 ---");
        errs = 0;
        for (c = 0; c < 10; c = c + 1) begin
            en1 = 1;
            d1i_re = 16'(10 * (c + 1));
            d1i_im = 16'(-(5 * (c + 1)));
            #1;
            if (d1o_re !== exp_re(c,1) || d1o_im !== exp_im(c,1)) begin
                $display("  FAIL D=1 c=%0d: got(%0d,%0d) exp(%0d,%0d)",
                    c, d1o_re, d1o_im, exp_re(c,1), exp_im(c,1));
                errs = errs + 1;
            end
            @(posedge clk);
        end
        // en=0 hold test
        en1 = 0; d1i_re = 16'h7FFF; d1i_im = 16'h7FFF;
        #1; hold_re = d1o_re; hold_im = d1o_im; @(posedge clk);
        en1 = 0; #1;
        if (d1o_re !== hold_re || d1o_im !== hold_im) begin
            $display("  FAIL D=1 en=0 hold"); errs = errs + 1;
        end
        @(posedge clk);
        total_errors = total_errors + errs;
        if (errs == 0) $display("  DELAY=1: passed.");
        else           $display("  DELAY=1: %0d errors.", errs);

        // ============================================================
        // Test DELAY = 2
        // ============================================================
        $display("--- DELAY=2 ---");
        errs = 0;
        for (c = 0; c < 12; c = c + 1) begin
            en2 = 1;
            d2i_re = 16'(10 * (c + 1));
            d2i_im = 16'(-(5 * (c + 1)));
            #1;
            if (d2o_re !== exp_re(c,2) || d2o_im !== exp_im(c,2)) begin
                $display("  FAIL D=2 c=%0d: got(%0d,%0d) exp(%0d,%0d)",
                    c, d2o_re, d2o_im, exp_re(c,2), exp_im(c,2));
                errs = errs + 1;
            end
            @(posedge clk);
        end
        en2 = 0; d2i_re = 16'h7FFF; d2i_im = 16'h7FFF;
        #1; hold_re = d2o_re; hold_im = d2o_im; @(posedge clk);
        en2 = 0; #1;
        if (d2o_re !== hold_re || d2o_im !== hold_im) begin
            $display("  FAIL D=2 en=0 hold"); errs = errs + 1;
        end
        @(posedge clk);
        total_errors = total_errors + errs;
        if (errs == 0) $display("  DELAY=2: passed.");
        else           $display("  DELAY=2: %0d errors.", errs);

        // ============================================================
        // Test DELAY = 4
        // ============================================================
        $display("--- DELAY=4 ---");
        errs = 0;
        for (c = 0; c < 14; c = c + 1) begin
            en4 = 1;
            d4i_re = 16'(10 * (c + 1));
            d4i_im = 16'(-(5 * (c + 1)));
            #1;
            if (d4o_re !== exp_re(c,4) || d4o_im !== exp_im(c,4)) begin
                $display("  FAIL D=4 c=%0d: got(%0d,%0d) exp(%0d,%0d)",
                    c, d4o_re, d4o_im, exp_re(c,4), exp_im(c,4));
                errs = errs + 1;
            end
            @(posedge clk);
        end
        en4 = 0; d4i_re = 16'h7FFF; d4i_im = 16'h7FFF;
        #1; hold_re = d4o_re; hold_im = d4o_im; @(posedge clk);
        en4 = 0; #1;
        if (d4o_re !== hold_re || d4o_im !== hold_im) begin
            $display("  FAIL D=4 en=0 hold"); errs = errs + 1;
        end
        @(posedge clk);
        total_errors = total_errors + errs;
        if (errs == 0) $display("  DELAY=4: passed.");
        else           $display("  DELAY=4: %0d errors.", errs);

        // ============================================================
        // Test DELAY = 8
        // ============================================================
        $display("--- DELAY=8 ---");
        errs = 0;
        for (c = 0; c < MAX_CYC; c = c + 1) begin
            en8 = 1;
            d8i_re = 16'(10 * (c + 1));
            d8i_im = 16'(-(5 * (c + 1)));
            #1;
            if (d8o_re !== exp_re(c,8) || d8o_im !== exp_im(c,8)) begin
                $display("  FAIL D=8 c=%0d: got(%0d,%0d) exp(%0d,%0d)",
                    c, d8o_re, d8o_im, exp_re(c,8), exp_im(c,8));
                errs = errs + 1;
            end
            @(posedge clk);
        end
        en8 = 0; d8i_re = 16'h7FFF; d8i_im = 16'h7FFF;
        #1; hold_re = d8o_re; hold_im = d8o_im; @(posedge clk);
        en8 = 0; #1;
        if (d8o_re !== hold_re || d8o_im !== hold_im) begin
            $display("  FAIL D=8 en=0 hold"); errs = errs + 1;
        end
        @(posedge clk);
        total_errors = total_errors + errs;
        if (errs == 0) $display("  DELAY=8: passed.");
        else           $display("  DELAY=8: %0d errors.", errs);

        // ============================================================
        // Final
        // ============================================================
        $display("");
        if (total_errors == 0)
            $display("=== PASS === All sdf_feedback_delay tests passed.");
        else
            $display("=== FAIL === %0d total errors.", total_errors);

        #20; $finish;
    end

endmodule
