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
    logic [31:0] test_in       [0:N-1];
    logic [31:0] exp_out_nat   [0:N-1];
    logic [31:0] exp_out_br    [0:N-1];
    logic [31:0] exp_out_dr    [0:N-1];

    logic signed [DATA_W-1:0] exp_re_nat, exp_im_nat;
    logic signed [DATA_W-1:0] exp_re_br,  exp_im_br;
    logic signed [DATA_W-1:0] exp_re_dr,  exp_im_dr;

    integer out_count;
    integer errors;
    integer test_id;
    integer latency;
    integer start_cycle;

    string tests [1:7];

    initial begin
        tests[1] = "Zeros"; tests[2] = "Impulse"; tests[3] = "DC";
        tests[4] = "ToneBin1"; tests[5] = "ToneBin7"; tests[6] = "ToneBin31"; tests[7] = "Random";
        
        $dumpfile("tb_fft256_r22sdf_top.vcd");
        $dumpvars(0, tb_fft256_r22sdf_top);
        
        rst_n = 0;
        valid_in = 0;
        sync_in = 0;
        din_re = 0; din_im = 0;
        
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (test_id = 1; test_id <= 7; test_id++) begin
            $display("==================================================");
            $display("Running Test %0d: %s", test_id, tests[test_id]);
            $display("==================================================");
            
            $readmemh($sformatf("sim/test_data/fft256_in_%0d.hex", test_id), test_in);
            $readmemh($sformatf("sim/test_data/fft256_out_nat_%0d.hex", test_id), exp_out_nat);
            $readmemh($sformatf("sim/test_data/fft256_out_br_%0d.hex", test_id), exp_out_br);
            $readmemh($sformatf("sim/test_data/fft256_out_dr_%0d.hex", test_id), exp_out_dr);

            errors = 0;
            out_count = 0;
            latency = -1;

            // Drive 256 samples
            fork
                begin
                    for (int i = 0; i < N; i++) begin
                        valid_in <= 1;
                        sync_in  <= (i == 0) ? 1 : 0;
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
                    match_nat = 1; match_br = 1; match_dr = 1;

                    while (out_count < N) begin
                        if (valid_out) begin
                            if (sync_out && latency == -1) begin
                                latency = cycle - start_cycle;
                                $display("Detected Latency: %0d cycles (Expected: %0d)", latency, EXP_LATENCY);
                                if (latency != EXP_LATENCY) begin
                                    $display("ERROR: Latency mismatch!");
                                    errors++;
                                end
                            end

                            if (latency != -1) begin
                                exp_re_nat = exp_out_nat[out_count][31:16];
                                exp_im_nat = exp_out_nat[out_count][15:0];
                                exp_re_br  = exp_out_br[out_count][31:16];
                                exp_im_br  = exp_out_br[out_count][15:0];
                                exp_re_dr  = exp_out_dr[out_count][31:16];
                                exp_im_dr  = exp_out_dr[out_count][15:0];

                                // Tolerance of 5 LSB
                                if ((dout_re > exp_re_nat ? dout_re - exp_re_nat : exp_re_nat - dout_re) > 5 || 
                                    (dout_im > exp_im_nat ? dout_im - exp_im_nat : exp_im_nat - dout_im) > 5) match_nat = 0;
                                    
                                if ((dout_re > exp_re_br ? dout_re - exp_re_br : exp_re_br - dout_re) > 5 || 
                                    (dout_im > exp_im_br ? dout_im - exp_im_br : exp_im_br - dout_im) > 5) match_br = 0;
                                    
                                if ((dout_re > exp_re_dr ? dout_re - exp_re_dr : exp_re_dr - dout_re) > 5 || 
                                    (dout_im > exp_im_dr ? dout_im - exp_im_dr : exp_im_dr - dout_im) > 5) match_dr = 0;

                                if (test_id == 2) begin
                                    // Print first few outputs for debugging
                                    if (out_count < 10) begin
                                        $display("cyc %0d idx %0d Out: (%5d, %5d) | Exp BR: (%5d, %5d)", cycle, out_count, dout_re, dout_im, exp_re_br, exp_im_br);
                                    end
                                end

                                out_count++;
                            end
                        end
                        @(posedge clk);
                        if (cycle > start_cycle + N + EXP_LATENCY + 100) begin
                            $display("ERROR: Timeout waiting for output!");
                            out_count = N; // break loop
                        end
                    end
                    
                    if (match_nat) $display("Match found: NATURAL order");
                    else if (match_br) $display("Match found: BIT-REVERSED order");
                    else if (match_dr) $display("Match found: DIGIT-REVERSED order");
                    else begin
                        $display("ERROR: No match found! Output order issue or computation error.");
                        errors++;
                    end
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
