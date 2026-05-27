# Tổng Quan Dự Án FFT-256 R2²SDF

## Mục Tiêu Của Project
Mục tiêu chính của dự án là thiết kế và thực thi (implement) một bộ gia tốc phần cứng (hardware accelerator) tính toán FFT 256 điểm (Fast Fourier Transform). Thiết kế này hướng tới việc hoạt động liên tục (streaming) với khả năng xử lý tốc độ cao, phục vụ cho các hệ thống xử lý tín hiệu số (DSP) thời gian thực.

## Kiến Trúc Được Chọn: Radix-2² SDF
Hệ thống sử dụng kiến trúc **Radix-2² Single-path Delay Feedback (R2²SDF)**. 

**Vì sao chọn R2²SDF?**
- **Tiết kiệm tài nguyên:** R2²SDF kết hợp ưu điểm của kiến trúc Radix-2 và Radix-4. Nó sử dụng số lượng thanh ghi dịch (shift registers) và bộ nhân phức (complex multipliers) tối thiểu giống như Radix-4, nhưng cấu trúc bướm (butterfly) vẫn duy trì sự đơn giản của Radix-2 (chỉ cần tính toán cộng/trừ cơ bản, không nhân phức tạp).
- **Phù hợp xử lý streaming:** Kiến trúc SDF (Single-path Delay Feedback) chỉ cần một đường dữ liệu vào (single data stream), cho phép dữ liệu liên tục đi qua các tầng mà không cần lưu trữ toàn bộ mảng data vào RAM rồi mới xử lý, giúp tiết kiệm memory bandwidth.
- **Dễ điều khiển:** Tín hiệu điều khiển (control signals) ở các tầng SDF chỉ phụ thuộc vào một bộ đếm (counter) đồng bộ với luồng dữ liệu, giúp module điều khiển trở nên rất gọn nhẹ.

## Định Dạng Dữ Liệu
Hệ thống tính toán hoàn toàn trên số thực dấu phẩy tĩnh (fixed-point). 
Định dạng được sử dụng là **Q1.15** (1 bit dấu, 15 bit phần thập phân). Do đó, tổng độ rộng dữ liệu (data width) cho mỗi phần (thực và ảo) là 16 bit.

## Hiệu Suất Hệ Thống (Performance)
- **Throughput mục tiêu:** 1 mẫu phức (complex sample) trên mỗi clock cycle sau khi pipeline đã được làm đầy (filled).
- **Latency đo được:** Quá trình tính toán mất chính xác **258 clock cycles** kể từ khi tín hiệu `sync_in` bắt đầu cho đến khi có `sync_out` xuất hiện ở đầu ra.

## Đặc Điểm Đầu Ra
- **Output order (Thứ tự đầu ra):** Kết quả của FFT không xuất hiện theo thứ tự tự nhiên (natural order). Do đặc thù cấu trúc mạng Radix-2², thứ tự đầu ra là **bit-reversed** (đảo bit).
- **Scaling toàn cục (Global Scaling Factor):** Hệ thống có 8 tầng butterfly Radix-2. Tại mỗi tầng, để tránh hiện tượng tràn số (overflow), kết quả phép cộng/trừ đều được dịch phải 1 bit (chia 2). Trải qua 8 tầng, dữ liệu bị chia tổng cộng $2^8 = 256$ lần. Do đó, hệ số scale của toàn hệ thống là **1/256**.

## Lưu Ý Về Verification
Dự án này sử dụng phương pháp **RTL functional verification** (kiểm tra chức năng RTL) thông qua mô phỏng (simulation) dựa trên bộ test vector sinh ra từ mô hình chuẩn (golden model) viết bằng thư viện `NumPy` trên Python. 
*Lưu ý:* Đây là kiểm chứng tính đúng đắn về mặt chức năng đối chiếu với kết quả toán học mẫu, **không** gọi là "formal verification" (kiểm chứng hình thức bằng toán học hệ thống logic).
