// r22sdf_block.sv
// One Radix-2² SDF block: BF2I → BF2II → optional CMUL.
//
// Structural module — instantiates verified sub-modules.
// No internal counter, no phase/address generation.
// All control signals (phase_sel_i, phase_sel_ii, rot_sel, tw_addr)
// are external inputs from the control unit.
//
// If HAS_CMUL = 1: twiddle_rom + complex_multiplier_q15 are included.
//   CMUL adds 1 clock cycle of latency to valid/sync/data.
// If HAS_CMUL = 0: BF2II output is the block output directly.

module r22sdf_block #(
    parameter int    DATA_W    = 16,
    parameter int    DELAY_I   = 4,
    parameter int    DELAY_II  = 2,
    parameter int    HAS_CMUL  = 1,
    parameter int    TW_ADDR_W = 8,
    parameter        TW_FILE   = "rom/tw256.hex"
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      valid_in,
    input  logic                      sync_in,

    input  logic                      phase_sel_i,
    input  logic                      phase_sel_ii,
    input  logic [1:0]                rot_sel,
    input  logic [TW_ADDR_W-1:0]      tw_addr,

    input  logic signed [DATA_W-1:0]  din_re,
    input  logic signed [DATA_W-1:0]  din_im,

    output logic                      valid_out,
    output logic                      sync_out,
    output logic signed [DATA_W-1:0]  dout_re,
    output logic signed [DATA_W-1:0]  dout_im
);

    // ----------------------------------------------------------------
    // Internal wires: BF2I → BF2II
    // ----------------------------------------------------------------
    logic                      bf2i_valid, bf2i_sync;
    logic signed [DATA_W-1:0]  bf2i_re, bf2i_im;

    // ----------------------------------------------------------------
    // Internal wires: BF2II → CMUL (or output)
    // ----------------------------------------------------------------
    logic                      bf2ii_valid, bf2ii_sync;
    logic signed [DATA_W-1:0]  bf2ii_re, bf2ii_im;

    // ----------------------------------------------------------------
    // BF2I stage
    // ----------------------------------------------------------------
    sdf_bf2i_stage #(
        .DATA_W (DATA_W),
        .DELAY  (DELAY_I)
    ) u_bf2i (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .sync_in   (sync_in),
        .phase_sel (phase_sel_i),
        .din_re    (din_re),
        .din_im    (din_im),
        .valid_out (bf2i_valid),
        .sync_out  (bf2i_sync),
        .dout_re   (bf2i_re),
        .dout_im   (bf2i_im)
    );

    // ----------------------------------------------------------------
    // BF2II stage
    // ----------------------------------------------------------------
    sdf_bf2ii_stage #(
        .DATA_W (DATA_W),
        .DELAY  (DELAY_II)
    ) u_bf2ii (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (bf2i_valid),
        .sync_in   (bf2i_sync),
        .phase_sel (phase_sel_ii),
        .rot_sel   (rot_sel),
        .din_re    (bf2i_re),
        .din_im    (bf2i_im),
        .valid_out (bf2ii_valid),
        .sync_out  (bf2ii_sync),
        .dout_re   (bf2ii_re),
        .dout_im   (bf2ii_im)
    );

    // ----------------------------------------------------------------
    // Optional CMUL
    // ----------------------------------------------------------------
    generate
        if (HAS_CMUL) begin : gen_cmul
            logic signed [DATA_W-1:0] tw_re, tw_im;

            // Twiddle ROM — combinational read
            twiddle_rom #(
                .DATA_W   (DATA_W),
                .ADDR_W   (TW_ADDR_W),
                .ROM_FILE (TW_FILE)
            ) u_tw (
                .addr  (tw_addr),
                .tw_re (tw_re),
                .tw_im (tw_im)
            );

            // Complex multiplier — 1 clock cycle latency
            complex_multiplier_q15 #(
                .DATA_W (DATA_W)
            ) u_cmul (
                .clk       (clk),
                .rst_n     (rst_n),
                .valid_in  (bf2ii_valid),
                .sync_in   (bf2ii_sync),
                .z_re      (bf2ii_re),
                .z_im      (bf2ii_im),
                .tw_re     (tw_re),
                .tw_im     (tw_im),
                .valid_out (valid_out),
                .sync_out  (sync_out),
                .y_re      (dout_re),
                .y_im      (dout_im)
            );
        end else begin : gen_no_cmul
            // Bypass — BF2II output directly to block output
            assign valid_out = bf2ii_valid;
            assign sync_out  = bf2ii_sync;
            assign dout_re   = bf2ii_re;
            assign dout_im   = bf2ii_im;
        end
    endgenerate

endmodule
