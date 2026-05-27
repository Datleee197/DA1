# Hướng Dẫn Chạy Simulation & Verification

Dự án này sử dụng công cụ mã nguồn mở **Icarus Verilog (`iverilog`)** để biên dịch và chạy mô phỏng.

## 1. Cách chạy Full Regression (Khuyến nghị)
Đây là cách nhanh nhất để kiểm tra toàn bộ 8 module cơ sở (leaf modules). Dự án đã có sẵn một script chạy tự động (batch run).
Mở terminal tại thư mục gốc của dự án (`DA11/`) và gõ:
```bash
bash scripts/run_module_tests.sh
```
Nếu màn hình in ra toàn bộ `PASS`, tức là các module cơ sở đều khỏe mạnh.

## 2. Cách chạy FFT-16 Test (Sandbox)
FFT-16 là mô hình thu nhỏ dùng để kiểm chứng logic ghép nối R2²SDF nhanh gọn.
**Bước 1:** Chạy Python để sinh các mảng dữ liệu mẫu ngẫu nhiên (Golden vectors).
```bash
python scripts/golden_fft16.py
```
**Bước 2:** Biên dịch toàn bộ source code RTL và testbench vào một file `.vvp`.
```bash
iverilog -g2012 -o sim/fft16.vvp rtl/*.sv sim/tb_fft16_r22sdf_top.sv
```
**Bước 3:** Chạy file biên dịch đó bằng Icarus vvp engine.
```bash
vvp sim/fft16.vvp
```
*Bạn sẽ thấy kết quả so khớp của các bài test, ví dụ: "Match found: BIT-REVERSED order".*

## 3. Cách chạy FFT-256 Test (Full Architecture)
Tương tự như FFT-16, nhưng cấu hình này chạy hệ thống hoàn chỉnh với 258 cycle latency và kiểm tra các bài Random Stress.
```bash
# 1. Sinh data chuẩn và bài test back-to-back
python scripts/golden_fft256.py

# 2. Biên dịch source RTL
iverilog -g2012 -o sim/fft256.vvp rtl/*.sv sim/tb_fft256_r22sdf_top.sv

# 3. Kích hoạt chạy test
vvp sim/fft256.vvp
```

## 4. Cách Regenerate Twiddle ROMs
Trong trường hợp bạn muốn thay đổi dải bit hay thay đổi độ lớn của bảng ROM, bạn chạy lệnh sau:
```bash
python scripts/generate_twiddles.py
```
Script này tự động ghi đè lại các file `rom/tw256.hex`, `rom/tw64.hex` và `rom/tw16.hex`.

## 5. Đọc Hiểu Kết Quả PASS/FAIL
Testbench được viết dạng tự đối chiếu (self-checking testbench). 
- Nếu luồng dữ liệu RTL xuất ra giống hệt luồng dữ liệu chuẩn (nằm trong dung sai 5 LSB), terminal sẽ in ra **`Match found: BIT-REVERSED order`**. Coi như bài test **PASS**.
- Nếu có một giá trị nào đó văng ra khỏi dải dung sai, testbench sẽ in **`ERROR: No match found! Output order issue or computation error.`**. Kèm theo sau đó là dòng `ERROR: Latency mismatch!` nếu chu kỳ trễ bị lệch, hoặc in chi tiết thống kê lượng mẫu lỗi (Samples > 5 LSB).

## 6. Xử lý khi xảy ra Mismatch
Nếu bạn nhận được `ERROR`, hãy làm theo các bước sau:
1. Xác định bài test nào bị fail (VD: Test 2: Impulse).
2. Kiểm tra thông số **Detected Latency**. Nếu latency $\neq 258$, bạn đã làm hỏng định tuyến `valid` và `sync` trong một số khối shift-register.
3. Nếu latency đúng nhưng kết quả sai, kiểm tra số lượng **Samples > 5 LSB**. Nếu sai số rất nhỏ nhưng vượt mức (vd: 6 LSB), có thể đây là hiệu ứng lượng tử hóa (quantization bias) do bạn sửa đổi thuật toán chia của butterfly.
4. Mở file waveform `.vcd` trên GTKWave để trace từng bit. (Xem hướng dẫn GTKWave).
