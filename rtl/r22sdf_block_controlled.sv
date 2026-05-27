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
    logic [CNT_W-1:0] current_cnt;

    // By combining the register state and sync_in, we get a counter that is 
    // exactly 0 during the cycle that sync_in is asserted, without delaying 
    // the count progression.
    assign current_cnt = (valid_in && sync_in) ? '0 : cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= '0;
        else if (valid_in) begin
            if (sync_in)
                cnt <= CNT_W'(1);
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

    assign phase_sel_i  = current_cnt[LOG2_DI];
    assign phase_sel_ii = current_cnt[LOG2_DII];
    // With rotator applied to din before BF2II, we need rotation=1 (-j) when the delayed difference (y1) is arriving.
    // y1 from BF2I emerges when phase_sel_i == 0!
    assign rot_sel      = {1'b0, ~phase_sel_i};

    generate
        if (HAS_CMUL) begin : gen_tw
            localparam int LAT_NOCMUL = DELAY_I + DELAY_II;
            
            logic [LAT_NOCMUL-1:0] val_del;
            logic [LAT_NOCMUL-1:0] syn_del;
            
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    val_del <= '0;
                    syn_del <= '0;
                end else begin
                    val_del <= {val_del[LAT_NOCMUL-2:0], valid_in};
                    syn_del <= {syn_del[LAT_NOCMUL-2:0], sync_in};
                end
            end
            
            logic cmul_valid;
            logic cmul_sync;
            assign cmul_valid = val_del[LAT_NOCMUL-1];
            assign cmul_sync  = syn_del[LAT_NOCMUL-1];
            
            localparam int M = 4 * DELAY_II;
            localparam int LOG2_M = $clog2(M);
            logic [LOG2_M-1:0] cmul_idx;
            logic [LOG2_M-1:0] current_idx;
            
            always_comb begin
                if (cmul_sync)
                    current_idx = '0;
                else
                    current_idx = cmul_idx + 1'b1;
            end
            
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cmul_idx <= '0;
                end else if (cmul_valid) begin
                    cmul_idx <= current_idx;
                end
            end
            
            logic [LOG2_DII-1:0] n3;
            logic [1:0] q;
            assign n3 = current_idx[LOG2_DII-1:0];
            assign q  = current_idx[LOG2_DII+1:LOG2_DII];
            
            logic [TW_ADDR_W-1:0] tw_addr_comb;
            always_comb begin
                case (q)
                    // q=0: X_{4k}   -> W^0
                    2'd0: tw_addr_comb = '0;
                    // q=1: X_{4k+2} -> W^{2n}
                    2'd1: tw_addr_comb = TW_ADDR_W'(n3 << 1);
                    // q=2: X_{4k+1} -> W^n
                    2'd2: tw_addr_comb = TW_ADDR_W'(n3);
                    // q=3: X_{4k+3} -> W^{3n}
                    2'd3: tw_addr_comb = TW_ADDR_W'((n3 << 1) + n3);
                endcase
            end
            
            assign tw_addr = tw_addr_comb;
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
