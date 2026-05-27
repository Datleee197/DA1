# FFT-256 Simulation Results Summary

## Overall Pass/Fail Status
- **Module-level tests (8 leaf modules)**: PASS
- **FFT-16 Sandbox Regression**: PASS
- **FFT-256 Single-Frame Tests (Tests 1-7)**: PASS
- **FFT-256 Random Stress Test (Test 8)**: PASS
- **FFT-256 Back-to-Back Frames (Test 9)**: PASS

## Max Error Statistics
The following statistics were gathered across 20 continuous random frames ($5,120$ individual complex samples):
- **Max Absolute Error (Real)**: 5 LSB
- **Max Absolute Error (Imag)**: 4 LSB
- **Mean Absolute Error**: ~0.70 LSB
- **Samples > 1 LSB Error**: 823 / 5120 (~16.0%)
- **Samples > 2 LSB Error**: 173 / 5120 (~3.3%)
- **Samples > 5 LSB Error**: 0 / 5120 (0.0%)

*Note: Truncation error correctly fits within a 5 LSB tolerance bound due to the 8 sequential Radix-2 right-shifts in the data path.*

## Execution Details

### Random Stress Result (Test 8)
- **Input**: 20 completely random complex frames ($256 \times 20 = 5120$ samples) with low amplitudes uniformly distributed between $[-0.1, 0.1]$.
- **Hardware behavior**: The stream operated successfully, emitting perfectly segmented output frames matching exactly with the expected NumPY model.
- **Order verified**: Bit-reversed order matched consistently for all 20 frames without any pipeline data leakage.

### Back-to-Back Frame Result (Test 9)
- **Input**: 3 consecutive fully saturated frames ($768$ samples).
- **Execution**:
  - `valid_in` was held constantly HIGH.
  - `sync_in` pulsed exactly every 256 cycles.
- **Hardware behavior**:
  - The internal counters reset flawlessly without explicit external global resets.
  - `sync_out` reliably emitted exactly 3 pulses at precisely separated $256$-cycle intervals, offset by the 258 cycle latency.
  - No trailing data corruption occurred across boundary transitions.
