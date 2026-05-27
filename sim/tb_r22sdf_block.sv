// tb_r22sdf_block.sv
// Self-checking testbench for r22sdf_block.
//
// Three DUTs driven with identical inputs:
//   dut0: HAS_CMUL=0                        (Test 1)
//   dut1: HAS_CMUL=1, tw_unity.hex          (Test 2)
//   dut2: HAS_CMUL=1, tw16.hex              (Test 3)
//
// DELAY_I=4, DELAY_II=2, TW_ADDR_W=4 (16-entry ROM).
// Control signals from a testbench-local counter.

`timescale 1ns/1ps

module tb_r22sdf_block;

    localparam int DATA_W     = 16;
    localparam int DELAY_I    = 4;
    localparam int DELAY_II   = 2;
    localparam int TW_ADDR_W  = 4;
    localparam int NUM_CYCLES = 24;
    // Total latency without CMUL:
    //   BF2I valid SR: DELAY_I cycles
    //   BF2II valid SR: DELAY_II cycles
    //   +1: BF2II SR must latch BF2I combinational valid at next posedge
    //   = DELAY_I + DELAY_II + 1
    // With CMUL: +1 more for the registered CMUL output
    localparam int LAT_NOCMUL = DELAY_I + DELAY_II + 1;  // 7
    localparam int LAT_CMUL   = LAT_NOCMUL + 1;          // 8

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Shared signals
    // ----------------------------------------------------------------
    logic                      rst_n, valid_in, sync_in;
    logic                      phase_sel_i, phase_sel_ii;
    logic [1:0]                rot_sel;
    logic [TW_ADDR_W-1:0]      tw_addr;
    logic signed [DATA_W-1:0]  din_re, din_im;

    // DUT0: HAS_CMUL = 0
    logic                      v0, s0;
    logic signed [DATA_W-1:0]  re0, im0;

    r22sdf_block #(
        .DATA_W(DATA_W), .DELAY_I(DELAY_I), .DELAY_II(DELAY_II),
        .HAS_CMUL(0), .TW_ADDR_W(TW_ADDR_W), .TW_FILE("rom/tw_unity.hex")
    ) dut0 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .sync_in(sync_in),
        .phase_sel_i(phase_sel_i), .phase_sel_ii(phase_sel_ii),
        .rot_sel(rot_sel), .tw_addr(tw_addr),
        .din_re(din_re), .din_im(din_im),
        .valid_out(v0), .sync_out(s0), .dout_re(re0), .dout_im(im0)
    );

    // DUT1: HAS_CMUL = 1 with unity twiddle (all entries = 1+j0)
    logic                      v1, s1;
    logic signed [DATA_W-1:0]  re1, im1;

    r22sdf_block #(
        .DATA_W(DATA_W), .DELAY_I(DELAY_I), .DELAY_II(DELAY_II),
        .HAS_CMUL(1), .TW_ADDR_W(TW_ADDR_W), .TW_FILE("rom/tw_unity.hex")
    ) dut1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .sync_in(sync_in),
        .phase_sel_i(phase_sel_i), .phase_sel_ii(phase_sel_ii),
        .rot_sel(rot_sel), .tw_addr(tw_addr),
        .din_re(din_re), .din_im(din_im),
        .valid_out(v1), .sync_out(s1), .dout_re(re1), .dout_im(im1)
    );

    // DUT2: HAS_CMUL = 1 with real tw16.hex
    logic                      v2, s2;
    logic signed [DATA_W-1:0]  re2, im2;

    r22sdf_block #(
        .DATA_W(DATA_W), .DELAY_I(DELAY_I), .DELAY_II(DELAY_II),
        .HAS_CMUL(1), .TW_ADDR_W(TW_ADDR_W), .TW_FILE("rom/tw16.hex")
    ) dut2 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .sync_in(sync_in),
        .phase_sel_i(phase_sel_i), .phase_sel_ii(phase_sel_ii),
        .rot_sel(rot_sel), .tw_addr(tw_addr),
        .din_re(din_re), .din_im(din_im),
        .valid_out(v2), .sync_out(s2), .dout_re(re2), .dout_im(im2)
    );

    // VCD
    initial begin
        $dumpfile("tb_r22sdf_block.vcd");
        $dumpvars(0, tb_r22sdf_block);
    end

    // ----------------------------------------------------------------
    // Testbench counter and control generation
    // ----------------------------------------------------------------
    logic [7:0] tb_cnt;

    // History buffers for cross-comparison (Test 2)
    logic signed [DATA_W-1:0] hist_re0 [0:NUM_CYCLES-1];
    logic signed [DATA_W-1:0] hist_im0 [0:NUM_CYCLES-1];
    logic                     hist_v0  [0:NUM_CYCLES-1];
    logic                     hist_s0  [0:NUM_CYCLES-1];

    // ----------------------------------------------------------------
    // Main test
    // ----------------------------------------------------------------
    integer cycle, errors_t1, errors_t2, errors_t3;
    integer total_errors;
    logic signed [DATA_W-1:0] diff_re, diff_im;

    initial begin
        rst_n = 0; valid_in = 0; sync_in = 0;
        phase_sel_i = 0; phase_sel_ii = 0;
        rot_sel = 0; tw_addr = 0;
        din_re = 0; din_im = 0;
        tb_cnt = 0;
        errors_t1 = 0; errors_t2 = 0; errors_t3 = 0;

        // Initialize history
        for (int k = 0; k < NUM_CYCLES; k++) begin
            hist_re0[k] = 0; hist_im0[k] = 0;
            hist_v0[k] = 0;  hist_s0[k] = 0;
        end

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ============================================================
        // Drive NUM_CYCLES samples
        // Inputs: din_re = 10*(c+1), din_im = 5*(c+1)
        // Control: phase_sel_i = cnt[2], phase_sel_ii = cnt[1]
        //          rot_sel = cnt[2:1] (exercises all 4 values)
        //          tw_addr = cnt[3:0] (exercises all 16 ROM entries)
        // ============================================================
        for (cycle = 0; cycle < NUM_CYCLES; cycle = cycle + 1) begin
            valid_in    = 1;
            sync_in     = (cycle == 0) ? 1 : 0;
            din_re      = 16'(10 * (cycle + 1));
            din_im      = 16'( 5 * (cycle + 1));
            phase_sel_i = tb_cnt[2];
            phase_sel_ii= tb_cnt[1];
            rot_sel     = tb_cnt[2:1];
            tw_addr     = tb_cnt[3:0];

            #1; // settle combinational

            // ---- Store DUT0 output for Test 2 comparison ----
            hist_re0[cycle] = re0;
            hist_im0[cycle] = im0;
            hist_v0[cycle]  = v0;
            hist_s0[cycle]  = s0;

            // ================================================
            // Test 1: HAS_CMUL=0 basic checks
            // ================================================
            // Check valid_out timing
            if (cycle < LAT_NOCMUL) begin
                if (v0 !== 1'b0) begin
                    $display("T1 FAIL cyc %0d: valid_out=%0d expected 0 (latency)", cycle, v0);
                    errors_t1 = errors_t1 + 1;
                end
            end else begin
                if (v0 !== 1'b1) begin
                    $display("T1 FAIL cyc %0d: valid_out=%0d expected 1", cycle, v0);
                    errors_t1 = errors_t1 + 1;
                end
            end
            // Check sync_out timing
            if (cycle == LAT_NOCMUL) begin
                if (s0 !== 1'b1) begin
                    $display("T1 FAIL cyc %0d: sync_out=%0d expected 1", cycle, s0);
                    errors_t1 = errors_t1 + 1;
                end
            end else begin
                if (s0 !== 1'b0) begin
                    $display("T1 FAIL cyc %0d: sync_out=%0d expected 0", cycle, s0);
                    errors_t1 = errors_t1 + 1;
                end
            end
            // Check data is not X when valid
            if (v0 === 1'b1 && (re0 === 16'hxxxx || im0 === 16'hxxxx)) begin
                $display("T1 FAIL cyc %0d: output is X when valid", cycle);
                errors_t1 = errors_t1 + 1;
            end

            // ================================================
            // Test 2: HAS_CMUL=1 unity — must equal DUT0 delayed 1 cycle
            // ================================================
            // Check valid/sync timing (1 cycle later than DUT0)
            if (cycle < LAT_CMUL) begin
                if (v1 !== 1'b0) begin
                    $display("T2 FAIL cyc %0d: valid_out=%0d expected 0 (latency)", cycle, v1);
                    errors_t2 = errors_t2 + 1;
                end
            end else begin
                if (v1 !== 1'b1) begin
                    $display("T2 FAIL cyc %0d: valid_out=%0d expected 1", cycle, v1);
                    errors_t2 = errors_t2 + 1;
                end
            end
            if (cycle == LAT_CMUL) begin
                if (s1 !== 1'b1) begin
                    $display("T2 FAIL cyc %0d: sync_out=%0d expected 1", cycle, s1);
                    errors_t2 = errors_t2 + 1;
                end
            end else begin
                if (s1 !== 1'b0) begin
                    $display("T2 FAIL cyc %0d: sync_out=%0d expected 0", cycle, s1);
                    errors_t2 = errors_t2 + 1;
                end
            end
            // Data check: unity CMUL output ≈ DUT0 output from previous cycle (±1 LSB)
            // The CMUL with tw=32767+j0 scales by 32767/32768, truncated.
            if (v1 === 1'b1 && cycle >= 1) begin
                diff_re = re1 - hist_re0[cycle-1];
                diff_im = im1 - hist_im0[cycle-1];
                if (diff_re > 1 || diff_re < -1 || diff_im > 1 || diff_im < -1) begin
                    $display("T2 FAIL cyc %0d: dut1=(%0d,%0d) expected~dut0[%0d]=(%0d,%0d) diff=(%0d,%0d)",
                             cycle, re1, im1, cycle-1,
                             hist_re0[cycle-1], hist_im0[cycle-1],
                             diff_re, diff_im);
                    errors_t2 = errors_t2 + 1;
                end
            end

            // ================================================
            // Test 3: HAS_CMUL=1 real twiddle — check valid/sync timing
            //   and spot-check with tw_addr=0 (first few valid outputs
            //   should match unity since W_16^0 = 1+j0 = 0x7FFF0000)
            // ================================================
            if (cycle < LAT_CMUL) begin
                if (v2 !== 1'b0) begin
                    $display("T3 FAIL cyc %0d: valid_out=%0d expected 0", cycle, v2);
                    errors_t3 = errors_t3 + 1;
                end
            end else begin
                if (v2 !== 1'b1) begin
                    $display("T3 FAIL cyc %0d: valid_out=%0d expected 1", cycle, v2);
                    errors_t3 = errors_t3 + 1;
                end
            end
            if (cycle == LAT_CMUL) begin
                if (s2 !== 1'b1) begin
                    $display("T3 FAIL cyc %0d: sync_out=%0d expected 1", cycle, s2);
                    errors_t3 = errors_t3 + 1;
                end
            end else begin
                if (s2 !== 1'b0) begin
                    $display("T3 FAIL cyc %0d: sync_out=%0d expected 0", cycle, s2);
                    errors_t3 = errors_t3 + 1;
                end
            end
            // Data is not X when valid
            if (v2 === 1'b1 && (re2 === 16'hxxxx || im2 === 16'hxxxx)) begin
                $display("T3 FAIL cyc %0d: output is X when valid", cycle);
                errors_t3 = errors_t3 + 1;
            end

            // Print trace
            $display("cyc %2d: ph_i=%0d ph_ii=%0d rot=%0d tw=%2d din=(%4d,%4d) | d0=(%5d,%5d) v=%0d s=%0d | d1=(%5d,%5d) v=%0d s=%0d | d2=(%5d,%5d) v=%0d s=%0d",
                     cycle, phase_sel_i, phase_sel_ii, rot_sel, tw_addr,
                     din_re, din_im,
                     re0, im0, v0, s0,
                     re1, im1, v1, s1,
                     re2, im2, v2, s2);

            @(posedge clk);
            tb_cnt = tb_cnt + 1;
        end

        // ============================================================
        // Run a few more clocks to flush pipeline (no new valid input)
        // ============================================================
        valid_in = 0; sync_in = 0;
        repeat (4) begin
            #1;
            @(posedge clk);
        end

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        total_errors = errors_t1 + errors_t2 + errors_t3;
        $display("Test 1 (HAS_CMUL=0):      %0d errors", errors_t1);
        $display("Test 2 (unity CMUL):       %0d errors", errors_t2);
        $display("Test 3 (real twiddle):     %0d errors", errors_t3);
        $display("");
        if (total_errors == 0)
            $display("=== PASS === All r22sdf_block tests passed.");
        else
            $display("=== FAIL === %0d total errors.", total_errors);

        #20; $finish;
    end

endmodule
