// tb_sdf_bf2ii_stage.sv
// Self-checking testbench for sdf_bf2ii_stage with DELAY = 4.
// Drives din_re = 10*(n+1), din_im = 5*(n+1).
// Tests all 4 rot_sel values during fill phase cycles 8-11.
// Compares cycle-by-cycle against the manual timing table.
// Generates VCD.  Prints PASS only if all checks pass.

`timescale 1ns/1ps

module tb_sdf_bf2ii_stage;

    localparam int DATA_W     = 16;
    localparam int DELAY      = 4;
    localparam int NUM_CYCLES = 16;

    // DUT signals
    logic                      clk, rst_n;
    logic                      valid_in, sync_in, phase_sel;
    logic [1:0]                rot_sel;
    logic signed [DATA_W-1:0]  din_re, din_im;
    logic                      valid_out, sync_out;
    logic signed [DATA_W-1:0]  dout_re, dout_im;

    sdf_bf2ii_stage #(.DATA_W(DATA_W), .DELAY(DELAY)) dut (.*);

    // Clock — 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Expected values from the manual timing table
    //
    // din_re = 10*(c+1), din_im = 5*(c+1)
    // rot_sel: fill phases use {0,1,2,3}, compute phases use 0
    //
    // Rotator applied during fill (phase_sel=0) on delay_out:
    //   rot=0: (re, im)     rot=1: (im, -re)
    //   rot=2: (-re, -im)   rot=3: (-im, re)
    //
    // Cycles 0-3: fill, delay_out=(0,0), dout=(0,0) regardless of rot
    // Cycles 4-7: compute, dout=y0
    // Cycles 8-11: fill, delay_out=(-20,-10), rotated output
    // Cycles 12-15: compute, dout=y0
    // ------------------------------------------------------------------

    logic signed [DATA_W-1:0] exp_re [0:NUM_CYCLES-1];
    logic signed [DATA_W-1:0] exp_im [0:NUM_CYCLES-1];
    logic                     exp_v  [0:NUM_CYCLES-1];
    logic                     exp_s  [0:NUM_CYCLES-1];

    // phase_sel pattern: 0 for cnt[2]==0, 1 for cnt[2]==1
    logic [2:0] tb_cnt;

    // rot_sel pattern per cycle
    logic [1:0] rot_pattern [0:NUM_CYCLES-1];

    initial begin
        // rot_sel: fill phases cycle through 0,1,2,3; compute phases = 0
        rot_pattern[ 0] = 0; rot_pattern[ 1] = 1;
        rot_pattern[ 2] = 2; rot_pattern[ 3] = 3;
        rot_pattern[ 4] = 0; rot_pattern[ 5] = 0;
        rot_pattern[ 6] = 0; rot_pattern[ 7] = 0;
        rot_pattern[ 8] = 0; rot_pattern[ 9] = 1;
        rot_pattern[10] = 2; rot_pattern[11] = 3;
        rot_pattern[12] = 0; rot_pattern[13] = 0;
        rot_pattern[14] = 0; rot_pattern[15] = 0;

        // Expected dout_re
        exp_re[ 0] =   0;  exp_im[ 0] =   0;   // fill, delay_out=0, rot=0
        exp_re[ 1] =   0;  exp_im[ 1] =   0;   // fill, delay_out=0, rot=1
        exp_re[ 2] =   0;  exp_im[ 2] =   0;   // fill, delay_out=0, rot=2
        exp_re[ 3] =   0;  exp_im[ 3] =   0;   // fill, delay_out=0, rot=3
        exp_re[ 4] =  30;  exp_im[ 4] =  15;   // compute: y0=(10+50)/2, (5+25)/2
        exp_re[ 5] =  40;  exp_im[ 5] =  20;   // compute: y0=(20+60)/2, (10+30)/2
        exp_re[ 6] =  50;  exp_im[ 6] =  25;   // compute: y0=(30+70)/2, (15+35)/2
        exp_re[ 7] =  60;  exp_im[ 7] =  30;   // compute: y0=(40+80)/2, (20+40)/2
        exp_re[ 8] = -20;  exp_im[ 8] = -10;   // fill, dly=(-20,-10), rot=0: (-20,-10)
        exp_re[ 9] = -10;  exp_im[ 9] =  20;   // fill, dly=(-20,-10), rot=1: (im,-re)=(-10,20)
        exp_re[10] =  20;  exp_im[10] =  10;   // fill, dly=(-20,-10), rot=2: (-re,-im)=(20,10)
        exp_re[11] =  10;  exp_im[11] = -20;   // fill, dly=(-20,-10), rot=3: (-im,re)=(10,-20)
        exp_re[12] = 110;  exp_im[12] =  55;   // compute: y0=(90+130)/2, (45+65)/2
        exp_re[13] = 120;  exp_im[13] =  60;   // compute: y0=(100+140)/2, (50+70)/2
        exp_re[14] = 130;  exp_im[14] =  65;   // compute: y0=(110+150)/2, (55+75)/2
        exp_re[15] = 140;  exp_im[15] =  70;   // compute: y0=(120+160)/2, (60+80)/2

        // valid_out / sync_out
        for (int k = 0; k < NUM_CYCLES; k++) begin
            exp_v[k] = (k >= DELAY) ? 1 : 0;
            exp_s[k] = (k == DELAY) ? 1 : 0;
        end
    end

    // VCD
    initial begin
        $dumpfile("tb_sdf_bf2ii_stage.vcd");
        $dumpvars(0, tb_sdf_bf2ii_stage);
    end

    // ------------------------------------------------------------------
    // Stimulus & checking
    // Timing: set inputs → #1 settle → check → @(posedge clk)
    // ------------------------------------------------------------------
    integer cycle, errors;

    initial begin
        rst_n = 0; valid_in = 0; sync_in = 0;
        phase_sel = 0; rot_sel = 0;
        din_re = 0; din_im = 0;
        tb_cnt = 0; errors = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (cycle = 0; cycle < NUM_CYCLES; cycle = cycle + 1) begin
            // Set inputs
            valid_in  = 1;
            sync_in   = (cycle == 0) ? 1 : 0;
            din_re    = 16'(10 * (cycle + 1));
            din_im    = 16'( 5 * (cycle + 1));
            phase_sel = tb_cnt[2];
            rot_sel   = rot_pattern[cycle];

            #1;  // settle

            // Check
            if (dout_re !== exp_re[cycle]) begin
                $display("FAIL cyc %0d: dout_re=%0d exp=%0d", cycle, dout_re, exp_re[cycle]);
                errors = errors + 1;
            end
            if (dout_im !== exp_im[cycle]) begin
                $display("FAIL cyc %0d: dout_im=%0d exp=%0d", cycle, dout_im, exp_im[cycle]);
                errors = errors + 1;
            end
            if (valid_out !== exp_v[cycle]) begin
                $display("FAIL cyc %0d: valid_out=%0d exp=%0d", cycle, valid_out, exp_v[cycle]);
                errors = errors + 1;
            end
            if (sync_out !== exp_s[cycle]) begin
                $display("FAIL cyc %0d: sync_out=%0d exp=%0d", cycle, sync_out, exp_s[cycle]);
                errors = errors + 1;
            end

            $display("cyc %2d: ph=%0d rot=%0d din=(%4d,%4d) dout=(%4d,%4d) v=%0d s=%0d | exp=(%4d,%4d) v=%0d s=%0d %s",
                     cycle, phase_sel, rot_sel, din_re, din_im,
                     dout_re, dout_im, valid_out, sync_out,
                     exp_re[cycle], exp_im[cycle], exp_v[cycle], exp_s[cycle],
                     (dout_re===exp_re[cycle] && dout_im===exp_im[cycle] &&
                      valid_out===exp_v[cycle] && sync_out===exp_s[cycle]) ? "OK" : "MISMATCH");

            @(posedge clk);
            tb_cnt = tb_cnt + 1;
        end

        $display("");
        if (errors == 0)
            $display("=== PASS === All %0d cycle checks passed.", NUM_CYCLES);
        else
            $display("=== FAIL === %0d errors in %0d cycles.", errors, NUM_CYCLES);

        #20; $finish;
    end

endmodule
