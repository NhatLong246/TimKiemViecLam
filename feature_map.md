# FEATURE MAP — ViecNow

> **AI:** Kiểm tra file này trước khi code một tính năng mới để tránh làm trùng hoặc sai vai trò.
> Sau khi hoàn thành một feature, cập nhật status tại đây VÀ tóm tắt vào `MEMORY.md`.

## Trạng thái ký hiệu
- `✅` Done — Đã hoàn thành, có thể tham chiếu
- `🔄` In Progress — Đang làm
- `❌` Not Started — Chưa làm
- `⚠️` Needs Fix — Có vấn đề cần sửa

---

## SHARED (Tất cả roles)

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| S1 | Splash & routing logic | `splash_screen.dart` | ✅ | |
| S2 | Onboarding | `onboarding_screen.dart` | ✅ | |
| S3 | Đăng ký tài khoản | `register_screen.dart` | ✅ | Chưa có chọn role Employer/Candidate |
| S4 | Đăng nhập | `login_screen.dart` | ✅ | |
| S5 | Quên mật khẩu | `forget_password_screen.dart` | ✅ | |
| S6 | Xác thực email | `verify_email_screen.dart` | ✅ | |
| S7 | Đổi tên | `change_name_screen.dart` | ✅ | |
| S8 | Đổi username | `change_username_screen.dart` | ✅ | |
| S9 | Đổi email | `change_email_screen.dart` | ✅ | |
| S10 | Đổi SĐT | `change_phonenumber_screen.dart` | ✅ | |
| S11 | Đổi giới tính | `change_gender_screen.dart` | ✅ | |
| S12 | Đổi ngày sinh | `change_dateofbirth_screen.dart` | ✅ | |
| S13 | Tài khoản ngân hàng | `my_bank_account_screen.dart` | ✅ | |
| S14 | Thêm/sửa tài khoản NH | `add_edit_bank_account_screen.dart` | ✅ | |
| S15 | Main Navigation (bottom nav) | `main_navigation_screen.dart` | ✅ | Cần tách theo role |

---

## CANDIDATE FEATURES

| # | Tính năng | Screen/File (dự kiến) | Status | Ghi chú |
|---|---|---|---|---|
| C1 | Feed công việc (Home) | `screens/job/job_feed_screen.dart` | ❌ | |
| C2 | Tìm kiếm việc làm | `screens/search/search_screen.dart` | ✅ | Tìm theo keyword, mức lương, khoảng cách (thành phố) |
| C3 | Xem chi tiết công việc | `screens/job/job_detail_screen.dart` | ✅ | |
| C4 | Ứng tuyển (part-time: đề xuất) | `controller/application_controller.dart` | ❌ | Kiểm tra duplicate `candidateId+jobId` |
| C5 | Nộp CV (full-time) | `screens/job/apply_fulltime_screen.dart` | ❌ | Upload CV lên Firebase Storage |
| C6 | Danh sách đã ứng tuyển | `screens/application/my_applications_screen.dart` | ❌ | |
| C7 | Lịch làm việc | `screens/schedule/candidate_schedule_screen.dart` | ✅ | Firestore `schedules`, tuần + ca theo ngày |
| C8 | Thống kê thu nhập | `screens/stats/candidate_stats_screen.dart` | ❌ | Tổng job, tổng thu nhập |
| C9 | CV cá nhân | `screens/profile/cv_screen.dart` | ❌ | Dành cho full-time |
| C10 | Tham khảo giá thị trường | `screens/reference/market_rate_screen.dart` | ❌ | So sánh lương theo loại job + khu vực |
| C11 | Đánh giá Employer | `controller/review_controller.dart` | ❌ | Sau khi hoàn thành job |
| C12 | Xem đánh giá cá nhân | `screens/profile/my_ratings_screen.dart` | ❌ | |
| C13 | Tạo Lead Group | `screens/group/create_lead_group_screen.dart` | ❌ | Nhóm Candidates |
| C14 | Phân loại công việc | `screens/job/job_category_screen.dart` | ❌ | |

---

## EMPLOYER FEATURES

| # | Tính năng | Screen/File (dự kiến) | Status | Ghi chú |
|---|---|---|---|---|
| E1 | Dashboard Employer | `screens/employer/employer_home_screen.dart` | ✅ | Giao diện quản lý, mock data, bottom nav employer |
| E2 | Đăng tin tuyển dụng | `screens/employer/post_job_screen.dart` | ❌ | Cần check budget trong ví |
| E3 | Xem/Sửa/Xóa tin đăng | `screens/employer/manage_jobs_screen.dart` | ❌ | |
| E4 | Xem danh sách ứng viên | `screens/employer/applicants_screen.dart` | ❌ | |
| E5 | Duyệt/Từ chối ứng viên | `controller/employer_application_controller.dart` | ❌ | Tạo group chat sau khi duyệt |
| E6 | Quản lý nhân viên đang làm | `screens/employer/manage_employees_screen.dart` | ❌ | Tính lương, theo dõi |
| E7 | Điểm danh | `screens/employer/attendance_screen.dart` | ❌ | Theo giờ setup, check trễ/đúng |
| E8 | Lịch làm việc | `screens/employer/employer_schedule_screen.dart` | ❌ | Thêm lịch vào group chat |
| E9 | Thống kê chi tiêu | `screens/stats/employer_stats_screen.dart` | ✅ | Bar+Line+Area charts, filter Ngày/Tuần/Tháng/Năm, date range picker, 6 stat cards |
| E10 | Xác nhận hoàn thành job | `controller/job_completion_controller.dart` | ❌ | 2 bên xác nhận |
| E11 | Thanh toán lương | `controller/payment_controller.dart` | ❌ | Từ ví → tài khoản Candidate |
| E12 | Xử lý tranh chấp | `screens/employer/dispute_screen.dart` | ❌ | Xác nhận từ Candidates khác |
| E13 | Nạp tiền vào ví | `screens/wallet/deposit_screen.dart` | ❌ | |
| E14 | Lịch sử giao dịch | `screens/wallet/transaction_history_screen.dart` | ❌ | |
| E15 | Rút tiền | `screens/wallet/withdrawal_screen.dart` | ❌ | |
| E16 | Tham khảo giá thị trường | `screens/reference/employer_market_rate_screen.dart` | ✅ | Employer: xem mặt bằng lương theo category + khu vực. Route: `/employer-reference` |
| E17 | Đánh giá Candidate | `controller/review_controller.dart` | ❌ | |

---

## CHAT FEATURES (shared)

| # | Tính năng | Screen/File (dự kiến) | Status | Ghi chú |
|---|---|---|---|---|
| CH1 | Danh sách nhóm chat | `screens/chat/chat_list_screen.dart` | ❌ | |
| CH2 | Giao diện chat nhóm | `screens/chat/group_chat_screen.dart` | ❌ | Real-time Firestore listener |
| CH3 | Gửi lịch làm vào chat | Widget trong chat | ❌ | Type `"schedule"` |
| CH4 | Gửi thông báo điểm danh | Widget trong chat | ❌ | Type `"attendance_call"` |

---

## ADMIN FEATURES

| # | Tính năng | Screen/File (dự kiến) | Status | Ghi chú |
|---|---|---|---|---|
| A1 | Dashboard Admin | `screens/admin/admin_home_screen.dart` | ❌ | |
| A2 | Duyệt/Từ chối tin tuyển dụng | `screens/admin/job_approval_screen.dart` | ❌ | Đổi `status: "pending"` → `"approved"/"rejected"` |
| A3 | Quản lý người dùng | `screens/admin/user_management_screen.dart` | ❌ | |
| A4 | Xử lý tranh chấp | `screens/admin/dispute_management_screen.dart` | ❌ | |
| A5 | Báo cáo doanh thu | `screens/admin/revenue_screen.dart` | ❌ | |

---

## FILE/FOLDER CẦN TẠO (dự kiến cho các feature chưa có)
```
lib/screens/
    job/                    # C1, C2, C3, C4, C5, C14
    application/            # C6
    schedule/               # C7
    stats/                  # C8, E9
    reference/              # C10, E16
    wallet/                 # E13, E14, E15
    employer/               # E1-E17
    chat/                   # CH1-CH4
    admin/                  # A1-A5
lib/controller/
    job_controller.dart
    application_controller.dart
    employer_application_controller.dart
    job_completion_controller.dart
    payment_controller.dart
    attendance_controller.dart
    chat_controller.dart
    review_controller.dart
    admin_controller.dart
    wallet_controller.dart
lib/data/
    models/
        job_model.dart
        application_model.dart
        group_chat_model.dart
        message_model.dart
        schedule_model.dart
        attendance_model.dart
        transaction_model.dart
        review_model.dart
    services/
        job_service.dart
        application_service.dart
        chat_service.dart
        attendance_service.dart
        wallet_service.dart
        review_service.dart
        admin_service.dart
        sqlite_cache_service.dart   # quản lý SQLite
```

---

## Thứ tự ưu tiên phát triển (recommended)
1. **Phase 1:** S3 fix (chọn role khi đăng ký) → C1 Job Feed → C3 Job Detail → C4 Apply
2. **Phase 2:** E2 Post Job → E4 Applicants → E5 Approve → CH1/CH2 Group Chat
3. **Phase 3:** E7 Attendance → E10 Confirm → E11 Payment → C7 Schedule
4. **Phase 4:** E13/E14/E15 Wallet → C8/E9 Stats → C10/E16 Market Reference
5. **Phase 5:** Admin panel → Reviews → Lead Group → Dispute handling
