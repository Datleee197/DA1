# RTL Agent Brief — FFT-256 Radix-2² SDF

## 1. Goal

Implement a streaming FFT-256 hardware accelerator based on the **Radix-2² Single-path Delay Feedback** architecture, abbreviated as **R2²SDF**.

The design must follow the architecture described in Chapter 5 of the report.

Core requirements:

- Algorithm: Radix-2² DIF FFT.
- FFT size: `N = 256`.
- Data format: complex signed Q1.15.
- Real part width: `DATA_W = 16` bits.
- Imaginary part width: `DATA_W = 16` bits.
- Input throughput target: one complex sample per clock after the pipeline is filled.
- Architecture: streaming single-path datapath with delay-feedback.
- Number of Radix-2² blocks: `log4(256) = 4`.
- Number of full complex multipliers: `log4(256) - 1 = 3`.
- Delay sequence: `128, 64, 32, 16, 8, 4, 2, 1`.
- Total complex delay memory: `255` complex samples.

Do **not** replace this with a behavioral FFT, memory-based batch FFT, direct DFT, iterative FFT, generic Radix-2 FFT, or generic Radix-4 FFT. The target is a real streaming RTL implementation that preserves the R2²SDF data schedule.

---

## 2. Top-level interface

Use SystemVerilog unless the repository is restricted to Verilog-2001.

Recommended top-level module:

```systemverilog
module fft256_r22sdf_top #(
    parameter int DATA_W = 16,
    parameter int N      = 256
)(
    input  logic clk,
    input  logic rst_n,

    // valid_in = 1 when din_re/din_im are valid.
    // sync_in = 1 for exactly one clock on the first sample of a 256-sample frame.
    input  logic valid_in,
    input  logic sync_in,
    input  logic signed [DATA_W-1:0] din_re,
    input  logic signed [DATA_W-1:0] din_im,

    // valid_out = 1 when dout_re/dout_im are valid.
    // sync_out = 1 for exactly one clock on the first output sample of a frame.
    output logic valid_out,
    output logic sync_out,
    output logic signed [DATA_W-1:0] dout_re,
    output logic signed [DATA_W-1:0] dout_im
);
```

### Streaming convention

The MVP does **not** need backpressure. Do not add `ready_in` or `ready_out` yet.

Initial assumptions:

- A new FFT frame starts when `sync_in == 1` and `valid_in == 1`.
- `sync_in` is asserted on the same clock as the first input sample of the frame.
- During one frame, `valid_in` stays high for 256 consecutive clocks.
- The global counter `cnt` resets to zero on `sync_in && valid_in`.
- `cnt` increments only when `valid_in == 1`.
- If a true AXI-Stream interface is needed later, add `ready` only after the base architecture passes functional verification.

---

## 3. Mandatory naming convention

Use these names consistently. Do not invent multiple names for the same concept.

### RTL signal names

| Name | Meaning |
|---|---|
| `DATA_W` | Width of each real/imaginary component. For Q1.15, `DATA_W = 16`. |
| `TW_W` | Twiddle coefficient width. Usually equal to `DATA_W`. |
| `N` | FFT size. For this project, `N = 256`. |
| `DELAY` | Delay-line depth of a given SDF stage. |
| `cnt` | Global 8-bit frame counter for FFT-256. |
| `phase_sel` | Fill/compute phase selection for an SDF stage. |
| `rot_sel` | 2-bit selector for the trivial rotation in BF2II. |
| `valid_in`, `valid_out` | Input/output validity flags. |
| `sync_in`, `sync_out` | Start-of-frame marker for input/output frames. |
| `din_re`, `din_im` | Top-level complex input. |
| `dout_re`, `dout_im` | Top-level complex output. |
| `tw_re_s0`, `tw_im_s0` | Twiddle coefficients for CMUL stage 0, corresponding to `W256`. |
| `tw_re_s1`, `tw_im_s1` | Twiddle coefficients for CMUL stage 1, corresponding to `W64`. |
| `tw_re_s2`, `tw_im_s2` | Twiddle coefficients for CMUL stage 2, corresponding to `W16`. |
| `a_re`, `a_im` | Delayed butterfly input. |
| `b_re`, `b_im` | Current butterfly input. |
| `y0_re`, `y0_im` | Scaled butterfly sum output. |
| `y1_re`, `y1_im` | Scaled butterfly difference output. |

Do not mix names such as `coef_rom`, `W_ROM`, `twiddle_mem`, and `tw_rom` if they refer to the same object. Pick one naming style and keep it across RTL, testbench, and documentation.

### Recommended source tree

```text
rtl/
  fft256_r22sdf_top.sv
  sdf_bf2i_stage.sv
  sdf_bf2ii_stage.sv
  butterfly_radix2_scaled.sv
  trivial_rotator.sv
  complex_multiplier_q15.sv
  delay_line_shift.sv
  twiddle_rom.sv
  control_unit_256.sv

sim/
  tb_trivial_rotator.sv
  tb_butterfly_radix2_scaled.sv
  tb_complex_multiplier_q15.sv
  tb_delay_line_shift.sv
  tb_sdf_stage_small.sv
  tb_fft256_r22sdf_top.sv

scripts/
  gen_twiddle_hex.py
  golden_fft256.py
  compare_fft_output.py
```

---

## 4. Overall FFT-256 datapath

The FFT-256 R2²SDF pipeline must follow this structure:

```text
Input
  -> BF2I(D=128)
  -> BF2II(D=64)
  -> CMUL(W256)
  -> BF2I(D=32)
  -> BF2II(D=16)
  -> CMUL(W64)
  -> BF2I(D=8)
  -> BF2II(D=4)
  -> CMUL(W16)
  -> BF2I(D=2)
  -> BF2II(D=1)
  -> Output
```

There are four Radix-2² blocks:

| Block | BF2I delay | BF2II delay | CMUL after block |
|---:|---:|---:|---|
| 0 | 128 | 64 | `W256` |
| 1 | 32 | 16 | `W64` |
| 2 | 8 | 4 | `W16` |
| 3 | 2 | 1 | No CMUL |

The last block does not need a full CMUL because the remaining DFT length is 4. The required rotations are trivial and can be handled by BF2II.

---

## 5. SDF stage behavior

Each SDF stage has a delay depth `D` and operates with a periodic schedule of `2*D` clocks.

Use one phase bit derived from `cnt`:

```systemverilog
phase_sel = cnt[PHASE_BIT];
```

For the MVP, use this convention:

- `phase_sel == 0`: fill phase / delayed-feedback output phase.
- `phase_sel == 1`: compute phase.

This convention must be verified by simulation. A one-clock phase error is enough to destroy the FFT result even when all arithmetic modules are correct.

### BF2I stage

BF2I has no twiddle or trivial rotation.

```text
If phase_sel == 0:
    delay_in  = stage_in
    stage_out = delay_out

If phase_sel == 1:
    a = delay_out
    b = stage_in
    y0 = (a + b) >>> 1
    y1 = (a - b) >>> 1
    stage_out = y0
    delay_in  = y1
```

### BF2II stage

BF2II is similar to BF2I, but the delayed feedback branch must pass through `trivial_rotator` before moving forward.

```text
If phase_sel == 0:
    delay_in  = stage_in
    stage_out = trivial_rotator(delay_out, rot_sel)

If phase_sel == 1:
    a = delay_out
    b = stage_in
    u0 = (a + b) >>> 1
    u1 = (a - b) >>> 1
    stage_out = u0
    delay_in  = u1
```

Important: This schedule must be proven with a small-stage testbench, for example `DELAY = 2` or `DELAY = 4`, before building the FFT-256 top module.

---

## 6. Scaled Radix-2 butterfly

For each real and imaginary component:

```text
y0 = (a + b) >>> 1
y1 = (a - b) >>> 1
```

Implementation requirements:

- Inputs are signed Q1.15.
- Sign-extend to `DATA_W + 1` before addition/subtraction.
- Use arithmetic right shift: `>>> 1`.
- Truncate back to `DATA_W` bits after scaling.
- Apply the same logic independently to the real and imaginary parts.
- Do not use logical right shift `>>` for signed values.

No saturation is required for the MVP unless it is explicitly added behind a parameter and also modeled in the golden reference.

---

## 7. Trivial rotator

`rot_sel` is a 2-bit selector corresponding to `q = k1 + 2*k2`.

| `rot_sel` | Coefficient | Mapping |
|---:|---|---|
| 0 | `1` | `out_re = in_re`, `out_im = in_im` |
| 1 | `-j` | `out_re = in_im`, `out_im = -in_re` |
| 2 | `-1` | `out_re = -in_re`, `out_im = -in_im` |
| 3 | `j` | `out_re = -in_im`, `out_im = in_re` |

Requirements:

- Pure combinational logic.
- Signed two's-complement arithmetic.
- No multiplier.
- No floating-point.
- No saturation for the MVP.

---

## 8. Complex multiplier Q1.15

Let:

```text
z = z_re + j*z_im
t = tw_re + j*tw_im
```

The complex multiplication is:

```text
y_re = z_re*tw_re - z_im*tw_im
y_im = z_re*tw_im + z_im*tw_re
```

Fixed-point requirements:

- Inputs are signed Q1.15.
- Q1.15 × Q1.15 produces Q2.30 intermediate products.
- Keep enough internal width for the product and add/subtract operations.
- Convert back to Q1.15 by arithmetic shifting right by `DATA_W - 1`, which is 15 for Q1.15.
- Use truncation for the MVP.
- Do not use rounding unless the Python golden model and testbench are updated to match it.

Do not use `real`, `shortreal`, `$sin`, `$cos`, or any floating-point arithmetic in synthesizable RTL.

---

## 9. Twiddle ROM

The twiddle coefficient is:

```text
T_M(q, r) = W_M^(q*r), q in {0, 1, 2, 3}
```

For FFT-256, use three ROM groups:

| Stage | Current DFT length `M` | `q` width | `r` width | ROM depth |
|---:|---:|---:|---:|---:|
| 0 | 256 | 2 | 6 | 256 |
| 1 | 64 | 2 | 4 | 64 |
| 2 | 16 | 2 | 2 | 16 |

Recommended address construction:

```systemverilog
addr_s0 = {q_s0, r_s0}; // q_s0 = cnt[7:6], r_s0 = cnt[5:0]
addr_s1 = {q_s1, r_s1}; // q_s1 = cnt[5:4], r_s1 = cnt[3:0]
addr_s2 = {q_s2, r_s2}; // q_s2 = cnt[3:2], r_s2 = cnt[1:0]
```

However, do not blindly use the current `cnt` at a CMUL input if the datapath before that CMUL has registered latency. The twiddle address and `rot_sel` must be delayed to match the data path.

The Python script `gen_twiddle_hex.py` must generate signed Q1.15 coefficients in one consistent format. Acceptable options:

Option A: one 32-bit word per line:

```text
{tw_re[15:0], tw_im[15:0]}
```

Option B: two separate files:

```text
tw_re.hex
tw_im.hex
```

Choose one format and keep it consistent across ROM, testbench, and documentation.

---

## 10. Global control counter

For FFT-256, `cnt` is 8 bits wide: `cnt[7:0]`.

| Delay `D` | Phase bit | Suggested `rot_sel` | Block |
|---:|---|---|---|
| 128 | `cnt[7]` | `cnt[7:6]` | BF2I block 0 |
| 64 | `cnt[6]` | `cnt[7:6]` | BF2II block 0 |
| 32 | `cnt[5]` | `cnt[5:4]` | BF2I block 1 |
| 16 | `cnt[4]` | `cnt[5:4]` | BF2II block 1 |
| 8 | `cnt[3]` | `cnt[3:2]` | BF2I block 2 |
| 4 | `cnt[2]` | `cnt[3:2]` | BF2II block 2 |
| 2 | `cnt[1]` | `cnt[1:0]` | BF2I block 3 |
| 1 | `cnt[0]` | `cnt[1:0]` | BF2II block 3 |

Rules:

- `cnt` increments only when `valid_in == 1`.
- `cnt` resets to zero on `sync_in && valid_in`.
- `cnt` wraps modulo 256.
- If any stage adds pipeline registers, the related control signals must be delayed by the same number of cycles.
- `valid_out` and `sync_out` must be aligned with the actual output data, not guessed.

---

## 11. Required testbenches

Do not build the full FFT top first. Build and verify from the bottom up.

### 11.1 `trivial_rotator` unit test

Test all four `rot_sel` cases with signed vectors such as:

- `1 + j2`
- `-3 + j4`
- `1000 - j2000`
- `-12000 - j7000`

Expected results must match bit-exactly.

### 11.2 `butterfly_radix2_scaled` unit test

Test:

- positive + positive,
- positive + negative,
- negative + negative,
- values close to the Q1.15 boundary,
- random small-amplitude signed values.

The testbench must verify both `y0` and `y1` for real and imaginary parts.

### 11.3 `complex_multiplier_q15` unit test

Compare with a Python golden model.

Required cases:

- `0.5 * 0.5`,
- multiplication by `1`,
- multiplication by `-1`,
- multiplication by `j`,
- multiplication by `-j`,
- random values in a safe range such as `[-0.8, 0.8]`.

Note: Q1.15 cannot exactly represent `+1.0`; the maximum positive value is `32767/32768`.

If truncation is used in RTL, the Python golden model must also truncate instead of round.

### 11.4 `delay_line_shift` unit test

For `D = 1, 2, 4, 8`, feed an increasing counter into the delay line. Output data, `valid_out`, and `sync_out` must appear exactly `D` clocks later.

No one-clock ambiguity is acceptable.

### 11.5 Small SDF stage test

Create a small SDF stage with `DELAY = 2` or `DELAY = 4`.

Dump and inspect:

- `phase_sel`,
- `delay_in`,
- `delay_out`,
- `stage_in`,
- `stage_out`,
- `valid_in`,
- `valid_out`,
- `sync_in`,
- `sync_out`.

Before proceeding, create a manual timing table with at least 12 clock cycles.

Required columns:

| Clock | Phase | Input sample | Delayed sample | Butterfly active | Forward output | Feedback write | valid_out | sync_out |
|---:|---|---|---|---|---|---|---|---|

The RTL waveform must match this table.

### 11.6 Full FFT-256 test

Minimum input vectors:

1. **All-zero input**: every output should be zero after pipeline latency.
2. **Impulse input**: `x[0] = 1`, all other samples zero. FFT output should be constant after total scaling.
3. **DC input**: all samples equal a small value, for example `0.25`. Only the DC bin should be large.
4. **Single complex tone**: `x[n] = exp(j*2*pi*m*n/N)` for `m = 1, 5, 17`. The peak should appear at the matching bin after output reorder.
5. **Random low-amplitude complex input**: compare against NumPy FFT after scaling and output reorder.

### Total scaling

Each Radix-2 butterfly shifts right by one bit. FFT-256 has 8 Radix-2 butterfly stages. Therefore, the total amplitude scale is:

```text
scale_total = 2^-8 = 1/256
```

If the golden FFT output is not divided by 256, the test will fail even if RTL is correct.

### Output order

DIF FFT with natural-order input usually produces bit-reversed or digit-reversed output. The golden model must reorder the expected output before comparison.

Do not declare the RTL wrong just because a single-tone peak does not appear at the natural-order index. First check the output ordering.

---

## 12. Python golden model requirements

Create `golden_fft256.py` with these features:

- Generate Q1.15 complex input vectors.
- Compute `numpy.fft.fft`.
- Apply the total scale factor `1/256`.
- Reorder the output to match the RTL output order.
- Quantize expected real and imaginary parts to signed Q1.15.
- Use the same truncation/wrap behavior as RTL.
- Export input vectors and expected output vectors as hex files.

Create `compare_fft_output.py` with these features:

- Read RTL output logs.
- Read expected output vectors.
- Compare real and imaginary parts.
- Allow a small tolerance only if justified by truncation or pipeline rounding differences.
- Print the first mismatch with index, expected value, actual value, and error.

---

## 13. Things the coding agent must not do

- Do not implement direct DFT in RTL.
- Do not store all 256 samples and compute FFT in a behavioral loop.
- Do not replace R2²SDF with iterative FFT, generic Radix-2 SDF, or generic Radix-4 SDF.
- Do not remove `valid_in`/`valid_out`.
- Do not remove `sync_in`/`sync_out`.
- Do not use floating-point arithmetic in synthesizable RTL.
- Do not use `real`, `shortreal`, `$sin`, `$cos`, or dynamic arrays in synthesizable RTL.
- Do not use division or modulo in timing-critical datapath/control logic.
- Do not optimize delay lines into BRAM for the MVP.
- Do not add backpressure before the base design passes.
- Do not compare RTL output with NumPy FFT before applying scale and output reorder.
- Do not hard-code `valid_out` latency without proving it from the actual datapath.
- Do not use several names for the same signal or module concept.

---

## 14. Acceptance criteria

The RTL project reaches MVP quality when:

1. All modules compile cleanly.
2. `trivial_rotator` passes bit-exact unit tests.
3. `butterfly_radix2_scaled` passes bit-exact unit tests.
4. `complex_multiplier_q15` matches the Python fixed-point golden model.
5. `delay_line_shift` delays data, valid, and sync by exactly `DELAY` clocks.
6. A small SDF stage passes the manual timing-table check.
7. The FFT-256 top can accept a full 256-sample frame with one complex sample per clock.
8. `valid_out` is asserted only when the output sample is valid.
9. `sync_out` is aligned with the first output sample of each frame.
10. Top-level FFT output matches NumPy FFT after:
    - total scale factor `1/256`,
    - Q1.15 quantization,
    - output reorder,
    - fixed-point truncation tolerance.
11. The waveform can be explained stage by stage: BF2I, BF2II, CMUL, delay line, `cnt`, `phase_sel`, `rot_sel`, twiddle address, `valid_out`, and `sync_out`.

---

## 15. Recommended implementation order

Use this exact order. Do not jump directly to the top-level FFT.

1. Define fixed-point helper functions in testbench/Python, not in synthesizable RTL unless needed.
2. Implement `trivial_rotator.sv`.
3. Implement and test `butterfly_radix2_scaled.sv`.
4. Implement and test `complex_multiplier_q15.sv`.
5. Implement and test `delay_line_shift.sv`.
6. Implement and test `sdf_bf2i_stage.sv` with parameter `DELAY`.
7. Implement and test `sdf_bf2ii_stage.sv` with parameter `DELAY` and `rot_sel`.
8. Create a small manual timing table for `DELAY = 4` and verify the RTL waveform.
9. Write `gen_twiddle_hex.py`.
10. Generate ROM files for `W256`, `W64`, and `W16`.
11. Implement `twiddle_rom.sv`.
12. Build block 0 and test it separately.
13. Build block 1 and test it separately.
14. Build block 2 and test it separately.
15. Build block 3 and test it separately.
16. Integrate `fft256_r22sdf_top.sv`.
17. Write `golden_fft256.py` and `compare_fft_output.py`.
18. Run all-zero, impulse, DC, single-tone, and random tests.
19. Only after functional correctness, consider BRAM delay lines, rounding, saturation, or true ready/valid backpressure.

---

## 16. Initial prompt to give the coding agent

Use this prompt before asking for code:

```md
You are an RTL design assistant. Your task is to implement a fixed-point FFT-256 hardware accelerator based on the R2²SDF architecture described in the attached Markdown spec and Chapter 5.

Important constraints:
- Do not implement a generic software-style FFT.
- Do not implement a memory-based batch FFT.
- Implement a streaming FFT architecture.
- Architecture: Radix-2² Single-path Delay Feedback, FFT size N = 256.
- Input order: natural order.
- Output order: digit-reversed / bit-reversed is acceptable.
- Data format: signed Q1.15, 16-bit real + 16-bit imaginary.
- Throughput target: 1 complex sample per clock after pipeline is filled.
- Use valid_in / valid_out.
- Use sync_in / sync_out to mark the start of a 256-sample frame.
- Use synchronous reset unless the existing repository requires otherwise.
- Scaling: right shift by 1 bit after every butterfly. Total FFT-256 scale factor is 1/256.
- Do not use floating-point arithmetic in RTL.
- Do not use division or modulo in timing-critical RTL logic.
- Twiddle factors must come from ROM or generated fixed-point coefficient files.

Before writing code, read the spec and produce:
1. module hierarchy,
2. signal naming convention,
3. control schedule,
4. testbench strategy,
5. risks that may cause wrong FFT output.

Do not write RTL code yet.
```

---

## 17. Prompt for incremental coding

Use this only after the agent produces a reasonable plan:

```md
Now implement the project incrementally.

Use SystemVerilog if the repository allows it. Otherwise use Verilog-2001.

Required module order:
1. trivial_rotator
2. butterfly_radix2_scaled
3. complex_multiplier_q15
4. delay_line_shift
5. sdf_bf2i_stage
6. sdf_bf2ii_stage
7. twiddle_rom
8. fft256_r22sdf_top
9. unit testbenches for each module
10. Python golden model and test vector generator

Rules:
- After each module, create a small self-checking testbench.
- Do not proceed to the next module until the current one passes simulation.
- Keep all module interfaces explicit: clk, rst_n, valid_in, sync_in, data_re_in, data_im_in, valid_out, sync_out, data_re_out, data_im_out.
- Use consistent names: DATA_W, TW_W, DELAY, cnt, phase_sel, rot_sel, tw_re, tw_im, y_re, y_im.
- Add comments explaining timing and latency.
- Do not change the architecture unless the spec is ambiguous. If ambiguous, stop and ask.
```

---

## 18. Debugging priorities

If the top-level FFT output is wrong, debug in this order:

1. Check total scaling: expected output must be divided by 256.
2. Check output order: bit-reversed/digit-reversed output may need reorder.
3. Check `sync_out` alignment.
4. Check `valid_out` latency.
5. Check `cnt` reset and wrap behavior.
6. Check `phase_sel` for each SDF stage.
7. Check whether `rot_sel` is delayed to match the data path.
8. Check whether twiddle ROM address is delayed to match the data path.
9. Check CMUL fixed-point truncation.
10. Check butterfly arithmetic shift and sign extension.

The most likely bug is not the complex multiplier. The most likely bug is a one-clock mismatch between data and control.

---

## 19. Final technical note

Do not optimize too early. The first version must be easy to inspect in waveforms, easy to explain in the report, and easy to compare against Python. Use shift-register delay lines first. Move long delay lines to BRAM only after functional correctness is proven.
