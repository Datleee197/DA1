`timescale 1ns/1ps

module fft256_r22sdf_top #(
    parameter int DATA_W = 16
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      valid_in,
    input  logic                      sync_in,
    input  logic signed [DATA_W-1:0]  din_re,
    input  logic signed [DATA_W-1:0]  din_im,
    output logic                      valid_out,
    output logic                      sync_out,
    output logic signed [DATA_W-1:0]  dout_re,
    output logic signed [DATA_W-1:0]  dout_im
);

    // ----------------------------------------------------------------
    // Block 0: DELAY_I=128, DELAY_II=64, HAS_CMUL=1
    // ----------------------------------------------------------------
    logic                      b0_valid, b0_sync;
    logic signed [DATA_W-1:0]  b0_re, b0_im;

    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(128),
        .DELAY_II(64),
        .HAS_CMUL(1),
        .TW_ADDR_W(8),
        .TW_FILE("rom/tw256.hex")
    ) blk0 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .sync_in(sync_in),
        .din_re(din_re),
        .din_im(din_im),
        .valid_out(b0_valid),
        .sync_out(b0_sync),
        .dout_re(b0_re),
        .dout_im(b0_im)
    );

    // ----------------------------------------------------------------
    // Block 1: DELAY_I=32, DELAY_II=16, HAS_CMUL=1
    // ----------------------------------------------------------------
    logic                      b1_valid, b1_sync;
    logic signed [DATA_W-1:0]  b1_re, b1_im;

    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(32),
        .DELAY_II(16),
        .HAS_CMUL(1),
        .TW_ADDR_W(6),
        .TW_FILE("rom/tw64.hex")
    ) blk1 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(b0_valid),
        .sync_in(b0_sync),
        .din_re(b0_re),
        .din_im(b0_im),
        .valid_out(b1_valid),
        .sync_out(b1_sync),
        .dout_re(b1_re),
        .dout_im(b1_im)
    );

    // ----------------------------------------------------------------
    // Block 2: DELAY_I=8, DELAY_II=4, HAS_CMUL=1
    // ----------------------------------------------------------------
    logic                      b2_valid, b2_sync;
    logic signed [DATA_W-1:0]  b2_re, b2_im;

    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(8),
        .DELAY_II(4),
        .HAS_CMUL(1),
        .TW_ADDR_W(4),
        .TW_FILE("rom/tw16.hex")
    ) blk2 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(b1_valid),
        .sync_in(b1_sync),
        .din_re(b1_re),
        .din_im(b1_im),
        .valid_out(b2_valid),
        .sync_out(b2_sync),
        .dout_re(b2_re),
        .dout_im(b2_im)
    );

    // ----------------------------------------------------------------
    // Block 3: DELAY_I=2, DELAY_II=1, HAS_CMUL=0
    // ----------------------------------------------------------------
    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(2),
        .DELAY_II(1),
        .HAS_CMUL(0)
    ) blk3 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(b2_valid),
        .sync_in(b2_sync),
        .din_re(b2_re),
        .din_im(b2_im),
        .valid_out(valid_out),
        .sync_out(sync_out),
        .dout_re(dout_re),
        .dout_im(dout_im)
    );

endmodule
