# Hướng Dẫn Debug Bằng GTKWave

GTKWave là một phần mềm phân tích giản đồ xung logic (Waveform Viewer). Nó đọc các file log nhị phân để vẽ lại toàn bộ trạng thái của từng sợi dây điện (wire/register) bên trong chip tại mỗi chu kỳ clock, giúp bạn nhìn xuyên thấu vào cấu trúc hệ thống.

## 1. Cách sinh file waveform (.vcd)
Mọi testbench trong dự án (ví dụ `tb_fft256_r22sdf_top.sv`) đều đã tích hợp sẵn đoạn code sinh file dump:
```systemverilog
$dumpfile("tb_fft256_r22sdf_top.vcd");
$dumpvars(0, tb_fft256_r22sdf_top);
```
Khi bạn chạy lệnh `vvp sim/fft256.vvp`, chương trình sẽ tự động nhả ra một file `tb_fft256_r22sdf_top.vcd` nằm ở thư mục hiện tại.

## 2. Cách mở file .vcd
Mở terminal và gõ:
```bash
gtkwave tb_fft256_r22sdf_top.vcd
```
Giao diện GTKWave sẽ hiện lên. Ở cây thư mục bên trái (SST), bạn có thể xổ các module ra và kéo thả tín hiệu (Signals) vào khu vực màn hình chính (Signals list) để vẽ xung.

## 3. Các tín hiệu khuyên dùng để quan sát (Signals to Trace)
Khi debug một hệ thống pipelined sâu như FFT-256, hãy luôn nhóm các tín hiệu theo trật tự logic của nó:
- **Nhóm Giao tiếp (Interface):** 
  - Kéo các tín hiệu Top-level: `clk`, `rst_n`.
  - Tín hiệu kích hoạt nạp data: `valid_in`, `sync_in`, `din_re`, `din_im`.
  - Tín hiệu kết quả trả về: `valid_out`, `sync_out`, `dout_re`, `dout_im`.
- **Nhóm Điều khiển cục bộ (Local Control):**
  - Mở module `dut` -> click vào các block `genblk[0]`, `genblk[1]`...
  - Kéo các tín hiệu sinh control: `current_cnt`, `phase_sel_i`, `phase_sel_ii`, `rot_sel`, `tw_addr`.
- **Nhóm Block-level Valid/Sync:**
  - Để biết dữ liệu đang tắc ở đâu, hãy kéo tín hiệu `valid_out` của Block 0, Block 1, Block 2, Block 3 đặt cạnh nhau để thấy dạng sóng nối đuôi dạng bậc thang.

## 4. Kỹ thuật Debug cụ thể
- **Cách debug Latency 258 Cycles:** 
  1. Kéo `sync_in` và `sync_out` ra màn hình.
  2. Bấm vào icon "Marker" (hình mũi tên đánh dấu). Kéo click chuột từ cạnh lên (posedge) của xung `sync_in` sang cạnh lên của `sync_out`.
  3. Thời gian delta (time difference) ở phía trên màn hình chia cho thời gian của 1 clock cycle (10ns) sẽ ra chính xác 258. Nếu không đủ 258, chứng tỏ có shift-register nào đó đang đếm sai kích thước (sai Parameter).
- **Cách debug Valid bị lệch Data:**
  1. Kéo `valid_out` và `dout_re`. Đổi định dạng hiển thị của `dout_re` sang Analog Step hoặc Decimal để dễ nhìn số.
  2. Dữ liệu thực đầu tiên (khác 0) phải xuất hiện ngay tại chu kỳ clock mà `valid_out` nhảy lên 1. Nếu data xuất hiện trễ hơn `valid_out` 1 chu kỳ, thì độ sâu bộ trễ của khối v_sr/s_sr đang bị sai (thường là cấp nhầm độ rộng bit).
- **Cách debug lỗi Đảo pha (Bit-Reversed):**
  Chạy Test "Impulse" (Vector chứa số 0.5 ở index 0, còn lại 0 toàn bộ). Nếu kết quả đầu ra không phải mảng constant toàn bộ là 64, mà lại lồi lõm, chứng tỏ các bit control (VD: `rot_sel`, `tw_addr`) đang bị gán sai vị trí (bị đảo trật tự). Kéo `rot_sel` ra soi xem nó có tuân thủ quy tắc lặp $0-1-2-3$ hay không.

## 5. Lưu trạng thái Waveform (.gtkw)
Mỗi lần mở GTKWave kéo từng tín hiệu rất mất công. Khi đã bố trí màn hình đẹp, hãy ấn **File -> Write Save File**.
Lưu thành file `debug_fft256.gtkw`. 
Lần sau chỉ cần gõ:
```bash
gtkwave debug_fft256.gtkw
```
GTKWave sẽ mở lại đúng cửa sổ và dàn bài tín hiệu bạn đã sắp đặt.
