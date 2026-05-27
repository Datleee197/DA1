# SDF Pipeline Valid/Sync Alignment Bug Resolution

## 1. Exact Bug Explanation
The bug resided in how the valid and sync shift registers (`v_sr` and `s_sr`) were declared in both `sdf_bf2i_stage.sv` and `sdf_bf2ii_stage.sv`. 

Originally, the declaration was:
```systemverilog
logic [DELAY:0] v_sr;
assign valid_out = v_sr[DELAY];
```
In SystemVerilog, `[DELAY:0]` creates a vector of `DELAY+1` bits. Because the shift register shifts by 1 bit per clock cycle, it took `DELAY+1` cycles for `valid_in` to propagate to `valid_out`.

Conversely, the data delay line `sdf_feedback_delay` uses `sr_re[0]` through `sr_re[DELAY-1]`, meaning the data propagates to the combinational output after exactly `DELAY` cycles.

This `DELAY` vs `DELAY+1` mismatch caused the `valid_out` signal to assert one cycle late per stage, accumulating a 2-cycle misalignment across an `r22sdf_block`.

The bug was previously hidden in simulation by a classic testbench race condition: the stimulus inputs were assigned using blocking assignments (`=`) exactly on the active clock edge. Because Icarus Verilog evaluated the testbench before the `always_ff` blocks, the shift register sampled the updated `valid_in` combinationally on the very first cycle, inadvertently shortening the simulated valid delay by 1 cycle and masking the bug.

## 2. Files Changed
- `rtl/sdf_bf2i_stage.sv` (changed `v_sr` and `s_sr` width to `[DELAY-1:0]`)
- `rtl/sdf_bf2ii_stage.sv` (changed `v_sr` and `s_sr` width to `[DELAY-1:0]`)
- `sim/tb_sdf_bf2i_stage.sv` (fixed stimulus race condition using non-blocking `<=`)
- `sim/tb_sdf_bf2ii_stage.sv` (fixed stimulus race condition using non-blocking `<=`)
- `sim/tb_r22sdf_block.sv` (fixed race condition, updated `LAT_NOCMUL` and `LAT_CMUL` expectations)
- `sim/tb_r22sdf_block_controlled.sv` (fixed race condition)

## 3. Corrected Latency Formula
With the alignment fixed, the block latency is strictly the sum of the delay components:
- **Without CMUL:** `LAT_NOCMUL = DELAY_I + DELAY_II`
- **With CMUL:** `LAT_CMUL = DELAY_I + DELAY_II + 1` (the +1 is from the registered CMUL output)

## 4. Corrected Timing Table (FFT-16 Block 0)
Using the corrected modules, where `DELAY_I = 8` and `DELAY_II = 4` and `HAS_CMUL = 1`. 
Data and valid now perfectly align at cycle `8 + 4 = 12` (before CMUL). Because CMUL is enabled, the final block output appears at cycle `13`.

| cyc | cnt | ph_i | ph_ii | rot_sel {ii,i} | BF2II v (cyc 12) | Block v_out (cyc 13) | Block s_out | CMUL output |
|:---:|:---:|:----:|:-----:|:--------------:|:----------------:|:--------------------:|:-----------:|:------------|
| 0   | 0   | 0    | 0     | 0              | 0                | 0                    | 0           | -           |
| ... |     |      |       |                |                  |                      |             |             |
| 11  | 11  | 1    | 0     | 1              | 0                | 0                    | 0           | -           |
| 12  | 12  | 1    | 1     | 3              | **1**            | 0                    | 0           | -           |
| 13  | 13  | 1    | 1     | 3              | **1**            | **1**                | **1**       | **7**       |
| 14  | 14  | 1    | 1     | 3              | 1                | 1                    | 0           | 8           |
| 15  | 15  | 1    | 1     | 3              | 1                | 1                    | 0           | 9           |

*Note: The first FFT sample emerges from the entire block precisely at cycle 13, completely resolving the lost-data issue.*

## 5. Regression Results
Running all 10 module testbenches after the fix yields 0 failures:
- `trivial_rotator`: PASS
- `butterfly_radix2_scaled`: PASS
- `complex_multiplier_q15`: PASS
- `delay_line_shift`: PASS
- `sdf_feedback_delay`: PASS
- `sdf_bf2i_stage`: PASS
- `sdf_bf2ii_stage`: PASS
- `twiddle_rom`: PASS
- `r22sdf_block`: PASS
- `r22sdf_block_controlled`: PASS
