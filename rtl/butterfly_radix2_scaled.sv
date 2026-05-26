// butterfly_radix2_scaled.sv
// Scaled Radix-2 butterfly: y0 = (a+b)>>>1, y1 = (a-b)>>>1.
// Applied independently to real and imaginary parts.
// Pure combinational — no clock, no reset.
// Sign-extends inputs to DATA_W+1 before add/sub.
// Uses arithmetic right shift (>>>). No saturation.

module butterfly_radix2_scaled #(
    parameter int DATA_W = 16
)(
    input  logic signed [DATA_W-1:0] a_re, a_im,  // delayed sample
    input  logic signed [DATA_W-1:0] b_re, b_im,  // current sample
    output logic signed [DATA_W-1:0] y0_re, y0_im, // scaled sum
    output logic signed [DATA_W-1:0] y1_re, y1_im  // scaled difference
);

    // Extended-width intermediates
    logic signed [DATA_W:0] sum_re, sum_im, diff_re, diff_im;

    always_comb begin
        // Sign-extend and add/subtract
        sum_re  = {a_re[DATA_W-1], a_re} + {b_re[DATA_W-1], b_re};
        sum_im  = {a_im[DATA_W-1], a_im} + {b_im[DATA_W-1], b_im};
        diff_re = {a_re[DATA_W-1], a_re} - {b_re[DATA_W-1], b_re};
        diff_im = {a_im[DATA_W-1], a_im} - {b_im[DATA_W-1], b_im};

        // Arithmetic right shift by 1, then truncate to DATA_W
        y0_re = (sum_re  >>> 1);
        y0_im = (sum_im  >>> 1);
        y1_re = (diff_re >>> 1);
        y1_im = (diff_im >>> 1);
    end

endmodule
