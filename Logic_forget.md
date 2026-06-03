# Logic cần làm sau

## 1. Trừ/giữ tiền cọc khi tạo job

Luồng đúng nên chuyển về backend/transaction:

1. Doanh nghiệp tạo job.
2. Backend tính `depositAmount = salary * slots`.
3. Kiểm tra ví doanh nghiệp còn đủ số dư khả dụng.
4. Nếu đủ tiền: trừ hoặc hold `depositAmount` khỏi ví doanh nghiệp.
5. Ghi transaction ví loại `job_deposit_hold`.
6. Chỉ sau khi hold tiền thành công mới tạo `jobPosts`.
7. Job lưu rõ:
   - `totalBudget = depositAmount`
   - `depositStatus = held`
   - `depositHeldAt`
   - `depositTransactionId`

Nếu ví không đủ tiền thì không tạo job và trả lỗi cho app. Không để client Flutter tự quyết định số tiền bị trừ, vì có thể bị sửa request hoặc lỗi ghi nửa chừng.

## 2. Đền bù bằng điểm đánh giá/uy tín cho ứng viên

Hiện tại luồng hủy job mới đền bù bằng tiền trong ví. Nếu nghiệp vụ yêu cầu
"đền bù tăng điểm đánh giá user" thì cần tách rõ đây là điểm uy tín hệ thống,
không phải review sao thủ công từ employer.

Luồng đúng nên làm sau:

1. Khi job đã đủ người nhưng doanh nghiệp hủy trước ngày làm, backend xác định
   danh sách ứng viên hợp lệ được đền bù.
2. Ngoài giao dịch tiền, backend ghi một sự kiện uy tín riêng, ví dụ
   `reputationEvents`:
   - `userId`
   - `jobId`
   - `type = employer_cancelled_full_job`
   - `pointsDelta`
   - `reason`
   - `createdAt`
3. Cập nhật field tổng hợp trên `users/{candidateId}`, ví dụ:
   - `reputationScore`
   - `reputationEventCount`
   - `updatedAt`
4. Không tự tạo review 5 sao giả trong collection `reviews`, vì review là
   đánh giá chủ quan sau khi làm việc. Điểm bù do hệ thống nên nằm ở hệ điểm
   uy tín riêng để tránh làm sai trung bình rating.
5. Gửi notification cho ứng viên nói rõ:
   - job đã bị hủy
   - số tiền được bù nếu có
   - điểm uy tín được cộng nếu có
6. Cần idempotency key theo `jobId + candidateId` để không cộng điểm nhiều lần
   nếu workflow hủy chạy lại.

## 4. Hủy job và hoàn/đền bù tiền chuẩn backend

Luồng đúng nên nằm trong Cloud Function hoặc backend transaction:

1. Nhận yêu cầu hủy job từ doanh nghiệp.
2. Backend kiểm tra:
   - Người gọi đúng là chủ job.
   - Job chưa bắt đầu.
   - Job chưa bị hủy/đóng trước đó.
   - Tiền cọc đang ở trạng thái `held`.
3. Backend đọc danh sách application còn hiệu lực, bỏ qua `withdrawn`, `rejected`, `cancelled`.
4. Nếu `filledSlots >= slots`:
   - Hoàn 90% `totalBudget` cho doanh nghiệp.
   - Chia 10% `totalBudget` cho các ứng viên hợp lệ.
   - Ghi transaction ví cho từng bên.
5. Nếu `filledSlots < slots`:
   - Hoàn 100% `totalBudget` cho doanh nghiệp.
   - Không đền bù ứng viên.
6. Trong cùng transaction/batch hoặc workflow idempotent:
   - Cập nhật job `status = cancelled`.
   - Cập nhật application `status = cancelled`.
   - Hủy schedules/workSchedules liên quan.
   - Giải tán nhóm chat.
   - Gửi notification cho ứng viên và doanh nghiệp.
7. Lưu log:
   - `cancelledAt`
   - `cancelledBy`
   - `refundAmount`
   - `compensationTotal`
   - `compensationPerCandidate`
   - `refundTransactionIds`

Client Flutter chỉ nên gọi API hủy và hiển thị kết quả. Mọi tính toán tiền, ghi ví, cập nhật trạng thái quan trọng phải do backend xử lý để tránh gian lận và tránh lỗi ghi dữ liệu không đồng bộ.
