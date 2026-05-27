// r22sdf_block_controlled.sv
// Wrapper: local control generator + verified r22sdf_block.
//
// Generates phase_sel_i, phase_sel_ii, rot_sel, tw_addr from a
// local sample counter that increments on valid_in and resets on
// sync_in && valid_in.
//
// Bit extraction (all DELAY values must be powers of 2):
//   phase_sel_i  = cnt[$clog2(DELAY_I)]
//   phase_sel_ii = cnt[$clog2(DELAY_II)]
//   rot_sel      = {cnt[$clog2(DELAY_I)], cnt[$clog2(DELAY_II)]}
//   tw_addr      = cnt[TW_ADDR_W-1:0]   when HAS_CMUL=1
//                = 0                      when HAS_CMUL=0

module r22sdf_block_controlled #(
    parameter int DATA_W    = 16,
    parameter int DELAY_I   = 4,
    parameter int DELAY_II  = 2,
    parameter int HAS_CMUL  = 1,
    parameter int TW_ADDR_W = 8,
    parameter     TW_FILE   = "rom/tw256.hex"
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
    // Counter parameters
    // ----------------------------------------------------------------
    localparam int LOG2_DI     = $clog2(DELAY_I);   // e.g. 2 for DELAY_I=4
    localparam int LOG2_DII    = $clog2(DELAY_II);  // e.g. 1 for DELAY_II=2
    localparam int CNT_PHASE_W = LOG2_DI + 1;       // bits for phase control
    localparam int CNT_W       = (TW_ADDR_W > CNT_PHASE_W) ? TW_ADDR_W
                                                            : CNT_PHASE_W;

    // ----------------------------------------------------------------
    // Local sample counter
    // Increments on valid_in.  Resets to 0 on sync_in && valid_in.
    // ----------------------------------------------------------------
    logic [CNT_W-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= '0;
        else if (valid_in) begin
            if (sync_in)
                cnt <= '0;
            else
                cnt <= cnt + 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Control signal generation
    // ----------------------------------------------------------------
    logic                      phase_sel_i;
    logic                      phase_sel_ii;
    logic [1:0]                rot_sel;
    logic [TW_ADDR_W-1:0]      tw_addr;

    assign phase_sel_i  = cnt[LOG2_DI];
    assign phase_sel_ii = cnt[LOG2_DII];
    assign rot_sel      = {cnt[LOG2_DI], cnt[LOG2_DII]};

    generate
        if (HAS_CMUL) begin : gen_tw
            assign tw_addr = cnt[TW_ADDR_W-1:0];
        end else begin : gen_no_tw
            assign tw_addr = '0;
        end
    endgenerate

    // ----------------------------------------------------------------
    // Instantiate verified r22sdf_block
    // ----------------------------------------------------------------
    r22sdf_block #(
        .DATA_W    (DATA_W),
        .DELAY_I   (DELAY_I),
        .DELAY_II  (DELAY_II),
        .HAS_CMUL  (HAS_CMUL),
        .TW_ADDR_W (TW_ADDR_W),
        .TW_FILE   (TW_FILE)
    ) u_block (
        .clk         (clk),
        .rst_n       (rst_n),
        .valid_in    (valid_in),
        .sync_in     (sync_in),
        .phase_sel_i (phase_sel_i),
        .phase_sel_ii(phase_sel_ii),
        .rot_sel     (rot_sel),
        .tw_addr     (tw_addr),
        .din_re      (din_re),
        .din_im      (din_im),
        .valid_out   (valid_out),
        .sync_out    (sync_out),
        .dout_re     (dout_re),
        .dout_im     (dout_im)
    );

endmodule
