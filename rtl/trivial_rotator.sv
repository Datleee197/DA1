// trivial_rotator.sv
// Multiplier-free complex rotation by {1, -j, -1, j}.
// Pure combinational — no clock, no reset.

module trivial_rotator #(
    parameter int DATA_W = 16
)(
    input  logic [1:0]               rot_sel,
    input  logic signed [DATA_W-1:0] in_re,
    input  logic signed [DATA_W-1:0] in_im,
    output logic signed [DATA_W-1:0] out_re,
    output logic signed [DATA_W-1:0] out_im
);

    always_comb begin
        case (rot_sel)
            2'd0: begin  // * 1
                out_re =  in_re;
                out_im =  in_im;
            end
            2'd1: begin  // * (-j)
                out_re =  in_im;
                out_im = -in_re;
            end
            2'd2: begin  // * (-1)
                out_re = -in_re;
                out_im = -in_im;
            end
            2'd3: begin  // * j
                out_re = -in_im;
                out_im =  in_re;
            end
            default: begin
                out_re = in_re;
                out_im = in_im;
            end
        endcase
    end

endmodule
