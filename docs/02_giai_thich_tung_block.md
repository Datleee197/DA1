# Giải Thích Chi Tiết Từng Block (RTL Modules)

Dự án tuân theo triết lý thiết kế "Bottom-up". Các module cơ sở (leaf modules) được thiết kế và kiểm chứng độc lập trước khi lắp ghép thành hệ thống lớn.

---

## 1. `trivial_rotator.sv`
- **Vai trò:** Thực hiện phép nhân số phức với các hệ số xoay đặc biệt: $W^0 = 1$ (không xoay) và $W^{N/4} = -j$ (xoay góc $-90^\circ$).
- **Input/Output:** 
  - `din_re, din_im`: Dữ liệu vào.
  - `rot_sel`: Tín hiệu chọn (0: $W^0$, 1: $W^{N/4}$).
  - `dout_re, dout_im`: Dữ liệu ra.
- **Cách hoạt động & Toán học:** 
  - Nếu `rot_sel = 0`: output = input (xem như nhân với $1$).
  - Nếu `rot_sel = 1`: output = input $\times (-j)$. Xét mặt toán học: $(R + jI) \times (-j) = I - jR$. Suy ra: `dout_re = din_im`, và `dout_im = -din_re`.
- **Lý do thiết kế:** Thay vì phải đưa bộ nhân $-j$ qua khối `complex_multiplier_q15` (sẽ tốn kém multiplier DSP trên FPGA), phép nhân $-j$ chỉ là thao tác hoán vị dây và đảo dấu (làm bằng phép bù 2: `~din_re + 1`), không tiêu tốn logic toán học nặng.
- **Lỗi dễ gặp:** Quên bit tràn khi đảo dấu (bù 2 của số âm nhỏ nhất), tuy nhiên với fixed-point đã được scaling, overflow ở đây hiếm xảy ra.

---

## 2. `butterfly_radix2_scaled.sv`
- **Vai trò:** Thực hiện phép cộng trừ bướm (Radix-2 Butterfly) và tự động thu nhỏ biên độ.
- **Input/Output:**
  - `x_re, x_im`, `y_re, y_im`: 2 luồng ngõ vào số phức.
  - `out_add_re, out_add_im`: Dữ liệu ngõ ra của nhánh cộng ($x + y$).
  - `out_sub_re, out_sub_im`: Dữ liệu ngõ ra của nhánh trừ ($x - y$).
- **Cách hoạt động & Toán học:** 
  - Tính tổng: $(x + y) / 2$.
  - Tính hiệu: $(x - y) / 2$.
  - Phép chia 2 được thực hiện bằng cách mở rộng 1 bit dấu, thực hiện phép toán, sau đó cắt bỏ bit LSB (tương đương phép Arithmetic Right Shift `>>> 1`).
- **Lý do thiết kế:** FFT cộng dồn qua nhiều tầng gây tăng kích thước bit (bit growth). Việc chia 2 ngay trong butterfly giữ độ rộng data không đổi (16-bit), đảm bảo định dạng Q1.15 thống nhất toàn mạch.

---

## 3. `complex_multiplier_q15.sv`
- **Vai trò:** Thực hiện phép nhân hai số phức định dạng Q1.15.
- **Input/Output:** `a_re, a_im` (dữ liệu), `b_re, b_im` (twiddle factor). Ra: `p_re, p_im` (chậm 1 clock cycle).
- **Cách hoạt động & Toán học:**
  - Phép nhân phức chuẩn: $p_{re} = (a_{re} \times b_{re}) - (a_{im} \times b_{im})$ và $p_{im} = (a_{re} \times b_{im}) + (a_{im} \times b_{re})$.
  - Cả a và b đều là Q1.15 (16-bit). Khi nhân nhau sẽ ra Q2.30 (32-bit). Khối này trích xuất lại dải bit `[30:15]` để ép kết quả trả về Q1.15 chuẩn.
- **Lý do thiết kế:** Mạch nhân thuần túy mất nhiều thời gian lan truyền (combinational delay). Khối này được thiết kế chèn thêm 1 tầng thanh ghi (pipeline register) ở đầu ra để cắt ngắn Critical Path, giúp nâng tần số tối đa (Fmax) của mạch.
- **Lỗi dễ gặp:** Lấy nhầm index bit khi shift (ví dụ lấy `[31:16]` thay vì `[30:15]`) sẽ làm giá trị bị lệch biên độ (sai số 1/2).

---

## 4. `delay_line_shift.sv` & `sdf_feedback_delay.sv`
- **Vai trò:** 
  - `delay_line_shift`: Tạo trễ tín hiệu độ sâu thay đổi (`DELAY` parameter). Hoạt động bằng cách khai báo mảng thanh ghi nối tiếp nhau.
  - `sdf_feedback_delay`: Wrapper ghép `delay_line_shift` với các MUX (Multiplexer) điều hướng dữ liệu.
- **Input/Output của `sdf_feedback_delay`:** 
  - `din`: Dữ liệu từ ngoài vào, `feedback_in`: Dữ liệu từ butterfly đưa ngược lại.
  - `phase_sel`: Quyết định chọn luồng dữ liệu (0: Nạp vào delay line, 1: Xuất từ delay line đi tính toán).
- **Cách hoạt động:** Khi `phase_sel = 0` (Nửa đầu block), mạch lưu trữ input vào bộ trễ. Khi `phase_sel = 1` (Nửa sau block), dữ liệu xả từ bộ trễ ra ngõ `dout`, đồng thời nạp kết quả `feedback_in` của bướm vào lại bộ trễ để xả ra ở chu kỳ tiếp theo.

---

## 5. `sdf_bf2i_stage.sv` & `sdf_bf2ii_stage.sv`
- **Vai trò:** Cài đặt 2 tầng bướm đặc thù của kiến trúc Radix-2² SDF.
- **Điểm khác biệt:**
  - `sdf_bf2i_stage` (Tầng I): Sử dụng bướm radix-2 bình thường kết nối với bộ đệm độ sâu $N/2$. Nó phân tách mẫu chẵn lẻ.
  - `sdf_bf2ii_stage` (Tầng II): Nằm ngay sau tầng I, bộ đệm có độ sâu bằng một nửa ($N/4$). Nó chèn thêm một bộ `trivial_rotator` ở ngõ vào $y$ của bướm để xử lý xoay pha $-90^\circ$ (tương đương phép nhân $-j$) dựa theo tín hiệu `rot_sel`.
- **Lý do thiết kế:** Hai tầng BF2I và BF2II ghép lại tạo thành hiệu ứng tính toán của một cục Radix-4 hoàn chỉnh, nhưng loại bỏ sự phức tạp về định tuyến (routing) đa đường của Radix-4 SDF truyền thống.

---

## 6. `twiddle_rom.sv`
- **Vai trò:** Lưu trữ hệ số góc xoay $W_N^k = \cos(2\pi k/N) - j\sin(2\pi k/N)$ dưới dạng tĩnh. Tùy theo `TW_FILE` mà module dùng file `.hex` tương ứng để khởi tạo (ví dụ `tw256.hex`).

---

## 7. `r22sdf_block.sv`
- **Vai trò:** Đóng gói BF2I, BF2II, ROM và CMUL thành một Block R2²SDF liền mạch (chỉ chứa data path, không tự sinh control).
- **Lý do thiết kế:** Module này tập trung giải quyết định tuyến luồng dữ liệu, cho phép testbench bên ngoài bơm tín hiệu control để kiểm chứng toán học thuần túy. Nếu tham số `HAS_CMUL = 0`, luồng data sẽ đi vòng qua (bypass) bộ ROM và CMUL (Dùng cho tầng cuối cùng của FFT).

---

## 8. `r22sdf_block_controlled.sv`
- **Vai trò:** Là Wrapper bọc bên ngoài `r22sdf_block.sv`. Nó chứa thêm một bộ đếm `counter` đồng bộ để tự sinh các tín hiệu `phase_sel_i, phase_sel_ii, rot_sel, tw_addr`.
- **Cách hoạt động:** Bộ đếm tự động chạy khi `valid_in` ở mức cao. Các tín hiệu điều khiển được gán trực tiếp thông qua việc cắt bóc các bit cụ thể của bộ đếm, đảm bảo thời gian đóng cắt luồng SDF chính xác tuyệt đối.

---

## 9. `fft16_r22sdf_top.sv` & `fft256_r22sdf_top.sv`
- **Vai trò:** Móc xích nối tiếp các module `r22sdf_block_controlled` thành hệ thống FFT.
  - `fft16`: Nối 2 block ($DELAY\_I = 8/2$).
  - `fft256`: Nối 4 block ($DELAY\_I = 128/32/8/2$).
- **Lỗi dễ gặp:** Lệch pha tín hiệu `valid` và `sync` giữa các block nếu không tính toán kỹ trễ pipeline của CMUL (bộ nhân phức). Thiết kế hiện tại đã đồng bộ chuẩn xác.
