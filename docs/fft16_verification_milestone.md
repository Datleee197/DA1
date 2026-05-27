# FFT-16 Radix-2² SDF Verification Milestone

## 1. Files Changed
The following files were modified during the audit to finalize verification:
- `rtl/sdf_bf2i_stage.sv`
- `rtl/sdf_bf2ii_stage.sv`
- `rtl/r22sdf_block_controlled.sv`
- `sim/tb_sdf_bf2i_stage.sv`
- `sim/tb_sdf_bf2ii_stage.sv`
- `sim/tb_r22sdf_block.sv`
- `sim/tb_r22sdf_block_controlled.sv`
- `sim/tb_fft16_r22sdf_top.sv`
- `scripts/golden_fft16.py`

*(Note: The core modules `trivial_rotator.sv`, `butterfly_radix2_scaled.sv`, `complex_multiplier_q15.sv`, `delay_line_shift.sv`, `sdf_feedback_delay.sv`, `twiddle_rom.sv`, and `r22sdf_block.sv` were verified in prior regression runs and NOT modified during this final audit phase).*

## 2. Corrected Valid/Sync Latency Formula
The correct propagation latency of an `r22sdf_block` is strictly the sum of its internal delay elements, with an extra cycle added only if the complex multiplier is instantiated:
- **Without CMUL:** `LAT_NOCMUL = DELAY_I + DELAY_II`
- **With CMUL:** `LAT_CMUL = DELAY_I + DELAY_II + 1`

## 3. FFT-16 Total Latency
For the complete FFT-16 cascading two blocks:
- **Block 0 (Has CMUL):** $8 (\text{BF2I}) + 4 (\text{BF2II}) + 1 (\text{CMUL}) = 13$ cycles.
- **Block 1 (No CMUL):** $2 (\text{BF2I}) + 1 (\text{BF2II}) = 3$ cycles.
- **Total Pipeline Latency:** $13 + 3 = 16$ cycles exactly.
- *Data input at cycle 0 begins emerging accurately at cycle 16.*

## 4. Final Control Equations

### Rotator Selection
```systemverilog
assign rot_sel = {1'b0, ~phase_sel_i};
```
**Explanation:** The trivial rotator applies $-j$ (which corresponds to `rot_sel = 1`) precisely when `~phase_sel_i` is true. This aligns with the delayed difference (`y1`) emerging from the `sdf_bf2i_stage`, perfectly satisfying the mathematical requirement of the R2²SDF architecture.

### Twiddle Address Generation
```systemverilog
assign current_cnt = (valid_in && sync_in) ? '0 : cnt;
assign phase_sel_i  = current_cnt[LOG2_DI];
assign phase_sel_ii = current_cnt[LOG2_DII];

assign cmul_idx = (cmul_sync) ? '0 : (cmul_idx + 1);
assign n3 = cmul_idx[LOG2_DII-1:0];
assign q  = cmul_idx[LOG2_DII+1:LOG2_DII];

// Twiddle Address
always_comb begin
    case (q)
        2'd0: tw_addr_comb = '0;                       // q=0: X_{4k}   -> W^0
        2'd1: tw_addr_comb = TW_ADDR_W'(n3 << 1);      // q=1: X_{4k+2} -> W^{2n}
        2'd2: tw_addr_comb = TW_ADDR_W'(n3);           // q=2: X_{4k+1} -> W^n
        2'd3: tw_addr_comb = TW_ADDR_W'((n3 << 1) + n3); // q=3: X_{4k+3} -> W^{3n}
    endcase
end
assign tw_addr = tw_addr_comb;
```

## 5. Explanation of q=1 / q=2 Twiddle Swap
During development, the twiddle multipliers for `q=1` and `q=2` were inadvertently swapped. A mathematical trace of the R2²SDF structure reveals that the frequency subsequences emerge in the exact order: $X_{4k}$ (`q=0`), $X_{4k+2}$ (`q=1`), $X_{4k+1}$ (`q=2`), and $X_{4k+3}$ (`q=3`). 
Consequently, the required twiddle exponents are $0$, $2n$, $n$, and $3n$ respectively. 
We corrected the assignment so that `q=1` maps to $W^{2n}$ (via `n3 << 1`) and `q=2` maps to $W^n$ (via `n3`).

## 6. Explanation of `current_cnt` Combinational Bypass
Using a fully registered synchronous reset (`cnt <= 1`) during `sync_in` caused the control logic to misread the phase index for the very first sample of a block (it saw the wrapping previous value, e.g., 13, instead of 0).
By introducing a combinational bypass:
```systemverilog
assign current_cnt = (valid_in && sync_in) ? '0 : cnt;
```
The logic can evaluate index `0` precisely at the instant `sync_in` is asserted, cleanly realigning the block boundaries without disrupting pipelined values already inside the stage.

## 7. Native Output Order Detected
Empirical testing on non-degenerate data mathematically proved that the native sequence output by the hardware is strictly **BIT-REVERSED order**.

## 8. Test Vectors Used & Results
| Test | Condition | Verified Output Order | Status |
|---|---|---|---|
| 1 | All Zeros | Natural / BR | **PASS** |
| 2 | Impulse ($x[0]=1, x[k]=0$) | Natural / BR | **PASS** |
| 3 | DC Constant ($x[k]=1$) | Natural / BR | **PASS** |
| 4 | Single Tone (Bin 1) | **Bit-Reversed** | **PASS** |
| 5 | Single Tone (Bin 3) | **Bit-Reversed** | **PASS** |
| 6 | Uniform Random Complex | **Bit-Reversed** | **PASS** |

**Summary:** The FFT-16 R2²SDF block wrapper and top-level architecture are fully cycle-accurate, bit-accurate against the python `numpy.fft` golden reference, and ready for FFT-256 scaling.
