// tb_twiddle_rom.sv
// Self-checking testbench for twiddle_rom.
// Loads tw256.hex, tw64.hex, tw16.hex.
// Checks cardinal points and several intermediate addresses.
// Prints PASS only if all checks pass.

`timescale 1ns/1ps

module tb_twiddle_rom;

    localparam int DATA_W = 16;

    // ----------------------------------------------------------------
    // ROM instances
    // ----------------------------------------------------------------
    // tw256: 256 entries, ADDR_W = 8
    logic [7:0]                addr256;
    logic signed [DATA_W-1:0] re256, im256;
    twiddle_rom #(.DATA_W(DATA_W), .ADDR_W(8), .ROM_FILE("rom/tw256.hex"))
        u_tw256 (.addr(addr256), .tw_re(re256), .tw_im(im256));

    // tw64: 64 entries, ADDR_W = 6
    logic [5:0]                addr64;
    logic signed [DATA_W-1:0] re64, im64;
    twiddle_rom #(.DATA_W(DATA_W), .ADDR_W(6), .ROM_FILE("rom/tw64.hex"))
        u_tw64 (.addr(addr64), .tw_re(re64), .tw_im(im64));

    // tw16: 16 entries, ADDR_W = 4
    logic [3:0]                addr16;
    logic signed [DATA_W-1:0] re16, im16;
    twiddle_rom #(.DATA_W(DATA_W), .ADDR_W(4), .ROM_FILE("rom/tw16.hex"))
        u_tw16 (.addr(addr16), .tw_re(re16), .tw_im(im16));

    // ----------------------------------------------------------------
    // Known Q1.15 cardinal values
    //
    // W_M^0       =  1 + j0  → re= 32767 (0x7FFF), im=0
    // W_M^(M/4)   =  0 - j1  → re=0, im=-32768 (0x8000)
    // W_M^(M/2)   = -1 + j0  → re=-32768 (0x8000), im=0
    // W_M^(3M/4)  =  0 + j1  → re=0, im= 32767 (0x7FFF)
    // ----------------------------------------------------------------

    integer errors;

    // Check helper
    task automatic check(
        input string   rom_name,
        input int      addr_val,
        input int      got_re,
        input int      got_im,
        input int      exp_re,
        input int      exp_im
    );
    begin
        if (got_re !== exp_re || got_im !== exp_im) begin
            $display("FAIL %s[%0d]: got(%0d,%0d) exp(%0d,%0d)",
                     rom_name, addr_val, got_re, got_im, exp_re, exp_im);
            errors = errors + 1;
        end else begin
            $display("  OK %s[%0d]: (%0d, %0d)", rom_name, addr_val, got_re, got_im);
        end
    end
    endtask

    // ----------------------------------------------------------------
    // Known intermediate values (from Python: gen_twiddle_hex.py)
    //
    // W_16^1 = cos(-2pi/16) - j*sin(-2pi/16)
    //        = cos(pi/8) - j*sin(pi/8)
    //        = 0.92388 - j*0.38268
    //   Q1.15: re = trunc(0.92388*32768) = 30273
    //          im = trunc(-0.38268*32768) = -12539  (ceil toward 0)
    //   Hex check: re=0x7641, im=0xCF05 → word=0x7641CF05 ✓ (matches tw16.hex line 1)
    //
    // W_16^2 = cos(-pi/4) - j*sin(-pi/4)
    //        = 0.70711 - j*(-0.70711) ... wait
    //   Actually: cos(-2pi*2/16) = cos(-pi/4) = 0.70711
    //             sin(-2pi*2/16) = sin(-pi/4) = -0.70711
    //   tw_re = 0.70711, tw_im = -0.70711
    //   Q1.15: re = trunc(0.70711*32768) = 23170 = 0x5A82
    //          im = trunc(-0.70711*32768) = -23170 → ceil = -23170 = 0xA57E
    //   Word = 0x5A82A57E ✓ (matches tw16.hex line 2)
    //
    // W_256^1:
    //   cos(-2pi/256) = 0.99970, sin(-2pi/256) = -0.02454
    //   re = trunc(0.99970*32768) = 32758 = 0x7FF6
    //   im = trunc(-0.02454*32768) = -804 → ceil = -804
    //   -804 unsigned = 0xFCDC
    //   Word = 0x7FF6FCDC
    //
    // W_256^32 = W_8^1 = cos(-pi/4) - j*sin(-pi/4) = 0.70711 - j*0.70711
    //   Wait: sin(-2pi*32/256) = sin(-pi/4) = -0.70711
    //   re = 23170, im = -23170 → same as W_16^2
    // ----------------------------------------------------------------

    initial begin
        errors = 0;

        // ============================================================
        // tw256 cardinal points
        // ============================================================
        $display("--- tw256 ---");

        addr256 = 8'd0;   #1;
        check("tw256", 0,   re256, im256, 16'sd32767, 16'sd0);

        addr256 = 8'd64;  #1;
        check("tw256", 64,  re256, im256, 16'sd0, 16'sh8000);

        addr256 = 8'd128; #1;
        check("tw256", 128, re256, im256, 16'sh8000, 16'sd0);

        addr256 = 8'd192; #1;
        check("tw256", 192, re256, im256, 16'sd0, 16'sd32767);

        // Intermediate: k=1
        addr256 = 8'd1;   #1;
        check("tw256", 1,   re256, im256, 16'sd32758, -16'sd804);

        // Intermediate: k=32 (= W_8^1 = cos45 - j*sin45)
        addr256 = 8'd32;  #1;
        check("tw256", 32,  re256, im256, 16'sd23170, -16'sd23170);

        // ============================================================
        // tw64 cardinal points
        // ============================================================
        $display("--- tw64 ---");

        addr64 = 6'd0;    #1;
        check("tw64", 0,   re64, im64, 16'sd32767, 16'sd0);

        addr64 = 6'd16;   #1;
        check("tw64", 16,  re64, im64, 16'sd0, 16'sh8000);

        addr64 = 6'd32;   #1;
        check("tw64", 32,  re64, im64, 16'sh8000, 16'sd0);

        addr64 = 6'd48;   #1;
        check("tw64", 48,  re64, im64, 16'sd0, 16'sd32767);

        // Intermediate: k=8 (= W_8^1)
        addr64 = 6'd8;    #1;
        check("tw64", 8,   re64, im64, 16'sd23170, -16'sd23170);

        // ============================================================
        // tw16 cardinal points
        // ============================================================
        $display("--- tw16 ---");

        addr16 = 4'd0;    #1;
        check("tw16", 0,   re16, im16, 16'sd32767, 16'sd0);

        addr16 = 4'd4;    #1;
        check("tw16", 4,   re16, im16, 16'sd0, 16'sh8000);

        addr16 = 4'd8;    #1;
        check("tw16", 8,   re16, im16, 16'sh8000, 16'sd0);

        addr16 = 4'd12;   #1;
        check("tw16", 12,  re16, im16, 16'sd0, 16'sd32767);

        // Intermediate: k=1 (cos(pi/8) - j*sin(pi/8))
        addr16 = 4'd1;    #1;
        check("tw16", 1,   re16, im16, 16'sd30273, -16'sd12539);

        // Intermediate: k=2 (cos(pi/4) - j*sin(pi/4))
        addr16 = 4'd2;    #1;
        check("tw16", 2,   re16, im16, 16'sd23170, -16'sd23170);

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        if (errors == 0)
            $display("=== PASS === All twiddle ROM checks passed.");
        else
            $display("=== FAIL === %0d errors.", errors);

        $finish;
    end

endmodule
