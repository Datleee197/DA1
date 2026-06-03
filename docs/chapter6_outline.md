# CHƯƠNG 6. TRIỂN KHAI RTL VÀ KIỂM CHỨNG CHỨC NĂNG HỆ THỐNG FFT-256 R2²SDF

## 6.1. Mục tiêu của chương
- Kế thừa nền tảng lý thuyết từ Chương 5.
- Trình bày quy trình triển khai RTL từ block nhỏ lên toàn hệ thống.
- Chứng minh thiết kế được kiểm chứng chức năng bằng mô phỏng RTL so với mô hình golden Python/NumPy.

## 6.2. Quy ước thiết kế RTL
- Cấu trúc SystemVerilog module (clk, rst_n, valid_in, sync_in, valid_out, sync_out).
- Định dạng dữ liệu Q1.15 (signed, 16-bit).
- Giao thức đồng bộ pipeline streaming.

## 6.3. Thiết kế các block RTL cơ bản
- **6.3.1. `trivial_rotator.sv`**: Phép xoay $1, -j, -1, j$. Bảng ánh xạ `rot_sel`.
- **6.3.2. `butterfly_radix2_scaled.sv`**: Phép tính bướm Radix-2 và dịch phải (shift-right) chống tràn bit.
- **6.3.3. `complex_multiplier_q15.sv`**: Bộ nhân phức Q1.15 và pipeline trễ 1 chu kỳ.
- **6.3.4. `delay_line_shift.sv`**: Thanh ghi dịch tuyến tính thông thường.
- **6.3.5. `sdf_feedback_delay.sv`**: Thanh ghi trễ chuyên dụng cho đường phản hồi SDF (SDF feedback loop).
- **6.3.6. `twiddle_rom.sv`**: Bộ nhớ ROM chứa hệ số góc xoay tĩnh.

## 6.4. Thiết kế stage SDF
- **6.4.1. `sdf_bf2i_stage.sv`**: Kiến trúc khối BF2I (Khoảng cách chéo $N/2$) và phương pháp nạp/xả trễ.
- **6.4.2. `sdf_bf2ii_stage.sv`**: Kiến trúc khối BF2II (Khoảng cách chéo $N/4$) kết hợp bộ trivial rotator bên trong.

## 6.5. Thiết kế block Radix-2² SDF
- **6.5.1. `r22sdf_block.sv`**: Khối Wrapper ghép nối datapath (BF2I -> BF2II -> CMUL).
- **6.5.2. `r22sdf_block_controlled.sv`**: Cơ chế điều khiển cục bộ (Local Control) sinh ra các tín hiệu `phase_sel_i`, `phase_sel_ii`, `rot_sel` từ `current_cnt`.

## 6.6. Thiết kế flow từ block nhỏ lên hệ thống
- Quy trình Bottom-Up 10 bước an toàn và giảm thiểu rủi ro khi debug hệ thống pipeline sâu.

## 6.7. Thiết kế top-level FFT-16 sandbox
- Mô hình thu nhỏ kiểm chứng logic ghép nối R2²SDF nhanh (Delay 8 -> 4 -> 2 -> 1).
- Trải nghiệm bài test output order (bit-reversed).

## 6.8. Thiết kế top-level FFT-256
- Liên kết 4 stage `r22sdf_block_controlled` (128->64, 32->16, 8->4, 2->1).
- Chứng minh độ trễ toàn mạng: $193 + 49 + 13 + 3 = 258$ chu kỳ clock.

## 6.9. Kiểm chứng chức năng RTL
- Tập hợp các test vectors so sánh với Python Golden Model.
- Ngưỡng dung sai lượng tử (5 LSB tolerance) và hiện tượng Bit-Reversed.
- Kết quả test 20 frames ngẫu nhiên và 3 frames streaming liên tục.

## 6.10. Hướng dẫn quan sát waveform bằng GTKWave
- Hướng dẫn trace tín hiệu VCD để trực quan hóa độ trễ 258 chu kỳ và phân tích lệch valid/data.

## 6.11. Tổng kết chương
- Khẳng định mô hình phần cứng hoạt động chuẩn xác so với Figure 4, đạt trạng thái functionally verified by RTL simulation.
