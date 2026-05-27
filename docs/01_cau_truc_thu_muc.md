# Cấu Trúc Thư Mục Dự Án

Dự án được tổ chức thành các thư mục rõ ràng, phân tách mạch RTL, môi trường testbench mô phỏng, và các script phụ trợ.

## Cây Thư Mục Tổng Quan

```
DA11/
├── rtl/        # Chứa toàn bộ source code SystemVerilog (Synthesizable)
├── sim/        # Chứa testbench và dữ liệu dùng để chạy mô phỏng
│   └── test_data/ # Các file .hex sinh ra từ Python golden model
├── scripts/    # Các script Python hỗ trợ sinh dữ liệu chuẩn và tạo ROM
├── rom/        # Chứa các file dữ liệu khởi tạo cho bộ nhớ ROM (.hex)
└── docs/       # Chứa tài liệu giải thích dự án
```

## Chi Tiết Các File

### 1. Thư mục `rtl/` (RTL Synthesizable)
Toàn bộ các file trong thư mục này đều có thể tổng hợp được (synthesizable) thành phần cứng thực tế trên FPGA/ASIC.
- `trivial_rotator.sv`: Xoay pha các góc đặc biệt ($0^\circ, -90^\circ$).
- `butterfly_radix2_scaled.sv`: Thực hiện phép tính bướm Radix-2 cơ bản (cộng/trừ và dịch phải 1 bit để scaling).
- `complex_multiplier_q15.sv`: Bộ nhân số phức định dạng Q1.15 có thanh ghi pipeline.
- `delay_line_shift.sv`: Bộ trễ tín hiệu (shift register delay).
- `sdf_feedback_delay.sv`: Bộ đệm feedback delay, tổ hợp `delay_line_shift` và logic multiplexer dùng cho các tầng SDF.
- `sdf_bf2i_stage.sv`: Tầng SDF kiểu I (BF2I) trong kiến trúc R2²SDF.
- `sdf_bf2ii_stage.sv`: Tầng SDF kiểu II (BF2II) trong kiến trúc R2²SDF.
- `twiddle_rom.sv`: Bộ nhớ ROM chứa các hệ số xoay (twiddle factors).
- `r22sdf_block.sv`: Một block xử lý R2²SDF hoàn chỉnh (Gồm 1 BF2I, 1 BF2II và 1 khối CMUL tùy chọn). Chứa thuần túy datapath.
- `r22sdf_block_controlled.sv`: Wrapper đóng gói `r22sdf_block` đi kèm với bộ tạo tín hiệu điều khiển cục bộ (local control logic).
- `fft16_r22sdf_top.sv`: Top-level rút gọn của cấu trúc FFT 16 điểm (Dùng làm sandbox verification).
- `fft256_r22sdf_top.sv`: Top-level hoàn chỉnh của cấu trúc FFT 256 điểm.

### 2. Thư mục `sim/` (Simulation/Testbench)
Các file trong thư mục này KHÔNG synthesizable, chỉ phục vụ mục đích mô phỏng và kiểm chứng (verification).
- `tb_*.sv`: Các file testbench độc lập ứng với từng module RTL (vd: `tb_butterfly_radix2_scaled.sv`, `tb_sdf_bf2i_stage.sv`...).
- `tb_fft16_r22sdf_top.sv`: Testbench tự động kiểm tra (self-checking) hệ thống FFT-16.
- `tb_fft256_r22sdf_top.sv`: Testbench tự động kiểm tra hệ thống FFT-256 hoàn chỉnh.
- `test_data/`: Nơi lưu trữ các file text định dạng thập lục phân (`.hex`) sinh ra từ Python để testbench nạp vào luồng tín hiệu (stimulus) và so sánh kết quả (expected outputs).

### 3. Thư mục `scripts/` (Phần mềm hỗ trợ)
- `generate_twiddles.py`: Script Python tính toán các hệ số lượng giác lượng tử hóa (Q1.15) và ghi vào các file ROM.
- `golden_fft16.py`: Sinh model chuẩn (golden model) và test vector (.hex) cho FFT-16.
- `golden_fft256.py`: Sinh model chuẩn và test vector (.hex) cho FFT-256 (Gồm cả single frames, random stress test, back-to-back streaming).

### 4. Thư mục `rom/`
- `tw256.hex`, `tw64.hex`, `tw16.hex`: File chứa dữ liệu tĩnh (twiddle factors) để tổng hợp thành block RAM/ROM trên phần cứng, được sinh ra từ `generate_twiddles.py`.
