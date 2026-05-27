# Liên Kết Cấp Hệ Thống (System Integration)

Tài liệu này giải thích cách các module cấp thấp (leaf modules) được ghép nối lại để tạo thành hệ thống tính toán FFT-256 hoàn chỉnh.

## 1. Ghép nối một block R2²SDF cơ bản (`r22sdf_block`)
Mỗi `r22sdf_block` tương đương với một tầng Radix-4, nhưng được chia làm hai nửa:
1. **Nửa đầu (BF2I):** Xử lý khoảng cách chéo xa (`DELAY_I`). Module `sdf_bf2i_stage` được gọi ra.
2. **Nửa sau (BF2II):** Xử lý khoảng cách chéo gần (`DELAY_II = DELAY_I / 2`). Module `sdf_bf2ii_stage` được gọi ra và nối tiếp vào sau ngõ ra của BF2I.
3. **Multiplier (CMUL):** Nếu tham số `HAS_CMUL = 1`, dữ liệu ra từ BF2II sẽ được đưa vào `complex_multiplier_q15` để nhân với hệ số từ `twiddle_rom`. Nếu `HAS_CMUL = 0`, luồng dữ liệu truyền thẳng (bypass) ra ngoài.

## 2. Quản lý điều khiển cục bộ (`r22sdf_block_controlled`)
Việc dùng chung một khối điều khiển trung tâm (Centralized Control Unit) cho toàn bộ hệ thống Pipeline sâu 258 chu kỳ là cực kỳ phức tạp và dễ lỗi pha.
Dự án chọn giải pháp **Điều khiển cục bộ (Local Control)**:
- Mỗi block được bọc trong module `r22sdf_block_controlled`.
- Module này chứa một biến `current_cnt` (chỉ chạy khi `valid_in` = 1, và reset về 0 khi `sync_in` = 1).
- Mọi tín hiệu điều khiển (`phase_sel_i`, `phase_sel_ii`, `rot_sel`, `tw_addr`) được tách trực tiếp từ các bit cụ thể của `current_cnt`. Nhờ vậy, tín hiệu điều khiển luôn đồng bộ chặt chẽ với dữ liệu đang chảy qua Block đó, bất kể nó nằm ở vị trí nào trong pipeline.

## 3. Ghép nối thành FFT-256
FFT kích thước 256 ($2^8 = 4^4$) cần chính xác 4 block R2²SDF ghép nối tiếp:
- **Block 0:** `DELAY_I=128`, `DELAY_II=64`, dùng ROM `tw256.hex` (chứa $256 \times 3 / 4 = 192$ hệ số).
- **Block 1:** Nối vào ngõ ra của Block 0. `DELAY_I=32`, `DELAY_II=16`, dùng ROM `tw64.hex`.
- **Block 2:** Nối vào ngõ ra của Block 1. `DELAY_I=8`, `DELAY_II=4`, dùng ROM `tw16.hex`.
- **Block 3:** Nối vào ngõ ra của Block 2. `DELAY_I=2`, `DELAY_II=1`, tham số `HAS_CMUL = 0` (vì chặng cuối cùng các hệ số xoay đều là 1).

## 4. Giao thức đồng bộ Valid/Sync
Dữ liệu di chuyển trong hệ thống theo cơ chế đẩy (push):
- Mạch chỉ hoạt động (thanh ghi dịch, counter dịch) khi `valid_in = 1`. Nếu `valid_in = 0`, toàn bộ mạng pipeline sẽ đứng im bảo toàn trạng thái (stall).
- `sync_in` chỉ đẩy lên 1 ở mẫu **đầu tiên** của một frame (đánh dấu index 0).
- Bên trong các block, 2 cờ này được trì hoãn (delay) đi qua các shift-register song song với luồng dữ liệu. Tức là data bị trễ bao lâu, cờ `valid` và `sync` bị trễ bấy lâu.
- Ở tầng cuối cùng, `valid_out` và `sync_out` văng ra, báo cho hệ thống downstream biết frame dữ liệu hợp lệ bắt đầu.

## 5. Lý giải Latency 258 Chu Kỳ
Tổng trễ là tổng trễ của tất cả các block cộng lại:
- **Block 0:** Trễ của BF2I (128) + Trễ của BF2II (64) + Trễ của thanh ghi CMUL (1) = 193 cycles.
- **Block 1:** 32 + 16 + 1 = 49 cycles.
- **Block 2:** 8 + 4 + 1 = 13 cycles.
- **Block 3:** 2 + 1 + 0 (Không CMUL) = 3 cycles.
- **Tổng cộng:** $193 + 49 + 13 + 3 = 258$ cycles. Testbench xác nhận chính xác con số này.

## 6. Hiện tượng Đảo Bit (Bit-Reversed Order)
Khác với tính toán FFT bằng phần mềm thường xử lý mảng trong RAM, kiến trúc SDF xử lý dòng dữ liệu. 
Đặc thù thuật toán Phân chia theo Tần số (DIF - Decimation In Frequency) khi map xuống phần cứng dạng luồng làm cho các mẫu sau khi tính toán xong không chui ra ngoài theo thứ tự $0, 1, 2, ... 255$.
Thay vào đó, chỉ số thứ tự của kết quả bị đảo ngược bit nhị phân (Ví dụ 8-bit, 0000_0001 thành 1000_0000). Điều này đã được chứng minh thực nghiệm (strong evidence) thông qua các phép thử tone đơn tần số (Single Tone bin) trong testbench. Hệ thống downstream sẽ cần một module giao tiếp RAM (Bit-Reversing Buffer) để sắp xếp lại data nếu cần thiết.
