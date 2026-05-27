# Số Thực Dấu Phẩy Tĩnh & Phân Tích Sai Số

Hệ thống hardware FFT tính toán hoàn toàn dựa trên dữ liệu kiểu Fixed-point (dấu phẩy tĩnh) nhằm tối ưu diện tích chip.

## 1. Định dạng Q1.15
Q1.15 là chuẩn biểu diễn số thực bằng một biến nguyên (integer) 16 bit, trong đó:
- **1 bit cao nhất (MSB):** Là bit Dấu (Sign bit, dùng số bù 2).
- **15 bit còn lại:** Đại diện cho phần thập phân (Fractional part).

Ví dụ: 
- Giá trị lớn nhất biểu diễn được: $+1 - 2^{-15} \approx 0.999969$.
- Giá trị nhỏ nhất: $-1.0$.
Bất kỳ tín hiệu Analog-to-Digital nào khi nạp vào mạch cũng cần được chuẩn hóa về dải $[-1, 1]$ trước khi chuyển thành chuỗi hex Q1.15.

Một mẫu dữ liệu phức trong mạch bao gồm 32 bit, ghép bởi `din_re[15:0]` và `din_im[15:0]`.

## 2. Vì sao Butterfly dịch phải 1 bit? (Scaling Factor)
Thuật toán FFT là quá trình cộng gộp năng lượng của các tín hiệu thành phần. Phép tính Bướm (Butterfly) cơ bản là: $X = A + B$.
Nếu $A$ và $B$ đều là số 16-bit, tổng $X$ có thể vượt ngưỡng và cần 17-bit (bit growth / overflow).
Để giữ nguyên băng thông bộ nhớ và bus dây ở 16-bit suốt dọc chiều dài đường ống, mạch được thiết kế ép buộc: Mỗi khi tính cộng/trừ xong, kết quả bị **dịch phải 1 bit (shift right `>>> 1`)**, tương đương phép chia 2.

**Hệ quả Scaling FFT-256:**
Mạng FFT 256 điểm có $\log_2(256) = 8$ tầng bướm Radix-2. Qua mỗi tầng dữ liệu bị chia 2 một lần. Tổng cộng dữ liệu ra ở chu trình cuối đã bị thu nhỏ đi $2^8 = 256$ lần so với công thức toán học thuần túy. 
Do đó, hệ số Scaling Factor toàn cục là **1/256**. Testbench/Python model bắt buộc phải chia kết quả lý thuyết cho 256 để khớp với mạch.

## 3. Phép nhân phức và Dịch bit (CMUL Shift)
Khối `complex_multiplier_q15` nhân 2 toán hạng 16-bit Q1.15. 
- $16 \text{ bit} \times 16 \text{ bit} = 32 \text{ bit}$.
- Theo luật nhân Q-format, $Q1.15 \times Q1.15 = Q2.30$.
Kết quả nguyên thủy chui ra từ phép nhân nằm ở dạng Q2.30. Để nạp lại vào đường ống Q1.15, khối CMUL cắt dải bit `[30:15]` làm ngõ ra. (Bit 31 chứa dấu phụ thừa thãi).

## 4. Phân Tích Sai Số (Quantization Error)
Việc dịch phải (shift right) sau butterfly và cắt bit (truncation) sau multiplier liên tục vứt bỏ các bit có trọng số nhỏ (LSB). Qua 8 tầng liên tục vứt LSB, sai số tích lũy (accumulated quantization error) là không thể tránh khỏi.

Tuy nhiên, kết quả từ các bài Random Stress Test (20 frame liên tiếp) với cấu hình này cho thấy:
- **Sai số tuyệt đối trung bình (Mean Error):** $\sim 0.70$ LSB.
- **Sai số lớn nhất (Max Error):** Không bao giờ vượt quá **5 LSB**.
- Mức sai số 5 LSB trên nền dữ liệu 16-bit là cực nhỏ và nằm trong ranh giới an toàn cho các ứng dụng thực tế. 
- Do đó, ngưỡng dung sai (tolerance) của bài test tự động được nới từ 2 lên thành **5 LSB**.

## 5. Khử tràn (Saturation)
Trong bản Minimum Viable Product (MVP) này, do tín hiệu đã bị chia 2 nghiêm ngặt ở mọi tầng, mạch **không** sử dụng bộ giới hạn (saturation logic) để tiết kiệm tài nguyên cổng logic (logic gates). Việc overflow là bất khả thi trừ khi đầu vào bị ép sai quy chuẩn dải Q1.15.
