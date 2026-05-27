// fft16_r22sdf_top.sv
// Top-level for FFT-16 R2^2SDF sandbox.
// Chains two controlled r22sdf_block instances.

module fft16_r22sdf_top #(
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
    // Block 0: DELAY_I=8, DELAY_II=4, HAS_CMUL=1
    // ----------------------------------------------------------------
    logic                      b0_valid, b0_sync;
    logic signed [DATA_W-1:0]  b0_re, b0_im;

    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(8),
        .DELAY_II(4),
        .HAS_CMUL(1),
        .TW_ADDR_W(4),
        .TW_FILE("rom/tw16.hex")
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
    // Block 1: DELAY_I=2, DELAY_II=1, HAS_CMUL=0
    // ----------------------------------------------------------------
    r22sdf_block_controlled #(
        .DATA_W(DATA_W),
        .DELAY_I(2),
        .DELAY_II(1),
        .HAS_CMUL(0)
    ) blk1 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(b0_valid),
        .sync_in(b0_sync),
        .din_re(b0_re),
        .din_im(b0_im),
        .valid_out(valid_out),
        .sync_out(sync_out),
        .dout_re(dout_re),
        .dout_im(dout_im)
    );

endmodule
