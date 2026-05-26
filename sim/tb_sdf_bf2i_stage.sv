// tb_sdf_bf2i_stage.sv
// Self-checking testbench for sdf_bf2i_stage with DELAY = 4.
// Drives din_re = 10*(n+1), din_im = 0.
// phase_sel from local counter: 0 for cnt[2]==0, 1 for cnt[2]==1.
// Checks cycle-by-cycle against the manual timing table.
// Generates VCD.  Prints PASS only if all checks pass.

`timescale 1ns/1ps

module tb_sdf_bf2i_stage;

    localparam int DATA_W     = 16;
    localparam int DELAY      = 4;
    localparam int NUM_CYCLES = 16;

    // DUT signals
    logic                      clk, rst_n;
    logic                      valid_in, sync_in, phase_sel;
    logic signed [DATA_W-1:0]  din_re, din_im;
    logic                      valid_out, sync_out;
    logic signed [DATA_W-1:0]  dout_re, dout_im;

    sdf_bf2i_stage #(.DATA_W(DATA_W), .DELAY(DELAY)) dut (.*);

    // Clock — 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Expected values from the manual timing table (DELAY = 4)
    //
    // din_re = 10*(cycle+1), din_im = 0
    //
    // Cyc|ph|din | dly_out|BF?| a  | b  | y0 | y1 |dly_wr|fwd |v|s
    //  0 | 0| 10 |   0   | N | —  | —  | —  | —  |  10  |  0 |0|0
    //  1 | 0| 20 |   0   | N | —  | —  | —  | —  |  20  |  0 |0|0
    //  2 | 0| 30 |   0   | N | —  | —  | —  | —  |  30  |  0 |0|0
    //  3 | 0| 40 |   0   | N | —  | —  | —  | —  |  40  |  0 |0|0
    //  4 | 1| 50 |  10   | Y | 10 | 50 | 30 |-20 | -20  | 30 |1|1
    //  5 | 1| 60 |  20   | Y | 20 | 60 | 40 |-20 | -20  | 40 |1|0
    //  6 | 1| 70 |  30   | Y | 30 | 70 | 50 |-20 | -20  | 50 |1|0
    //  7 | 1| 80 |  40   | Y | 40 | 80 | 60 |-20 | -20  | 60 |1|0
    //  8 | 0| 90 | -20   | N | —  | —  | —  | —  |  90  |-20 |1|0
    //  9 | 0|100 | -20   | N | —  | —  | —  | —  | 100  |-20 |1|0
    // 10 | 0|110 | -20   | N | —  | —  | —  | —  | 110  |-20 |1|0
    // 11 | 0|120 | -20   | N | —  | —  | —  | —  | 120  |-20 |1|0
    // 12 | 1|130 |  90   | Y | 90 |130 |110 |-20 | -20  |110 |1|0
    // 13 | 1|140 | 100   | Y |100 |140 |120 |-20 | -20  |120 |1|0
    // 14 | 1|150 | 110   | Y |110 |150 |130 |-20 | -20  |130 |1|0
    // 15 | 1|160 | 120   | Y |120 |160 |140 |-20 | -20  |140 |1|0
    // ------------------------------------------------------------------

    logic signed [DATA_W-1:0] exp_re [0:NUM_CYCLES-1];
    logic                     exp_v  [0:NUM_CYCLES-1];
    logic                     exp_s  [0:NUM_CYCLES-1];

    initial begin
        exp_re[ 0]=  0; exp_re[ 1]=  0; exp_re[ 2]=  0; exp_re[ 3]=  0;
        exp_re[ 4]= 30; exp_re[ 5]= 40; exp_re[ 6]= 50; exp_re[ 7]= 60;
        exp_re[ 8]=-20; exp_re[ 9]=-20; exp_re[10]=-20; exp_re[11]=-20;
        exp_re[12]=110; exp_re[13]=120; exp_re[14]=130; exp_re[15]=140;
        for (int k = 0; k < NUM_CYCLES; k++) begin
            exp_v[k] = (k >= DELAY) ? 1 : 0;
            exp_s[k] = (k == DELAY) ? 1 : 0;
        end
    end

    // VCD
    initial begin
        $dumpfile("tb_sdf_bf2i_stage.vcd");
        $dumpvars(0, tb_sdf_bf2i_stage);
    end

    // ------------------------------------------------------------------
    // Stimulus & checking
    //
    // Timing: set inputs → #1 settle → check combinational outputs →
    //         @(posedge clk) to advance registers.
    // This way the combinational outputs (dout, valid_out, sync_out)
    // reflect the current SR state and current inputs, with no
    // registered-output skew.
    // ------------------------------------------------------------------
    integer cycle, errors;
    logic [2:0] tb_cnt;

    initial begin
        rst_n = 0; valid_in = 0; sync_in = 0;
        phase_sel = 0; din_re = 0; din_im = 0;
        tb_cnt = 0; errors = 0;

        // Reset
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);  // one clean cycle after reset

        for (cycle = 0; cycle < NUM_CYCLES; cycle = cycle + 1) begin
            // --- Set inputs (combinational, before next posedge) ---
            valid_in  = 1;
            sync_in   = (cycle == 0) ? 1 : 0;
            din_re    = 16'(10 * (cycle + 1));
            din_im    = 16'd0;
            phase_sel = tb_cnt[2];

            #1;  // let combinational outputs settle

            // --- Check outputs ---
            if (dout_re !== exp_re[cycle]) begin
                $display("FAIL cyc %0d: dout_re=%0d exp=%0d", cycle, dout_re, exp_re[cycle]);
                errors = errors + 1;
            end
            if (dout_im !== 16'sd0) begin
                $display("FAIL cyc %0d: dout_im=%0d exp=0", cycle, dout_im);
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

            $display("cyc %2d: ph=%0d din=%4d dout=%4d v=%0d s=%0d | exp=%4d v=%0d s=%0d %s",
                     cycle, phase_sel, din_re, dout_re, valid_out, sync_out,
                     exp_re[cycle], exp_v[cycle], exp_s[cycle],
                     (dout_re===exp_re[cycle] && dout_im===16'sd0 &&
                      valid_out===exp_v[cycle] && sync_out===exp_s[cycle]) ? "OK" : "MISMATCH");

            // --- Advance clock (registers update) ---
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
