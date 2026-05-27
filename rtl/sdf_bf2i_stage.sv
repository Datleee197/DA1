// sdf_bf2i_stage.sv
// Radix-2² SDF BF2I stage.
// Contains: shift-register feedback (DELAY depth) + butterfly_radix2_scaled.
// No trivial_rotator, no CMUL, no internal counter.
// phase_sel is driven externally.
//
// Behavior:
//   phase_sel == 0 (fill):    delay_in = din,  dout = delay_out
//   phase_sel == 1 (compute): delay_in = y1,   dout = y0
//     where y0 = (a+b)>>>1, y1 = (a-b)>>>1, a = delay_out, b = din
//
// The feedback shift register uses combinational output (sr[DELAY-1])
// so that the butterfly always sees the current delay value, not a
// one-cycle-stale registered copy.  delay_line_shift (which has a
// registered output) is correct for non-feedback inter-stage paths but
// creates a one-cycle skew at phase boundaries when placed in a
// feedback loop.  The shift-register here follows the same principle
// (pure shift chain) and was verified via the timing-table test.
//
// Latency: DELAY cycles (data written in cycle C appears at output in cycle C+DELAY).
// dout is combinational (no output register).
// valid_out / sync_out delayed by DELAY cycles (combinational-output SR).

module sdf_bf2i_stage #(
    parameter int DATA_W = 16,
    parameter int DELAY  = 4
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      valid_in,
    input  logic                      sync_in,
    input  logic                      phase_sel,   // 0 = fill, 1 = compute
    input  logic signed [DATA_W-1:0]  din_re,
    input  logic signed [DATA_W-1:0]  din_im,
    output logic                      valid_out,
    output logic                      sync_out,
    output logic signed [DATA_W-1:0]  dout_re,
    output logic signed [DATA_W-1:0]  dout_im
);

    // ----------------------------------------------------------------
    // Internal wires
    // ----------------------------------------------------------------
    logic signed [DATA_W-1:0] delay_in_re,  delay_in_im;
    logic signed [DATA_W-1:0] delay_out_re, delay_out_im;
    logic signed [DATA_W-1:0] y0_re, y0_im, y1_re, y1_im;

    // ----------------------------------------------------------------
    // Butterfly — purely combinational
    // a = delay_out (old stored sample), b = din (current input)
    // ----------------------------------------------------------------
    butterfly_radix2_scaled #(.DATA_W(DATA_W)) u_bf (
        .a_re  (delay_out_re),
        .a_im  (delay_out_im),
        .b_re  (din_re),
        .b_im  (din_im),
        .y0_re (y0_re),
        .y0_im (y0_im),
        .y1_re (y1_re),
        .y1_im (y1_im)
    );

    // ----------------------------------------------------------------
    // Feedback mux — selects what is written into the delay SR
    //   fill    (phase_sel=0): store incoming sample
    //   compute (phase_sel=1): store butterfly difference y1
    // ----------------------------------------------------------------
    assign delay_in_re = phase_sel ? y1_re : din_re;
    assign delay_in_im = phase_sel ? y1_im : din_im;

    // ----------------------------------------------------------------
    // Output mux — combinational, no output register
    //   fill    (phase_sel=0): forward old delay content
    //   compute (phase_sel=1): forward butterfly sum y0
    // ----------------------------------------------------------------
    assign dout_re = phase_sel ? y0_re : delay_out_re;
    assign dout_im = phase_sel ? y0_im : delay_out_im;

    // ----------------------------------------------------------------
    // Feedback delay — sdf_feedback_delay (combinational output)
    //
    // DELAY-depth shift register with combinational read from sr[DELAY-1].
    // en = 1'b1: shifts unconditionally every clock.
    // In the feedback loop the effective latency is DELAY cycles
    // (DELAY-1 SR propagation + 1 write-at-posedge boundary).
    // ----------------------------------------------------------------
    sdf_feedback_delay #(
        .DATA_W (DATA_W),
        .DELAY  (DELAY)
    ) u_fbdelay (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (1'b1),
        .din_re (delay_in_re),
        .din_im (delay_in_im),
        .dout_re(delay_out_re),
        .dout_im(delay_out_im)
    );

    // ----------------------------------------------------------------
    // Valid / sync shift register — DELAY+1 depth, combinational output
    //
    // The data feedback SR achieves DELAY cycles of effective latency
    // because the write-then-shift-then-read loop adds one implicit
    // cycle.  Valid/sync is a linear (non-feedback) pipeline, so it
    // needs DELAY+1 stages with combinational output from index DELAY
    // to produce exactly DELAY cycles of delay.
    // ----------------------------------------------------------------
    logic [DELAY-1:0] v_sr;
    logic [DELAY-1:0] s_sr;

    assign valid_out = v_sr[DELAY-1];
    assign sync_out  = s_sr[DELAY-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_sr <= '0;
            s_sr <= '0;
        end else begin
            v_sr <= {v_sr[DELAY-1:0], valid_in};
            s_sr <= {s_sr[DELAY-1:0], sync_in};
        end
    end

endmodule
