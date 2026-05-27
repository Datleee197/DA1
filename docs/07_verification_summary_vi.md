# Tổng Kết Quá Trình Verification (Kiểm Chứng RTL)

Quá trình kiểm chứng chức năng (Functional Verification) mạch RTL so sánh với thuật toán chuẩn viết bằng Python/NumPy đã hoàn tất. Dưới đây là bảng tổng kết các kết quả thực nghiệm.

## 1. Trạng Thái Vượt Qua Bài Test
Toàn bộ hệ thống được test từ cấp vi mô đến vĩ mô và không phát hiện ra lỗi logic nào.
- **Module-level tests** (8 khối cơ sở riêng biệt): **PASS**
- **FFT-16 Sandbox Regression** (Phiên bản thu nhỏ 16 điểm): **PASS**
- **FFT-256 Single-frame tests** (Bài test 1 khung tín hiệu rời rạc): **PASS**
- **FFT-256 Random Stress Test** (Chạy liên tục 20 khung nhiễu ngẫu nhiên): **PASS**
- **FFT-256 Back-to-Back** (Chạy 3 khung liên tiếp kề nhau không có khoảng trống): **PASS**

## 2. Các Chỉ Số Hoạt Động (Metrics)
- **Độ trễ hệ thống (Latency đo được):** Chính xác **258 chu kỳ clock**.
- **Thứ tự đầu ra (Output Order):** Được chứng minh qua thực nghiệm là tuân theo quy luật đảo bit (**Bit-Reversed order**).

## 3. Phân Tích Lỗi Sai Số (Error Statistics)
Thu thập trên tập mẫu Stress Test cường độ cao gồm 5,120 điểm dữ liệu độc lập:
- **Max Absolute Error (Real - Phần thực):** 5 LSB
- **Max Absolute Error (Imag - Phần ảo):** 4 LSB
- **Mean Absolute Error (Sai số trung bình tuyệt đối):** ~0.70 LSB
Ngưỡng dung sai của mạch được cấu hình chính thức là $\le 5$ LSB do hao hụt tất yếu khi cắt bit ở 8 tầng phép tính lượng tử hóa Q1.15.

## 4. Điều Kiện Hoạt Động (Protocol Assumptions)
Để module FFT xuất được data ở ngõ ra đúng thời điểm, module điều khiển bên ngoài (Master) bắt buộc phải đáp ứng giao thức Flush Protocol:
- Chân `valid_in` bắt buộc phải **giữ ở mức CAO (HIGH)** để cung cấp nhịp dịch (shift enable) cho hệ thống đường ống (pipeline).
- Nếu mạch xử lý một chuỗi 256 mẫu rời rạc, sau khi đẩy xong mẫu cuối cùng vào ngõ vào, phải tiếp tục giữ `valid_in = 1` và bơm các giá trị dummy bằng 0 vào mạch thêm ít nhất 258 chu kỳ nữa. Nếu kéo `valid_in` xuống mức THẤP ngay lập tức, dữ liệu sẽ bị mắc kẹt vĩnh viễn bên trong mạch.

**Kết luận:** Hệ thống R2²SDF FFT-256 đã được kiểm chứng hoạt động hoàn toàn chính xác về mặt chức năng thông qua mô phỏng RTL (RTL Simulation).
