// tb_r22sdf_block_controlled.sv
// Self-checking testbench for r22sdf_block_controlled.
// Three configs, each with a controlled wrapper + reference raw block.
// TB replicates counter logic to drive the reference block identically.

`timescale 1ns/1ps

module tb_r22sdf_block_controlled;

    localparam int DW = 16;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    logic rst_n, valid_in, sync_in;
    logic signed [DW-1:0] din_re, din_im;

    // ================================================================
    // Config 1: DELAY_I=4, DELAY_II=2, HAS_CMUL=0
    // ================================================================
    logic v1c, s1c; logic signed [DW-1:0] re1c, im1c;
    r22sdf_block_controlled #(
        .DATA_W(DW),.DELAY_I(4),.DELAY_II(2),.HAS_CMUL(0),
        .TW_ADDR_W(4),.TW_FILE("rom/tw_unity.hex")
    ) ctrl1 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v1c),.sync_out(s1c),.dout_re(re1c),.dout_im(im1c)
    );

    // Reference raw block for Config 1
    logic v1r, s1r; logic signed [DW-1:0] re1r, im1r;
    logic [2:0] cnt1;
    logic ps1_i, ps1_ii; logic [1:0] rs1;
    r22sdf_block #(
        .DATA_W(DW),.DELAY_I(4),.DELAY_II(2),.HAS_CMUL(0),
        .TW_ADDR_W(4),.TW_FILE("rom/tw_unity.hex")
    ) ref1 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .phase_sel_i(ps1_i),.phase_sel_ii(ps1_ii),
        .rot_sel(rs1),.tw_addr(4'd0),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v1r),.sync_out(s1r),.dout_re(re1r),.dout_im(im1r)
    );
    assign ps1_i  = cnt1[2];
    assign ps1_ii = cnt1[1];
    assign rs1    = {cnt1[2], cnt1[1]};

    // ================================================================
    // Config 2: DELAY_I=4, DELAY_II=2, HAS_CMUL=1, unity
    // ================================================================
    logic v2c, s2c; logic signed [DW-1:0] re2c, im2c;
    r22sdf_block_controlled #(
        .DATA_W(DW),.DELAY_I(4),.DELAY_II(2),.HAS_CMUL(1),
        .TW_ADDR_W(4),.TW_FILE("rom/tw_unity.hex")
    ) ctrl2 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v2c),.sync_out(s2c),.dout_re(re2c),.dout_im(im2c)
    );

    logic v2r, s2r; logic signed [DW-1:0] re2r, im2r;
    logic [3:0] cnt2;
    logic ps2_i, ps2_ii; logic [1:0] rs2; logic [3:0] tw2;
    r22sdf_block #(
        .DATA_W(DW),.DELAY_I(4),.DELAY_II(2),.HAS_CMUL(1),
        .TW_ADDR_W(4),.TW_FILE("rom/tw_unity.hex")
    ) ref2 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .phase_sel_i(ps2_i),.phase_sel_ii(ps2_ii),
        .rot_sel(rs2),.tw_addr(tw2),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v2r),.sync_out(s2r),.dout_re(re2r),.dout_im(im2r)
    );
    assign ps2_i  = cnt2[2];
    assign ps2_ii = cnt2[1];
    assign rs2    = {cnt2[2], cnt2[1]};
    assign tw2    = cnt2[3:0];

    // ================================================================
    // Config 3: DELAY_I=8, DELAY_II=4, HAS_CMUL=1, tw64.hex
    // ================================================================
    logic v3c, s3c; logic signed [DW-1:0] re3c, im3c;
    r22sdf_block_controlled #(
        .DATA_W(DW),.DELAY_I(8),.DELAY_II(4),.HAS_CMUL(1),
        .TW_ADDR_W(6),.TW_FILE("rom/tw64.hex")
    ) ctrl3 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v3c),.sync_out(s3c),.dout_re(re3c),.dout_im(im3c)
    );

    logic v3r, s3r; logic signed [DW-1:0] re3r, im3r;
    logic [5:0] cnt3;
    logic ps3_i, ps3_ii; logic [1:0] rs3; logic [5:0] tw3;
    r22sdf_block #(
        .DATA_W(DW),.DELAY_I(8),.DELAY_II(4),.HAS_CMUL(1),
        .TW_ADDR_W(6),.TW_FILE("rom/tw64.hex")
    ) ref3 (
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),.sync_in(sync_in),
        .phase_sel_i(ps3_i),.phase_sel_ii(ps3_ii),
        .rot_sel(rs3),.tw_addr(tw3[5:0]),
        .din_re(din_re),.din_im(din_im),
        .valid_out(v3r),.sync_out(s3r),.dout_re(re3r),.dout_im(im3r)
    );
    assign ps3_i  = cnt3[3];
    assign ps3_ii = cnt3[2];
    assign rs3    = {cnt3[3], cnt3[2]};
    assign tw3    = cnt3[5:0];

    // ================================================================
    // TB counter replication (same logic as r22sdf_block_controlled)
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt1 <= '0; cnt2 <= '0; cnt3 <= '0;
        end else if (valid_in) begin
            if (sync_in) begin
                cnt1 <= '0; cnt2 <= '0; cnt3 <= '0;
            end else begin
                cnt1 <= cnt1 + 1'b1;
                cnt2 <= cnt2 + 1'b1;
                cnt3 <= cnt3 + 1'b1;
            end
        end
    end

    // VCD
    initial begin
        $dumpfile("tb_r22sdf_block_controlled.vcd");
        $dumpvars(0, tb_r22sdf_block_controlled);
    end

    // ================================================================
    // Stimulus and checking
    // ================================================================
    localparam int NUM_CYC = 48;  // enough for Config 3 (latency ~14)
    integer cycle, e1, e2, e3, total;

    initial begin
        rst_n = 0; valid_in = 0; sync_in = 0;
        din_re = 0; din_im = 0;
        e1 = 0; e2 = 0; e3 = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (cycle = 0; cycle < NUM_CYC; cycle = cycle + 1) begin
            valid_in = 1;
            sync_in  = (cycle == 0) ? 1 : 0;
            din_re   = 16'(10 * (cycle + 1));
            din_im   = 16'( 5 * (cycle + 1));

            #1; // settle

            // ---- Config 1 check: ctrl vs ref must match exactly ----
            if (v1c !== v1r || s1c !== s1r || re1c !== re1r || im1c !== im1r) begin
                $display("T1 FAIL cyc %0d cnt=%0d: ctrl=(%0d,%0d v=%0d s=%0d) ref=(%0d,%0d v=%0d s=%0d) ps_i=%0d ps_ii=%0d rot=%0d",
                    cycle, cnt1, re1c, im1c, v1c, s1c, re1r, im1r, v1r, s1r, ps1_i, ps1_ii, rs1);
                e1 = e1 + 1;
            end

            // ---- Config 2 check ----
            if (v2c !== v2r || s2c !== s2r || re2c !== re2r || im2c !== im2r) begin
                $display("T2 FAIL cyc %0d cnt=%0d: ctrl=(%0d,%0d v=%0d s=%0d) ref=(%0d,%0d v=%0d s=%0d) ps_i=%0d ps_ii=%0d rot=%0d tw=%0d",
                    cycle, cnt2, re2c, im2c, v2c, s2c, re2r, im2r, v2r, s2r, ps2_i, ps2_ii, rs2, tw2);
                e2 = e2 + 1;
            end

            // ---- Config 3 check ----
            if (v3c !== v3r || s3c !== s3r || re3c !== re3r || im3c !== im3r) begin
                $display("T3 FAIL cyc %0d cnt=%0d: ctrl=(%0d,%0d v=%0d s=%0d) ref=(%0d,%0d v=%0d s=%0d) ps_i=%0d ps_ii=%0d rot=%0d tw=%0d",
                    cycle, cnt3, re3c, im3c, v3c, s3c, re3r, im3r, v3r, s3r, ps3_i, ps3_ii, rs3, tw3);
                e3 = e3 + 1;
            end

            @(posedge clk);
        end

        $display("");
        total = e1 + e2 + e3;
        $display("Test 1 (HAS_CMUL=0, DI=4/DII=2): %0d errors", e1);
        $display("Test 2 (unity CMUL, DI=4/DII=2):  %0d errors", e2);
        $display("Test 3 (tw64 CMUL, DI=8/DII=4):   %0d errors", e3);
        $display("");
        if (total == 0)
            $display("=== PASS === All r22sdf_block_controlled tests passed.");
        else
            $display("=== FAIL === %0d total errors.", total);

        #20; $finish;
    end

endmodule
