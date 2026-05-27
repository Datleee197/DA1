// sdf_bf2ii_stage.sv
// Radix-2² SDF BF2II stage.
// Similar to BF2I, but during fill phase (phase_sel=0) the output
// passes through trivial_rotator before being forwarded.
//
// Uses: butterfly_radix2_scaled, trivial_rotator, sdf_feedback_delay.
// No CMUL.  No internal counter.  phase_sel and rot_sel are external.
//
// Behavior:
//   phase_sel == 0 (fill):
//       delay_write_in = din
//       dout = trivial_rotator(delay_out, rot_sel)
//
//   phase_sel == 1 (compute):
//       a = delay_out, b = din
//       y0 = (a+b)>>>1,  y1 = (a-b)>>>1
//       delay_write_in = y1
//       dout = y0
//
// dout is combinational (no output register).
// valid_out / sync_out delayed by DELAY cycles (DELAY+1-stage SR,
// combinational output, same method as sdf_bf2i_stage).

module sdf_bf2ii_stage #(
    parameter int DATA_W = 16,
    parameter int DELAY  = 4
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      valid_in,
    input  logic                      sync_in,
    input  logic                      phase_sel,   // 0 = fill, 1 = compute
    input  logic [1:0]                rot_sel,     // trivial rotation selector
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
    logic signed [DATA_W-1:0] rot_out_re, rot_out_im;

    // ----------------------------------------------------------------
    // Trivial rotator — purely combinational
    // Applied to din BEFORE the butterfly to compute A - jB
    // ----------------------------------------------------------------
    trivial_rotator #(.DATA_W(DATA_W)) u_rot (
        .rot_sel (rot_sel),
        .in_re   (din_re),
        .in_im   (din_im),
        .out_re  (rot_out_re),
        .out_im  (rot_out_im)
    );

    // ----------------------------------------------------------------
    // Butterfly — purely combinational
    // a = delay_out (stored sample), b = rot_out (current input rotated)
    // ----------------------------------------------------------------
    butterfly_radix2_scaled #(.DATA_W(DATA_W)) u_bf (
        .a_re  (delay_out_re),
        .a_im  (delay_out_im),
        .b_re  (rot_out_re),
        .b_im  (rot_out_im),
        .y0_re (y0_re),
        .y0_im (y0_im),
        .y1_re (y1_re),
        .y1_im (y1_im)
    );

    // ----------------------------------------------------------------
    // Feedback mux — selects what is written into the delay SR
    //   fill    (phase_sel=0): store incoming sample (unrotated? No, it should be rotated? 
    //   Wait! If it is stored, it should be unrotated so that it can be used as 'a' later!)
    // ----------------------------------------------------------------
    assign delay_in_re = phase_sel ? y1_re : din_re;
    assign delay_in_im = phase_sel ? y1_im : din_im;

    // ----------------------------------------------------------------
    // Output mux — combinational, no output register
    //   fill    (phase_sel=0): delay output
    //   compute (phase_sel=1): butterfly sum y0
    // ----------------------------------------------------------------
    assign dout_re = phase_sel ? y0_re : delay_out_re;
    assign dout_im = phase_sel ? y0_im : delay_out_im;

    // ----------------------------------------------------------------
    // Feedback delay — sdf_feedback_delay (combinational output)
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
    // Same method as sdf_bf2i_stage.
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
