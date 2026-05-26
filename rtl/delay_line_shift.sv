// delay_line_shift.sv
// Shift-register delay line of depth DELAY.
// Delays data (re, im), valid, and sync together by exactly DELAY clock cycles.
// Shifts every rising clock edge unconditionally.
//
// Implementation: uses (DELAY) flip-flop stages in a shift chain.
// Output is registered — the input at posedge N appears at output after posedge N+DELAY.

module delay_line_shift #(
    parameter int DATA_W = 16,
    parameter int DELAY  = 1
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

    generate
        if (DELAY == 0) begin : gen_passthrough
            assign dout_re   = din_re;
            assign dout_im   = din_im;
            assign valid_out = valid_in;
            assign sync_out  = sync_in;
        end else begin : gen_delay
            // We need exactly DELAY cycles of latency.
            // A chain of D+1 registers where sr[0]=input, output=sr[D]
            // gives D cycles (input latched at edge 0, appears at sr[D] at edge D).
            //
            // Use DELAY+1 entries: sr[0] is loaded from input,
            // sr[i] <= sr[i-1], output = sr[DELAY].
            // But that uses DELAY+1 registers for DELAY delay.
            //
            // Alternative: Use DELAY entries but output from a registered port.
            // Actually simplest: store in an array of DELAY depth.
            // sr[0] <= din; sr[i] <= sr[i-1]; output <= sr[DELAY-1] (registered output).
            // This gives: din → sr[0] (edge 0) → sr[1] (edge 1) → ... → sr[DELAY-1] (edge DELAY-1) → output (edge DELAY).
            // Total: DELAY cycles. ✓

            logic signed [DATA_W-1:0] sr_re  [0:DELAY-1];
            logic signed [DATA_W-1:0] sr_im  [0:DELAY-1];
            logic                     sr_v   [0:DELAY-1];
            logic                     sr_s   [0:DELAY-1];

            integer i;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (i = 0; i < DELAY; i = i + 1) begin
                        sr_re[i] <= '0;
                        sr_im[i] <= '0;
                        sr_v[i]  <= 1'b0;
                        sr_s[i]  <= 1'b0;
                    end
                    dout_re   <= '0;
                    dout_im   <= '0;
                    valid_out <= 1'b0;
                    sync_out  <= 1'b0;
                end else begin
                    // Shift chain
                    sr_re[0] <= din_re;
                    sr_im[0] <= din_im;
                    sr_v[0]  <= valid_in;
                    sr_s[0]  <= sync_in;
                    for (i = 1; i < DELAY; i = i + 1) begin
                        sr_re[i] <= sr_re[i-1];
                        sr_im[i] <= sr_im[i-1];
                        sr_v[i]  <= sr_v[i-1];
                        sr_s[i]  <= sr_s[i-1];
                    end
                    // Registered output — adds the final stage of delay
                    dout_re   <= sr_re[DELAY-1];
                    dout_im   <= sr_im[DELAY-1];
                    valid_out <= sr_v[DELAY-1];
                    sync_out  <= sr_s[DELAY-1];
                end
            end
        end
    endgenerate

endmodule
