`timescale 1ns/1ps

module tb_fft256_r22sdf_top;

    localparam int DATA_W = 16;
    localparam int N      = 256;
    localparam int EXP_LATENCY = 258;

    logic                      clk;
    logic                      rst_n;
    logic                      valid_in;
    logic                      sync_in;
    logic signed [DATA_W-1:0]  din_re;
    logic signed [DATA_W-1:0]  din_im;
    logic                      valid_out;
    logic                      sync_out;
    logic signed [DATA_W-1:0]  dout_re;
    logic signed [DATA_W-1:0]  dout_im;

    fft256_r22sdf_top #(.DATA_W(DATA_W)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle = 0;
    always @(posedge clk) cycle++;

    // Test data arrays
    logic [31:0] test_in       [0:5119];
    logic [31:0] exp_out_nat   [0:5119];
    logic [31:0] exp_out_br    [0:5119];
    logic [31:0] exp_out_dr    [0:5119];

    logic signed [DATA_W-1:0] exp_re_nat, exp_im_nat;
    logic signed [DATA_W-1:0] exp_re_br,  exp_im_br;
    logic signed [DATA_W-1:0] exp_re_dr,  exp_im_dr;

    integer out_count;
    integer errors;
    integer test_id;
    integer latency;
    integer start_cycle;
    integer test_len;

    // Error statistics
    integer max_err_re;
    integer max_err_im;
    longint sum_err;
    integer err_gt_1;
    integer err_gt_2;
    integer err_gt_5;

    string tests [1:9];

    initial begin
        tests[1] = "Zeros"; tests[2] = "Impulse"; tests[3] = "DC";
        tests[4] = "ToneBin1"; tests[5] = "ToneBin7"; tests[6] = "ToneBin31"; tests[7] = "Random";
        tests[8] = "RandomStress20"; tests[9] = "BackToBack3";
        
        $dumpfile("tb_fft256_r22sdf_top.vcd");
        $dumpvars(0, tb_fft256_r22sdf_top);
        
        rst_n = 0;
        valid_in = 0;
        sync_in = 0;
        din_re = 0; din_im = 0;
        
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (test_id = 1; test_id <= 9; test_id++) begin
            $display("==================================================");
            $display("Running Test %0d: %s", test_id, tests[test_id]);
            $display("==================================================");
            
            if (test_id == 8) test_len = N * 20;
            else if (test_id == 9) test_len = N * 3;
            else test_len = N;

            $readmemh($sformatf("sim/test_data/fft256_in_%0d.hex", test_id), test_in);
            $readmemh($sformatf("sim/test_data/fft256_out_nat_%0d.hex", test_id), exp_out_nat);
            $readmemh($sformatf("sim/test_data/fft256_out_br_%0d.hex", test_id), exp_out_br);
            $readmemh($sformatf("sim/test_data/fft256_out_dr_%0d.hex", test_id), exp_out_dr);

            errors = 0;
            out_count = 0;
            latency = -1;
            
            max_err_re = 0;
            max_err_im = 0;
            sum_err = 0;
            err_gt_1 = 0;
            err_gt_2 = 0;
            err_gt_5 = 0;

            // Drive samples
            fork
                begin
                    for (int i = 0; i < test_len; i++) begin
                        valid_in <= 1;
                        sync_in  <= (i % N == 0) ? 1 : 0;
                        if (i == 0) start_cycle = cycle;
                        din_re   <= test_in[i][31:16];
                        din_im   <= test_in[i][15:0];
                        @(posedge clk);
                    end
                    // Keep valid_in high to flush the pipeline
                    valid_in <= 1;
                    sync_in  <= 0;
                    din_re   <= 0;
                    din_im   <= 0;
                end
                
                begin
                    integer match_nat, match_br, match_dr;
                    integer sync_out_count;
                    match_nat = 1; match_br = 1; match_dr = 1;
                    sync_out_count = 0;

                    while (out_count < test_len) begin
                        if (valid_out) begin
                            if (sync_out) begin
                                sync_out_count++;
                                if (latency == -1) begin
                                    latency = cycle - start_cycle;
                                    $display("Detected Latency: %0d cycles (Expected: %0d)", latency, EXP_LATENCY);
                                    if (latency != EXP_LATENCY) begin
                                        $display("ERROR: Latency mismatch!");
                                        errors++;
                                    end
                                end
                            end

                            if (latency != -1) begin
                                exp_re_nat = exp_out_nat[out_count][31:16];
                                exp_im_nat = exp_out_nat[out_count][15:0];
                                exp_re_br  = exp_out_br[out_count][31:16];
                                exp_im_br  = exp_out_br[out_count][15:0];
                                exp_re_dr  = exp_out_dr[out_count][31:16];
                                exp_im_dr  = exp_out_dr[out_count][15:0];

                                begin
                                    integer diff_re, diff_im, abs_re, abs_im;
                                    
                                    // Calculate bit-reversed error stats since it is the native order
                                    diff_re = dout_re - exp_re_br;
                                    diff_im = dout_im - exp_im_br;
                                    abs_re = (diff_re < 0) ? -diff_re : diff_re;
                                    abs_im = (diff_im < 0) ? -diff_im : diff_im;
                                    
                                    if (abs_re > max_err_re) max_err_re = abs_re;
                                    if (abs_im > max_err_im) max_err_im = abs_im;
                                    sum_err = sum_err + abs_re + abs_im;
                                    
                                    if (abs_re > 1 || abs_im > 1) err_gt_1++;
                                    if (abs_re > 2 || abs_im > 2) err_gt_2++;
                                    if (abs_re > 5 || abs_im > 5) err_gt_5++;
                                end

                                // Tolerance of 5 LSB
                                if ((dout_re > exp_re_nat ? dout_re - exp_re_nat : exp_re_nat - dout_re) > 5 || 
                                    (dout_im > exp_im_nat ? dout_im - exp_im_nat : exp_im_nat - dout_im) > 5) match_nat = 0;
                                    
                                if ((dout_re > exp_re_br ? dout_re - exp_re_br : exp_re_br - dout_re) > 5 || 
                                    (dout_im > exp_im_br ? dout_im - exp_im_br : exp_im_br - dout_im) > 5) match_br = 0;
                                    
                                if ((dout_re > exp_re_dr ? dout_re - exp_re_dr : exp_re_dr - dout_re) > 5 || 
                                    (dout_im > exp_im_dr ? dout_im - exp_im_dr : exp_im_dr - dout_im) > 5) match_dr = 0;

                                out_count++;
                            end
                        end
                        @(posedge clk);
                        if (cycle > start_cycle + test_len + EXP_LATENCY + 100) begin
                            $display("ERROR: Timeout waiting for output!");
                            out_count = test_len; // break loop
                        end
                    end
                    
                    if (match_nat) $display("Match found: NATURAL order");
                    else if (match_br) $display("Match found: BIT-REVERSED order");
                    else if (match_dr) $display("Match found: DIGIT-REVERSED order");
                    else begin
                        $display("ERROR: No match found! Output order issue or computation error.");
                        errors++;
                    end
                    
                    if (test_id >= 4) begin
                        $display("Error Statistics (Bit-Reversed Match):");
                        $display("  Max Abs Error (Re): %0d", max_err_re);
                        $display("  Max Abs Error (Im): %0d", max_err_im);
                        $display("  Mean Abs Error    : %0f", real'(sum_err) / (test_len * 2.0));
                        $display("  Samples > 1 LSB   : %0d / %0d", err_gt_1, test_len);
                        $display("  Samples > 2 LSB   : %0d / %0d", err_gt_2, test_len);
                        $display("  Samples > 5 LSB   : %0d / %0d", err_gt_5, test_len);
                    end
                    $display("  sync_out pulses   : %0d (Expected: %0d)", sync_out_count, test_len / N);
                end
            join

            // Stop valid_in after capturing
            valid_in <= 0;

            // Flush pipeline between tests
            repeat (20) @(posedge clk);
        end
        
        $display("All tests completed.");
        $finish;
    end
endmodule
