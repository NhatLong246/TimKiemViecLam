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
1. Part-time gửi duyệt/tạo bài phải đủ tiền app để ứng trước.
2. Số tiền ứng = tính theo lương, số người, số ngày, giờ/ngày.
3. Lương phải > 0.
4. Số lượng người thuê phải > 0.
5. Ngày kết thúc không được trước ngày bắt đầu.
6. Cùng ngày bắt đầu/kết thúc được phép, tính 1 ngày.
7. Nếu trả lương theo giờ thì bắt buộc nhập Giờ làm/ngày.
8. Giờ làm/ngày nếu nhập phải > 0 và <= 24.
9. Nếu có hạn mức chi ví, tiền ứng không được vượt hạn mức đó.
10. Khi sửa bài, nếu ngân sách tăng thì phải đủ tiền để giữ thêm phần chênh lệch.
11. Khi sửa bài, nếu ngân sách giảm thì hoàn lại phần chênh lệch.
12. Khi rút nháp/xóa/hủy trước giờ bắt đầu thì mới hoàn tiền held.
13. “Đã bắt đầu” giờ tính bằng ngày + giờ bắt đầu, không còn tính từ 00:00.

## 5. Full-time: CV, hẹn phỏng vấn và hoa hồng giới thiệu

Nghiệp vụ mong muốn:

1. NTD đăng bài tuyển Full-time.
2. User ứng tuyển bằng CV.
3. NTD xem được CV và các thông tin hồ sơ liên quan của user.
4. NTD duyệt/chấp nhận CV và app thông báo cho user ngày giờ hẹn phỏng vấn.
5. Khi hết hạn ứng tuyển, app tính hoa hồng giới thiệu dựa trên số CV/user đã được NTD duyệt.
6. Phí giới thiệu tạm giữ trước khi đăng bài Full-time là `100000 * slots`.
   Ví dụ 10 slot thì giữ 1.000.000đ.
7. Nếu hết hạn chỉ có 5 CV/user được duyệt thì app lấy 500.000đ và hoàn lại NTD 500.000đ.
   Nếu duyệt đủ 10 slot thì app lấy đủ 1.000.000đ.

Kết quả kiểm tra code hiện tại: chưa đúng đủ luồng trên.

Các việc cần làm:

1. Đổi ngữ nghĩa ngày giờ Full-time:
   - Trên màn tạo bài Full-time, đổi label `Ngày bắt đầu làm việc` thành `Ngày hẹn phỏng vấn`.
   - Đổi `Giờ bắt đầu` thành `Giờ hẹn phỏng vấn`.
   - Có thể tạm dùng field hiện tại `startDate` + `startTime` cho ngày giờ phỏng vấn, hoặc tốt hơn thêm field rõ nghĩa như `interviewAt`.
   - Toàn bộ text lỗi, text chi tiết job, nút apply phải đổi từ "công việc đã bắt đầu" sang "đã qua lịch hẹn phỏng vấn" khi là Full-time.
   - Logic hiện tại đã có check `applicationDeadline < startDate + startTime`, nhưng message và UI vẫn đang hiểu là ngày bắt đầu làm việc.

2. Bắt buộc CV khi `fullTimeDetails.requiresCv = true`:
   - Hiện tại switch `Bắt buộc nộp CV` chỉ được lưu và hiển thị, chưa chặn apply.
   - Khi user apply Full-time, nếu job yêu cầu CV thì phải kiểm tra `users/{uid}.cvUrl`.
   - Nếu chưa có CV thì điều hướng user tới màn CV/upload hoặc hiện lỗi bắt buộc tải CV.
   - Khi tạo `applications`, phải copy `cvUrl` hiện tại của user vào `applications.cvUrl`.
   - Nếu `requiresCv = false`, vẫn nên tự đính kèm `cvUrl` nếu user đã có CV để NTD xem được.

3. Xử lý phỏng vấn trực tiếp:
   - Hiện tại switch `Phỏng vấn trực tiếp` chỉ được lưu và hiển thị, chưa ảnh hưởng workflow.
   - Nếu `interviewRequired = true`, khi NTD duyệt CV phải gửi notification cho user gồm ngày giờ hẹn phỏng vấn.
   - Nếu `interviewRequired = false`, cần đổi text thông báo thành NTD đã chấp nhận hồ sơ/liên hệ trực tiếp, không gọi là hẹn phỏng vấn.
   - Cần thống nhất tên nút phía NTD: `Duyệt CV` hoặc `Duyệt CV & hẹn phỏng vấn`, thay vì chỉ `Ghi nhận & liên hệ`.

4. NTD xem chi tiết hồ sơ user:
   - Hiện tại NTD mở bottom sheet ứng viên chỉ xem được thông tin cơ bản như email, số điện thoại, giới tính, ngày sinh, rating và số việc.
   - Tile có nút `Xem CV` nhưng chỉ hiện nếu `applications.cvUrl` có dữ liệu; hiện apply Full-time chưa truyền CV nên thường không có nút.
   - Cần bổ sung màn/bottom sheet hồ sơ đầy đủ cho NTD gồm:
     - CV file: ưu tiên `applications.cvUrl`, fallback `users/{candidateId}.cvUrl`.
     - Giới thiệu bản thân.
     - Kinh nghiệm làm việc.
     - Học vấn.
     - Kỹ năng.
     - Dự án.
     - Chứng chỉ/bằng cấp.
     - Ngoại ngữ.
     - Tiêu chí tìm việc nếu cần.

5. Ứng tiền/phí giới thiệu Full-time:
   - Hiện tại `JobPricingService.quote()` đang coi Full-time là `referral_only`, `requiresDeposit = false`, nên NTD không bị giữ 100.000đ/slot trước khi đăng bài.
   - Cần thêm pricing riêng cho Full-time:
     - `referralFeePerSlot = 100000`.
     - `depositAmount = referralFeePerSlot * slots`.
     - `totalBudget = depositAmount`.
     - `calculationUnit = full_time_referral_fee`.
   - Khi NTD gửi duyệt bài Full-time, phải kiểm tra ví đủ tiền và hold số tiền này trong transaction/backend giống luồng tiền quan trọng khác.
   - Không để client tự tính hoặc tự quyết định số tiền hoa hồng.

6. Quyết toán hoa hồng khi hết hạn ứng tuyển:
   - Cần workflow backend/transaction chạy khi `applicationDeadline` đã qua.
   - Đọc số application Full-time đã được NTD duyệt, tức `status = accepted`.
   - `acceptedCount = min(số CV được duyệt, slots)`.
   - `commissionAmount = acceptedCount * 100000`.
   - `refundAmount = heldAmount - commissionAmount`.
   - Ghi transaction app thu hoa hồng và transaction hoàn tiền cho NTD nếu có.
   - Cập nhật job:
     - `depositStatus = released` nếu lấy hết.
     - hoặc trạng thái vừa thu vừa hoàn, kèm `depositReleasedAt`, `depositRefundedAt`, `depositRefundAmount`, `referralCommissionAmount`.
   - Cần idempotency key theo `full_time_referral_settlement_{jobId}` để không thu/hoàn tiền nhiều lần.

7. Hết hạn ứng tuyển và slot Full-time:
   - Hiện tại deadline có tự reject pending application, nhưng chưa quyết toán hoa hồng.
   - Code hiện đang dùng `filledSlots` là số đơn đã accept, không phải tổng số user đã apply.
   - Cần xác định rõ:
     - Số user apply dùng để thống kê/lọc danh sách ứng tuyển.
     - Số user được duyệt CV dùng để tính hoa hồng.
   - Khi `filledSlots >= slots`, nên chặn duyệt thêm và có thể tự từ chối pending còn lại.
   - Khi hết hạn, pending còn lại bị reject và không tính phí hoa hồng.

8. Tách Full-time khỏi logic Part-time không liên quan:
   - Hiện tại accept Full-time vẫn acquire schedule locks và có thể làm ứng viên bị trùng lịch như Part-time.
   - `ScheduleService` vẫn biến application Full-time `pending/accepted` thành lịch làm.
   - `MessagingService.syncChatsFromAcceptedApplications()` có thể tạo group chat cho Full-time khi sync inbox, dù accept ban đầu đã tránh tạo group.
   - Cần bỏ Full-time khỏi schedule lock, lịch làm, điểm danh, giải ngân và auto group chat, trừ khi sau này có luồng chat/phỏng vấn riêng.

9. Thông báo cho user:
   - Khi user apply Full-time: thông báo cho NTD phải nói rõ user đã nộp CV.
   - Khi NTD duyệt CV: notification cho user phải có ngày giờ hẹn phỏng vấn từ bài đăng.
   - Khi hết hạn và không được duyệt: pending CV bị từ chối với lý do hết hạn.
   - Khi NTD hủy bài Full-time trước deadline: cần hoàn tiền held theo số đã quyết toán hoặc hoàn toàn bộ nếu chưa quyết toán.
