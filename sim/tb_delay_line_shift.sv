// tb_delay_line_shift.sv
// Self-checking testbench for delay_line_shift.
// Tests DELAY = 1, 2, 4, 8 with counter data.
// Verifies data, valid_out, and sync_out appear exactly DELAY clocks later.

`timescale 1ns/1ps

module tb_delay_line_shift;

    parameter int DATA_W   = 16;
    parameter int MAX_D    = 8;
    parameter int NUM_SAMP = 20;
    parameter int TOTAL_CYC = NUM_SAMP + MAX_D + 2;

    logic                      clk, rst_n;
    logic                      valid_in, sync_in;
    logic signed [DATA_W-1:0]  din_re, din_im;

    // --- DUT instances ---
    logic valid_out_1, sync_out_1;
    logic signed [DATA_W-1:0] dout_re_1, dout_im_1;
    delay_line_shift #(.DATA_W(DATA_W), .DELAY(1)) dut_d1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .sync_in(sync_in),
        .din_re(din_re), .din_im(din_im),
        .valid_out(valid_out_1), .sync_out(sync_out_1),
        .dout_re(dout_re_1), .dout_im(dout_im_1)
    );

    logic valid_out_2, sync_out_2;
    logic signed [DATA_W-1:0] dout_re_2, dout_im_2;
    delay_line_shift #(.DATA_W(DATA_W), .DELAY(2)) dut_d2 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .sync_in(sync_in),
        .din_re(din_re), .din_im(din_im),
        .valid_out(valid_out_2), .sync_out(sync_out_2),
        .dout_re(dout_re_2), .dout_im(dout_im_2)
    );

    logic valid_out_4, sync_out_4;
    logic signed [DATA_W-1:0] dout_re_4, dout_im_4;
    delay_line_shift #(.DATA_W(DATA_W), .DELAY(4)) dut_d4 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .sync_in(sync_in),
        .din_re(din_re), .din_im(din_im),
        .valid_out(valid_out_4), .sync_out(sync_out_4),
        .dout_re(dout_re_4), .dout_im(dout_im_4)
    );

    logic valid_out_8, sync_out_8;
    logic signed [DATA_W-1:0] dout_re_8, dout_im_8;
    delay_line_shift #(.DATA_W(DATA_W), .DELAY(8)) dut_d8 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .sync_in(sync_in),
        .din_re(din_re), .din_im(din_im),
        .valid_out(valid_out_8), .sync_out(sync_out_8),
        .dout_re(dout_re_8), .dout_im(dout_im_8)
    );

    // Clock: 10 ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Input history — index = clock cycle relative to first drive
    // We record what was driven at the negedge before each posedge.
    logic signed [DATA_W-1:0] hist_re  [0:TOTAL_CYC-1];
    logic signed [DATA_W-1:0] hist_im  [0:TOTAL_CYC-1];
    logic                     hist_v   [0:TOTAL_CYC-1];
    logic                     hist_s   [0:TOTAL_CYC-1];

    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check_one(
        input int D,
        input int cyc,
        input signed [DATA_W-1:0] dout_re_d,
        input signed [DATA_W-1:0] dout_im_d,
        input logic vout, sout
    );
        logic signed [DATA_W-1:0] exp_re, exp_im;
        logic exp_v, exp_s;
        int src;
        // Output at cycle 'cyc' should match input from cycle 'cyc - D'
        src = cyc - D;
        if (src < 0) begin
            exp_re = 0; exp_im = 0; exp_v = 0; exp_s = 0;
        end else begin
            exp_re = hist_re[src];
            exp_im = hist_im[src];
            exp_v  = hist_v[src];
            exp_s  = hist_s[src];
        end
        if (dout_re_d !== exp_re || dout_im_d !== exp_im ||
            vout !== exp_v || sout !== exp_s) begin
            $display("FAIL D=%0d cyc=%0d: exp=(%0d,%0d,v=%b,s=%b) got=(%0d,%0d,v=%b,s=%b)",
                     D, cyc, exp_re, exp_im, exp_v, exp_s,
                     dout_re_d, dout_im_d, vout, sout);
            fail_cnt = fail_cnt + 1;
        end else begin
            pass_cnt = pass_cnt + 1;
        end
    endtask

    integer k;
    int cycle;

    initial begin
        // Init
        for (k = 0; k < TOTAL_CYC; k = k + 1) begin
            hist_re[k] = 0; hist_im[k] = 0;
            hist_v[k] = 0; hist_s[k] = 0;
        end

        rst_n = 0; valid_in = 0; sync_in = 0;
        din_re = 0; din_im = 0;
        @(posedge clk); @(posedge clk);
        rst_n = 1;

        // Drive NUM_SAMP samples, then drive zeros for MAX_D more cycles to flush
        for (cycle = 0; cycle < NUM_SAMP + MAX_D; cycle = cycle + 1) begin
            // Drive inputs at negedge (setup time before posedge)
            @(negedge clk);
            if (cycle < NUM_SAMP) begin
                din_re   = 16'(cycle + 1);
                din_im   = 16'(-(cycle + 1));
                valid_in = 1'b1;
                sync_in  = (cycle == 0) ? 1'b1 : 1'b0;
            end else begin
                din_re   = 16'sd0;
                din_im   = 16'sd0;
                valid_in = 1'b0;
                sync_in  = 1'b0;
            end

            // Record what we're driving (will be latched at next posedge)
            hist_re[cycle] = din_re;
            hist_im[cycle] = din_im;
            hist_v[cycle]  = valid_in;
            hist_s[cycle]  = sync_in;

            // Wait for posedge (shift register latches) then check output
            @(posedge clk); #1;

            // The output now reflects data latched at THIS posedge.
            // For DELAY=D, the output should be what was driven D cycles ago.
            // At this posedge, cycle N's input is being latched.
            // The output is from cycle (N - D)'s input that was latched D edges ago.
            // But since the register latches on posedge and output reads combinationally
            // from the last register, after posedge #1 the output equals input[cycle-D].
            // However at cycle < D, the delay line was reset to 0.
            check_one(1, cycle, dout_re_1, dout_im_1, valid_out_1, sync_out_1);
            check_one(2, cycle, dout_re_2, dout_im_2, valid_out_2, sync_out_2);
            check_one(4, cycle, dout_re_4, dout_im_4, valid_out_4, sync_out_4);
            check_one(8, cycle, dout_re_8, dout_im_8, valid_out_8, sync_out_8);
        end

        $display("\n=== delay_line_shift: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
        if (fail_cnt > 0) $fatal(1, "FAIL");
        else $display("PASS");
        $finish;
    end

endmodule
