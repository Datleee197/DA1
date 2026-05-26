// complex_multiplier_q15.sv
// 1-cycle registered complex multiplier for Q1.15 fixed-point.
//
// y_re = z_re*tw_re - z_im*tw_im
// y_im = z_re*tw_im + z_im*tw_re
//
// Products are 2*DATA_W bits. Accumulators are 2*DATA_W+1 bits.
// Result: arithmetic right shift by (DATA_W-1), truncate to DATA_W.
// No saturation — two's-complement wrap-around.

module complex_multiplier_q15 #(
    parameter int DATA_W = 16
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      valid_in,
    input  logic                      sync_in,
    input  logic signed [DATA_W-1:0]  z_re,
    input  logic signed [DATA_W-1:0]  z_im,
    input  logic signed [DATA_W-1:0]  tw_re,
    input  logic signed [DATA_W-1:0]  tw_im,
    output logic                      valid_out,
    output logic                      sync_out,
    output logic signed [DATA_W-1:0]  y_re,
    output logic signed [DATA_W-1:0]  y_im
);

    localparam int PROD_W = 2 * DATA_W;     // 32 bits
    localparam int ACC_W  = PROD_W + 1;     // 33 bits
    localparam int SHIFT  = DATA_W - 1;     // 15

    // Combinational products and accumulators
    logic signed [PROD_W-1:0] p_rr, p_ii, p_ri, p_ir;
    logic signed [ACC_W-1:0]  acc_re, acc_im;

    always_comb begin
        p_rr   = z_re * tw_re;
        p_ii   = z_im * tw_im;
        p_ri   = z_re * tw_im;
        p_ir   = z_im * tw_re;
        acc_re = {p_rr[PROD_W-1], p_rr} - {p_ii[PROD_W-1], p_ii};
        acc_im = {p_ri[PROD_W-1], p_ri} + {p_ir[PROD_W-1], p_ir};
    end

    // 1-cycle output register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_re      <= '0;
            y_im      <= '0;
            valid_out <= 1'b0;
            sync_out  <= 1'b0;
        end else begin
            valid_out <= valid_in;
            sync_out  <= sync_in;
            y_re      <= (acc_re >>> SHIFT);
            y_im      <= (acc_im >>> SHIFT);
        end
    end

endmodule
