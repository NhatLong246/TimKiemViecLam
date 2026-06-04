# FEATURE MAP — ViecNow

> **AI:** Kiểm tra file này trước khi code một tính năng mới để tránh làm trùng hoặc sai vai trò.
> Sau khi hoàn thành một feature, cập nhật status tại đây VÀ tóm tắt vào `MEMORY.md`.

## Trạng thái ký hiệu
- `✅` Done — Đã hoàn thành, có thể tham chiếu
- `🔄` In Progress — Đang làm / một phần còn thiếu
- `❌` Not Started — Chưa làm
- `⚠️` Needs Fix — Có vấn đề cần sửa

---

## SHARED (Tất cả roles)

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| S1 | Splash & routing logic | `screens/spalsh/splash_screen.dart` | ✅ | |
| S2 | Onboarding | `screens/onboarding/onboarding_screen.dart` | ✅ | |
| S3 | Đăng ký tài khoản | `screens/auth/register_screen.dart` | ⚠️ | Hoạt động; chưa chọn role Employer/Candidate khi đăng ký |
| S4 | Đăng nhập | `screens/auth/login_screen.dart` | ✅ | Email + Google/Facebook |
| S5 | Quên mật khẩu | `screens/auth/forget_password_screen.dart` | ✅ | |
| S6 | Xác thực email | `screens/auth/verify_email_screen.dart` | ✅ | |
| S7 | Đổi tên | `screens/profile/change_name_screen.dart` | ✅ | |
| S8 | Đổi username | `screens/profile/change_username_screen.dart` | ✅ | |
| S9 | Đổi email | `screens/profile/change_email_screen.dart` | ✅ | |
| S10 | Đổi SĐT | `screens/profile/change_phonenumber_screen.dart` | ✅ | |
| S11 | Đổi giới tính | `screens/profile/change_gender_screen.dart` | ✅ | |
| S12 | Đổi ngày sinh | `screens/profile/change_dateofbirth_screen.dart` | ✅ | |
| S13 | Tài khoản ngân hàng | `screens/bank_account/my_bank_account_screen.dart` | ✅ | |
| S14 | Thêm/sửa tài khoản NH | `screens/bank_account/add_edit_bank_account_screen.dart` | ✅ | |
| S15 | Main Navigation (bottom nav) | `screens/home/main_navigation_screen.dart` | ✅ | Ứng viên; NTD: `employer_main_navigation_screen.dart` |
| S16 | Hồ sơ / cập nhật tài khoản | `screens/profile/profile_screen.dart`, `update_account_screen.dart` | ✅ | |
| S17 | Thông báo (chuông) | `screens/notification/notification_screen.dart` | ✅ | In-app + FCM push (cần deploy Functions) |
| S18 | Chatbot AI (Gemini) | `screens/chatbot/chatbot_screen.dart` | ✅ | FAB nổi trên home |

---

## CANDIDATE FEATURES

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| C1 | Feed công việc (Home) | `screens/home/home_screen.dart` | ✅ | Việc mới nhất, refresh, quick tools |
| C2 | Tìm kiếm việc làm | `screens/search/search_screen.dart`, `search_results_screen.dart` | ✅ | Keyword, lương, khoảng cách |
| C3 | Xem chi tiết công việc | `screens/job/job_detail_screen.dart` | ✅ | `job_detail_controller.dart`; tap địa điểm → `job_directions_map_screen.dart` |
| C4 | Ứng tuyển (part-time) | `controller/job_detail_controller.dart` | ✅ | `applyForJob`; check duplicate qua service |
| C5 | Nộp CV (full-time) | `screens/job/apply_fulltime_screen.dart` | ❌ | Chưa có màn riêng upload CV |
| C6 | Danh sách đã ứng tuyển | — | ❌ | Có `application_service.dart`, chưa có màn list |
| C7 | Lịch làm việc | `screens/schedule/candidate_schedule_screen.dart` | ✅ | Quick tool "Lịch làm"; Firestore `schedules`, tuần + ca theo ngày |
| C8 | Thống kê thu nhập | `screens/stats/candidate_stats_screen.dart` | ✅ | Quick tool "Thống kê" |
| C9 | CV / hồ sơ chi tiết | `screens/profile/my_profile_screen.dart`, `screens/profile/cv_screen.dart` + form screens | 🔄 | Kinh nghiệm, học vấn, kỹ năng, chứng chỉ, upload PDF |
| C10 | Tham khảo giá thị trường | `screens/reference/market_rate_screen.dart` | ✅ | Quick tool "Tham khảo" |
| C11 | Đánh giá Employer | `screens/menu_candidate/candidate_reviews_screen.dart` | 🔄 | UI có; logic đánh giá đầy đủ chưa rõ |
| C12 | Xem đánh giá cá nhân | `screens/menu_candidate/candidate_reviews_screen.dart` | 🔄 | |
| C13 | Nhóm / Lead Group (ứng viên) | `screens/menu_candidate/candidate_groups_screen.dart` | ✅ | Menu ứng viên |
| C14 | Phân loại / tiêu chí việc | `screens/profile/job_criteria_screen.dart` | ✅ | |
| C15 | Menu ứng viên (benefits, nhóm…) | `screens/menu_candidate/candidate_menu_scaffold.dart` | ✅ | |
| C16 | Điểm danh (ứng viên) | `screens/attendance/candidate_attendance_screen.dart` | ✅ | Chỉ ngày làm bắt buộc (`workSchedules` hoặc start–end job) |
| C18 | Khiếu nại sau giải tán | `post_dissolution_complaint_screen.dart` | ✅ | Chỉ nhóm `closed`; oan ức sau giải tán |
| C17 | Phân công ca (ứng viên) | `screens/attendance/candidate_work_assignment_screen.dart` | ✅ | |

---

## EMPLOYER FEATURES

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| E1 | Dashboard Employer | `screens/employer/employer_home_screen.dart` | ✅ | Bottom nav, quick tools |
| E2 | Đăng tin tuyển dụng | `screens/post/create_post_screen.dart` | ✅ | Validate đầy đủ + ảnh minh họa (`imageUrls`) |
| E3 | Xem/Sửa/Xóa tin đăng | `screens/post/post_management_screen.dart` | ✅ | |
| E4 | Xem danh sách ứng viên | `screens/employer/employer_candidates_screen.dart` | ✅ | |
| E5 | Duyệt/Từ chối ứng viên | `controller/candidates_controller.dart` | ✅ | Accept → tạo/thêm nhóm chat |
| E6 | Quản lý nhân viên đang làm | `screens/employer/employer_candidates_screen.dart` | 🔄 | Gộp với duyệt ứng viên; chưa tách màn riêng lương |
| E7 | Điểm danh | `screens/employer/attendance_screen.dart` | ✅ | Cuối ngày → giải ngân & đánh giá; bảng tổng hợp |
| E7b | Bảng điểm danh tổng hợp | `screens/employer/job_attendance_summary_screen.dart` | ✅ | Menu nhóm NTD |
| E7c | Kết thúc ngày / giải ngân | `screens/employer/job_day_end_flow_screen.dart` | ✅ | Tự động chia lương → Hỏi khiếu nại → Đóng nhóm & bài đăng |
| E7d | Nhắc giải ngân tự động (hết endDate) | `job_disbursement_reminder_service.dart` | ✅ | Poll mỗi phút khi NTD đăng nhập; log `workflowReminders/disbursement` |
| E8 | Lịch làm việc | `screens/chat/work_schedule_screen.dart`, `schedule_tool_screen.dart` | ✅ | Gửi lịch vào chat qua `MessagingService` |
| E9 | Thống kê chi tiêu | `screens/stats/employer_stats_screen.dart` | ✅ | fl_chart, filter Ngày/Tuần/Tháng/Năm |
| E10 | Xác nhận hoàn thành job | `job_workflow_service.dart` | ✅ | Tự đóng job và xóa nhóm chat sau khi giải ngân |
| E11 | Thanh toán lương (giải ngân) | `job_workflow_service.dart` | ✅ | Hỗ trợ đền bù chênh lệch, nợ âm tiền ví (tự xử lý) |
| E12 | Xử lý tranh chấp | `job_day_end_flow_screen.dart` | ✅ | NTD khiếu nại → chờ Admin web duyệt → Giải ngân |
| E13 | Nạp tiền vào ví | `screens/menu_employer/employer_wallet_screen.dart` | 🔄 | UI ví; logic nạp thật chưa đủ |
| E14 | Lịch sử giao dịch | `screens/menu_employer/employer_wallet_screen.dart` | 🔄 | |
| E15 | Rút tiền | — | ❌ | |
| E16 | Tham khảo giá thị trường | `screens/reference/employer_market_rate_screen.dart` | ✅ | Route `/employer-reference` |
| E17 | Đánh giá Candidate | `job_day_end_flow_screen.dart` | ✅ | Bật dialog hỏi đánh giá sau giải ngân xong |
| E18 | Menu NTD | `screens/menu_employer/employer_menu_screen.dart` | ✅ | |
| E19 | Tin nhắn hub NTD | `screens/menu_employer/employer_messages_screen.dart` | ✅ | Tab Nhóm chat / Chat cá nhân |
| E20 | Danh sách nhóm (tab Nhóm) | `screens/chat/employer_groups_screen.dart` | ✅ | |
| E21 | Tìm việc / ứng viên (NTD) | `screens/employer/employer_search_screen.dart` | ✅ | |
| E22 | Thông báo NTD | `screens/employer/employer_notifications_screen.dart` | ✅ | |

---

## CHAT & MESSAGING (shared — đã làm nhiều)

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| CH1 | Danh sách hội thoại (ứng viên) | `screens/messaging/conversation_list_screen.dart` | ✅ | Tab Nhóm chat / Chat cá nhân |
| CH2 | Giao diện chat nhóm | `screens/chat/group_chat_screen.dart` | ✅ | Real-time Firestore |
| CH3 | Phòng chat thống nhất (1-1 + nhóm) | `screens/messaging/chat_room_screen.dart` | ✅ | Ảnh, file, vị trí, gọi, điểm danh |
| CH4 | Gửi lịch làm vào chat | `MessagingService.sendSchedule` | ✅ | Message type `schedule` |
| CH5 | Yêu cầu / kết quả điểm danh trong chat | `chat_room_screen.dart` | ✅ | `attendance_request`, check-in/out ảnh |
| CH6 | Chat 1-1 NTD ↔ ứng viên | `MessagingService.getOrCreateDirectChat` | ✅ | `chatType: direct` |
| CH7 | Chat 1-1 giữa thành viên (peer) | `MessagingService.getOrCreatePeerChat` | ✅ | Từ màn Thành viên; tab Chat cá nhân |
| CH8 | Quản lý nhóm | `screens/chat/group_management_screen.dart` | ✅ | Hình nền, mute, thành viên, rời/giải tán |
| CH9 | Danh sách thành viên + nhắn riêng | `_MembersScreen` trong `group_management_screen.dart` | ✅ | Peer + direct |
| CH10 | Swipe để trả lời tin | `widgets/swipe_to_reply.dart` | ✅ | User + NTD, nhóm + 1-1 |
| CH11 | Tắt thông báo nhóm (mute) | `group_management_screen.dart`, `MessagingController` | ✅ | Không badge/chuông/bong bóng khi mute |
| CH12 | Hình nền nhóm (đồng bộ Firestore) | `group_chat_service.saveGroupWallpaper*` | ✅ | Mọi thành viên thấy; tin hệ thống khi đổi |
| CH13 | Tìm tin trong nhóm | `screens/chat/search_messages_screen.dart` | ✅ | |
| CH14 | Gọi thoại / video | `screens/chat/call_screen.dart` | ✅ | Agora |
| CH15 | Bong bóng tin nhắn nổi | `widgets/floating_message_bubble.dart` | ✅ | Kéo ẩn; hiện lại khi tin mới |
| CH16 | Bong bóng chatbot nổi | `widgets/floating_chat_button.dart` | ✅ | |
| CH17 | Trả lời / thu hồi / ghim / reaction | `chat_room_screen.dart`, `MessagingController` | ✅ | |
| CH18 | Đồng bộ inbox / badge | `MessagingController`, `messaging_bootstrap.dart` | ✅ | Chuông + bong bóng dùng chung logic unread |
| CH19 | Auto tạo nhóm khi duyệt ứng viên | `candidates_controller.dart`, `group_chat_service.dart` | ✅ | `ensureJobGroup` / add member |
| CH20 | Trùng nhóm chat (1 job = 1 nhóm) | `group_chat_service.dart` | ⚠️ | Đã gom logic; cần kiểm tra data cũ trùng |

---

## ADMIN FEATURES

| # | Tính năng | Screen/File | Status | Ghi chú |
|---|---|---|---|---|
| A1 | Dashboard Admin | `screens/admin/admin_home_screen.dart` | 🔄 | Giải ngân + khiếu nại |
| A2 | Duyệt giải ngân NTD | `screens/admin/admin_disbursement_screen.dart` | ✅ | Cho phép GN / từ chối / đóng nhóm |
| A3 | Quản lý người dùng | — | ❌ | |
| A4 | Danh mục khiếu nại | `screens/shared/complaints_catalog_screen.dart` | ✅ | incidents + jobComplaints |
| A5 | Báo cáo doanh thu | — | ❌ | |

---

## FILE/FOLDER ĐÃ CÓ (thực tế trong repo)

```
lib/screens/
    home/                   # C1, S15
    job/                    # C3
    search/                 # C2
    schedule/               # C7
    stats/                  # C8, E9
    reference/              # C10, E16
    post/                   # E2, E3
    employer/               # E1, E4, E7, E21, E22
    chat/                   # CH2, CH8, CH9, CH13, CH14
    messaging/              # CH1, CH3, CH10
    menu_employer/          # E18–E19, tools
    menu_candidate/         # C13, C15
    attendance/             # C16, C17
    chatbot/                # S18
    notification/           # S17
lib/controller/
    home_controller.dart, job_detail_controller.dart
    job_post_controller.dart, candidates_controller.dart
    messaging_controller.dart, group_chat_controller.dart
    employer_stats_controller.dart, employer_reference_controller.dart
    ...
lib/data/
    models/                 # job_post, application, group_chat, messaging, attendance, ...
    services/               # messaging, group_chat, application, job_post, attendance, ...
```

---

## Thứ tự ưu tiên phát triển (cập nhật 2026-05)

**Đã xong (Phase chat + employer core):** E1–E5, E7–E9, E16, CH1–CH19, C1–C4, C7–C8, C10, C13–C17

**Tiếp theo đề xuất:**
1. S3 — Chọn role khi đăng ký
2. C6 — Màn danh sách đơn ứng tuyển
3. E10 → E11 — Hoàn thành job + thanh toán lương
4. E13–E15 — Ví đầy đủ (nạp/rút/lịch sử)
5. CH20 — Dọn duplicate `groupChats` trên Firestore (nếu còn)
6. Admin panel (A1–A5)
7. Reviews đầy đủ (C11, E17)
