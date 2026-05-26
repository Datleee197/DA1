// sdf_feedback_delay.sv
// Shift-register delay line with combinational output for SDF feedback paths.
//
// Unlike delay_line_shift (which has a registered output), this module
// provides a combinational read from sr[DELAY-1].  This avoids the
// one-clock skew at phase boundaries when placed in a feedback loop.
//
// Shifts only when en == 1.
// No valid/sync.  No RAM.  No circular buffer.

module sdf_feedback_delay #(
    parameter int DATA_W = 16,
    parameter int DELAY  = 4
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      en,
    input  logic signed [DATA_W-1:0]  din_re,
    input  logic signed [DATA_W-1:0]  din_im,
    output logic signed [DATA_W-1:0]  dout_re,
    output logic signed [DATA_W-1:0]  dout_im
);

    // Shift register: DELAY stages, combinational output
    logic signed [DATA_W-1:0] sr_re [0:DELAY-1];
    logic signed [DATA_W-1:0] sr_im [0:DELAY-1];

    assign dout_re = sr_re[DELAY-1];
    assign dout_im = sr_im[DELAY-1];

    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DELAY; i = i + 1) begin
                sr_re[i] <= '0;
                sr_im[i] <= '0;
            end
        end else if (en) begin
            sr_re[0] <= din_re;
            sr_im[0] <= din_im;
            for (i = 1; i < DELAY; i = i + 1) begin
                sr_re[i] <= sr_re[i-1];
                sr_im[i] <= sr_im[i-1];
            end
        end
    end

endmodule
