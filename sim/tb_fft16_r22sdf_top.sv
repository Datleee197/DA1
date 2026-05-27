// tb_fft16_r22sdf_top.sv
// Testbench for FFT-16 sandbox

`timescale 1ns/1ps

module tb_fft16_r22sdf_top;

    localparam int DW = 16;
    localparam int N = 16;
    
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;
    
    logic rst_n, valid_in, sync_in;
    logic signed [DW-1:0] din_re, din_im;
    
    logic valid_out, sync_out;
    logic signed [DW-1:0] dout_re, dout_im;
    
    fft16_r22sdf_top #(
        .DATA_W(DW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .sync_in(sync_in),
        .din_re(din_re),
        .din_im(din_im),
        .valid_out(valid_out),
        .sync_out(sync_out),
        .dout_re(dout_re),
        .dout_im(dout_im)
    );
    
    // ================================================================
    // Test logic
    // ================================================================
    
    // Arrays for Python golden data
    logic [31:0] in_data [0:15];
    logic [31:0] exp_nat [0:15];
    logic [31:0] exp_br  [0:15];
    logic [31:0] exp_dr  [0:15];
    
    // Captured output
    logic signed [DW-1:0] cap_re [0:15];
    logic signed [DW-1:0] cap_im [0:15];
    
    string test_names [1:6];
    
    integer test_idx;
    integer i;
    integer m_nat, m_br, m_dr;
    integer diff_re, diff_im;
    
    initial begin
        test_names[1] = "test_1_all_zeros";
        test_names[2] = "test_2_impulse";
        test_names[3] = "test_3_dc_constant";
        test_names[4] = "test_4_tone_bin_1";
        test_names[5] = "test_5_tone_bin_3";
        test_names[6] = "test_6_random";
        rst_n = 0;
        valid_in = 0;
        sync_in = 0;
        din_re = 0;
        din_im = 0;
        
        $dumpfile("tb_fft16_r22sdf_top.vcd");
        $dumpvars(0, tb_fft16_r22sdf_top);
        
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        for (test_idx = 1; test_idx <= 6; test_idx++) begin
            $display("==================================================");
            $display("Running %s", test_names[test_idx]);
            $display("==================================================");
            
            // Load hex files
            $readmemh({"sim/", test_names[test_idx], "_in.hex"}, in_data);
            $readmemh({"sim/", test_names[test_idx], "_out_nat.hex"}, exp_nat);
            $readmemh({"sim/", test_names[test_idx], "_out_br.hex"}, exp_br);
            $readmemh({"sim/", test_names[test_idx], "_out_dr.hex"}, exp_dr);
            
            // Drive inputs
            for (i = 0; i < 16; i++) begin
                valid_in <= 1;
                sync_in  <= (i == 0) ? 1 : 0;
                din_re   <= $signed(in_data[i][31:16]);
                din_im   <= $signed(in_data[i][15:0]);
                @(posedge clk);
            end
            
            // Flush pipeline (keep valid_in high to let counters run)
            valid_in <= 1;
            sync_in  <= 0;
            din_re   <= 0;
            din_im   <= 0;
            
            while (!valid_out) @(posedge clk);
            
            // Capture 16 outputs
            for (i = 0; i < 16; i++) begin
                if (!valid_out) begin
                    $display("ERROR: valid_out dropped before 16 samples!");
                end
                cap_re[i] = dout_re;
                cap_im[i] = dout_im;
                @(posedge clk);
            end
            
            // Stop valid_in after capturing
            valid_in <= 0;
            
            // Compare
            m_nat = 0; m_br = 0; m_dr = 0;
            for (i = 0; i < 16; i++) begin
                // Check against natural
                diff_re = cap_re[i] - $signed(exp_nat[i][31:16]);
                diff_im = cap_im[i] - $signed(exp_nat[i][15:0]);
                if (diff_re < -2 || diff_re > 2 || diff_im < -2 || diff_im > 2) m_nat++;
                
                // Check against bit-reversed
                diff_re = cap_re[i] - $signed(exp_br[i][31:16]);
                diff_im = cap_im[i] - $signed(exp_br[i][15:0]);
                if (diff_re < -2 || diff_re > 2 || diff_im < -2 || diff_im > 2) m_br++;
                
                // Check against digit-reversed
                diff_re = cap_re[i] - $signed(exp_dr[i][31:16]);
                diff_im = cap_im[i] - $signed(exp_dr[i][15:0]);
                if (diff_re < -2 || diff_re > 2 || diff_im < -2 || diff_im > 2) m_dr++;
            end
            
            if (m_nat == 0) $display("Match found: NATURAL order");
            else if (m_br == 0) $display("Match found: BIT-REVERSED order");
            else if (m_dr == 0) $display("Match found: DIGIT-REVERSED order");
            else begin
                $display("ERROR: No match found! Output dumped below:");
                for (i = 0; i < 16; i++) begin
                    $display("  [%2d] Out: (%6d, %6d) | Exp Nat: (%6d, %6d) | Exp BR: (%6d, %6d) | Exp DR: (%6d, %6d)", 
                        i, cap_re[i], cap_im[i], 
                        $signed(exp_nat[i][31:16]), $signed(exp_nat[i][15:0]),
                        $signed(exp_br[i][31:16]), $signed(exp_br[i][15:0]),
                        $signed(exp_dr[i][31:16]), $signed(exp_dr[i][15:0]));
                end
            end
            
            // Wait some cycles between tests
            repeat (10) @(posedge clk);
        end
        
        $display("All tests completed.");
        $finish;
    end
    
endmodule
