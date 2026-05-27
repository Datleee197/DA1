# FFT-256 Radix-2² SDF Hardware Accelerator

## Project Overview
This repository contains a streaming FFT-256 hardware accelerator implemented in SystemVerilog using the Radix-2² Single-path Delay Feedback (R2²SDF) architecture. Designed for Q1.15 fixed-point arithmetic, the accelerator sustains continuous pipeline operation while natively achieving theoretical limits on shift-register and complex multiplier utilization.

### Key Specifications
- **Transform Size**: 256 points
- **Architecture**: Radix-2² Single-path Delay Feedback (R2²SDF)
- **Data Format**: 16-bit Signed Fixed-Point (Q1.15)
- **Scale Factor**: $1/256$ (each of the 8 Radix-2 butterfly stages applies a $1/2$ shift to prevent bit-growth).
- **Latency**: 258 clock cycles
- **Output Order**: Bit-Reversed order
- **Throughput**: 1 complex sample per clock cycle

**STATUS:** FUNCTIONALLY VERIFIED BY RTL SIMULATION

## Quick Start & Running Simulations
The verification flow uses Python/NumPy for golden model generation, and Icarus Verilog (`iverilog`) for compilation and simulation.

### 1. Run Module-level Tests
To test individual leaf components (e.g., butterflies, delay lines, generic complex multipliers):
```bash
bash scripts/run_module_tests.sh
```

### 2. Run FFT-16 Test (Sandbox)
The FFT-16 sandbox is used to debug block integration at a smaller latency footprint (16 cycles).
```bash
# Generate dynamic test vectors
python scripts/golden_fft16.py
# Compile and simulate
iverilog -g2012 -o sim/fft16.vvp rtl/*.sv sim/tb_fft16_r22sdf_top.sv
vvp sim/fft16.vvp
```

### 3. Run FFT-256 Test (Full Architecture)
The full integration suite checks edge cases, impulse responses, frequency tones, randomized stress arrays, and back-to-back streaming boundaries.
```bash
# Generate 9 distinct dynamic test sets
python scripts/golden_fft256.py
# Compile and simulate
iverilog -g2012 -o sim/fft256.vvp rtl/*.sv sim/tb_fft256_r22sdf_top.sv
vvp sim/fft256.vvp
```

## How to Regenerate Twiddle ROMs
The Twiddle factors for the ROM blocks are dynamically generated via a Python script. If parameter changes occur, execute:
```bash
python scripts/generate_twiddles.py
```
This script populates the `rom/` directory with `tw256.hex`, `tw64.hex`, and `tw16.hex`.

## How to Open GTKWave
To view the generated `.vcd` files (e.g., after running the FFT-256 test), open GTKWave:
```bash
gtkwave tb_fft256_r22sdf_top.vcd
```

## Vietnamese Documentation / Tài Liệu Tiếng Việt
Dự án cung cấp bộ tài liệu giải thích chi tiết bằng tiếng Việt trong thư mục `docs/`:
1. [Tổng Quan Dự Án](docs/00_tong_quan_du_an.md)
2. [Cấu Trúc Thư Mục](docs/01_cau_truc_thu_muc.md)
3. [Giải Thích Từng RTL Block](docs/02_giai_thich_tung_block.md)
4. [Liên Kết Cấp Hệ Thống](docs/03_lien_ket_he_thong.md)
5. [Số Thực Dấu Phẩy Tĩnh & Phân Tích Sai Số](docs/04_fixed_point_va_sai_so.md)
6. [Hướng Dẫn Chạy Simulation](docs/05_huong_dan_chay_simulation.md)
7. [Hướng Dẫn Dùng GTKWave](docs/06_huong_dan_gtkwave.md)
8. [Tổng Kết Quá Trình Verification](docs/07_verification_summary_vi.md)
