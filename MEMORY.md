# MEMORY — ViecNow Project State

> **AI: Đọc file này + `project_overview.md` trước khi bắt đầu session mới.**
> Sau khi hoàn thành feature, cập nhật section "Completed Features" và "Known Issues".

---

## Thông tin project
- **Package:** `viecnow` | **Stack:** Flutter · GetX · Firebase Auth · Firestore · SQLite
- **Màn hình quản lý route:** `lib/routes/app_routes.dart` (dùng `Map<String,WidgetBuilder>`) + `lib/routes/app_pages.dart` (GetX `GetPage`)
- **Auth controller:** `class AuthController` trong `lib/controller/login_controller.dart` — được `Get.put()` tại `main.dart`
- **State management:** GetX (`GetxController`, `GetBuilder`, `Obx`)

---

## Completed Features ✅
| Feature | File chính | Ghi chú |
|---|---|---|
| Splash | `screens/spalsh/splash_screen.dart` | Lưu ý: folder tên `spalsh` (typo) |
| Onboarding | `screens/onboarding/onboarding_screen.dart` | |
| Login | `screens/auth/login_screen.dart` | |
| Register | `screens/auth/register_screen.dart` | Chưa có chọn role |
| Forget/Reset Password | `screens/auth/forget_password_screen.dart` | |
| Verify Email | `screens/auth/verify_email_screen.dart` | |
| Update Account | `screens/profile/update_account_screen.dart` | |
| Change Name/Username/Email/Phone/Gender/DOB | `screens/profile/change_*.dart` | 6 màn hình |
| Bank Account (CRUD) | `screens/bank_account/` | |
| Shipping Address (CRUD) | `screens/shipping_address/` | Legacy từ template cũ |
| Main Navigation | `screens/home/main_navigation_screen.dart` | Bottom nav skeleton |
| Job feed + detail + apply | `home_screen.dart`, `job_detail_screen.dart` | C1–C4 |
| Employer post/manage jobs | `post/create_post_screen.dart`, `post_management_screen.dart` | E2–E3 |
| Employer candidates accept | `employer_candidates_screen.dart`, `candidates_controller.dart` | E4–E5, auto group chat |
| Chat nhóm + messaging hub | `group_chat_screen.dart`, `chat_room_screen.dart`, `conversation_list_screen.dart` | CH1–CH7 |
| Peer chat, swipe reply, mute, wallpaper | `messaging_service.dart`, `group_management_screen.dart` | CH7–CH12 |
| Attendance (NTD + UV) | `attendance_screen.dart`, `candidate_attendance_screen.dart` | E7, C16 |
| Stats + market reference | `employer_stats_screen.dart`, `*_market_rate_screen.dart` | E9, E16, C8, C10 |
| Chatbot + floating bubbles | `chatbot_screen.dart`, `floating_*_bubble.dart` | S18, CH15–CH16 |

> **Bản đồ đầy đủ:** xem `feature_map.md` (đã rà soát 2026-05-20).

---

## Known Issues ⚠️
| Issue | File | Mức độ | Ghi chú |
|---|---|---|---|
| Duplicate keys trong routes map | `app_routes.dart` | Medium | `forgetPassword` và `home` khai báo 2 lần |
| `AuthController` tên trùng | `login_controller.dart` | Low | Class tên `AuthController` nhưng file tên `login_controller` |
| Chưa có logic chọn role khi đăng ký | `register_screen.dart` | High | Cần thêm cho feature S3 |
| `app_pages.dart` chỉ có Splash + Onboarding | `app_pages.dart` | Medium | Các route khác chỉ dùng `routes` map |

---

## Session Log (cập nhật mỗi lần hoàn thành feature)
| Ngày | Feature hoàn thành | Thay đổi chính |
|---|---|---|
| 2026-05-11 | E1 — Employer Home / Quản lý | Tạo `screens/employer/employer_home_screen.dart`, `employer_main_navigation_screen.dart`. Thêm route `employerHome` vào `app_routes.dart` |
| 2026-05-13 | E2 — Quản lý Bài đăng | Tạo `data/models/job_post_model.dart`, `data/services/job_post_service.dart`, `controller/job_post_controller.dart`, `screens/post/post_management_screen.dart`, `screens/post/create_post_screen.dart`. Thêm route `postManagement`, `createPost`. Kết nối nút "Bài đăng" trong employer_home_screen. |
| 2026-05-12 | E16 — Employer Tham khảo giá | Tạo `data/models/market_rate_model.dart`, `data/services/market_rate_service.dart`, `controller/employer_reference_controller.dart`, `screens/reference/employer_market_rate_screen.dart`. Route: `employerReference = /employer-reference`. Quick tool "Tham khảo" trên Home đã navigate đến màn này. |
| 2026-05-13 | E9 — Employer Thống kê | Tạo `data/models/employer_stats_model.dart`, `data/services/employer_stats_service.dart`, `controller/employer_stats_controller.dart`, `screens/stats/employer_stats_screen.dart`. Package fl_chart thêm vào pubspec. Route: `employerStats = /employer-stats`. Thêm tab "Thống kê" vào EmployerMainNavigationScreen (index 2). Gồm: 6 stat cards, 3 biểu đồ (Bar+Line chi tiêu & tuyển dụng, Area nạp tiền, Bar bài đăng), filter Ngày/Tuần/Tháng/Năm, date range picker. |
| 2026-05-20 | Rà soát `feature_map.md` | Đánh dấu ✅ toàn bộ tính năng đã làm (auth, candidate home/search/apply, employer post/candidates/stats, chat CH1–CH19, attendance, notifications, chatbot). |

---

## ROADMAP — Group Chat + Worker Management (bắt đầu 2026-05-14)

> **Mục tiêu:** Cho phép Employer tương tác và quản lý nhân viên đang làm việc thông qua:
> nhắn tin nhóm, chia sẻ lịch làm, điểm danh check-in/check-out, báo cáo sự cố.
> **Tech:** Firestore real-time (đã có) + Firebase Storage (đã có) + firebase_messaging (thêm mới)

### Tổng quan các bước

| Bước | Nội dung | Status | Files tạo/sửa |
|---|---|---|---|
| B1 | Thêm packages vào pubspec.yaml | ✅ | `pubspec.yaml` — thêm firebase_messaging ^16.2.0, flutter_local_notifications ^18.0.1, cached_network_image ^3.4.1, permission_handler ^11.4.0 |
| B2 | Tạo Models | ✅ | `data/models/group_chat_model.dart`, `chat_message_model.dart`, `attendance_model.dart`, `incident_model.dart` |
| B3 | Tạo Services | ✅ | `data/services/group_chat_service.dart`, `attendance_service.dart` |
| B4 | Tạo Controllers | ✅ | `controller/group_chat_controller.dart`, `attendance_controller.dart` |
| B5 | Màn hình danh sách Groups | ✅ | `screens/chat/employer_groups_screen.dart` |
| B6 | Màn hình Group Chat Detail (nhắn tin) | ✅ | `screens/chat/group_chat_screen.dart` |
| B7 | Màn hình Điểm danh | ✅ | `screens/employer/attendance_screen.dart` |
| B8 | Tích hợp: auto-tạo group khi duyệt ứng viên | ✅ | `controller/candidates_controller.dart` — `accept()` gọi `_handleGroupChat()`: tạo group mới hoặc addMember nếu group đã có |
| B9 | Thêm tab "Nhóm" vào EmployerMainNavigationScreen | ✅ | `screens/employer/employer_main_navigation_screen.dart` — 4 tabs: Danh mục/Home/Nhóm/Cá nhân |

---

### Chi tiết từng bước

#### B1 — Thêm packages
Thêm vào `pubspec.yaml` dependencies:
- `firebase_messaging: ^15.x.x` — Push notifications (BẮT BUỘC)
- `flutter_local_notifications: ^18.x.x` — Banner khi app đang mở
- `cached_network_image: ^3.x.x` — Load ảnh avatar/điểm danh hiệu quả
- `permission_handler: ^11.x.x` — Xin quyền camera + notification

#### B2 — Models
- `GroupChatModel`: groupId, jobId, jobTitle, employerId, memberIds, createdAt
- `ChatMessageModel`: msgId, senderId, content, type, attachmentUrl, createdAt
- `AttendanceModel`: attendanceId, jobId, groupId, employerId, date, expectedStartTime, records[]
- `AttendanceRecord` (sub-class): candidateId, checkInTime, checkOutTime, status, lateMinutes, checkInPhotoUrl, checkOutPhotoUrl
- `IncidentModel`: incidentId, groupId, jobId, reportedBy, workerId, description, photoUrl, amount, status, createdAt

#### B3 — Services (Firestore operations)
- `GroupChatService`:
  - `createGroup(jobId, jobTitle, employerId, memberIds)` → tạo doc, cập nhật `jobPosts/{jobId}.groupChatId`
  - `addMemberToGroup(groupId, candidateId)` → arrayUnion
  - `sendMessage(groupId, message)` → add to subcollection
  - `streamMessages(groupId)` → real-time stream
  - `streamMyGroups(employerId)` → stream groups list
- `AttendanceService`:
  - `createAttendanceSession(session)` → tạo doc trong `attendance`
  - `updateRecord(attendanceId, candidateId, data)` → update 1 record trong records[]
  - `streamAttendanceByJob(jobId)` → stream danh sách điểm danh

#### B4 — Controllers
- `GroupChatController` (GetxController):
  - `groups: RxList<GroupChatModel>`
  - `messages: RxList<ChatMessageModel>`
  - `currentGroupId: RxString`
  - `isLoading: RxBool`
  - `sendMessage(content, type)` → gọi service
  - `loadGroup(groupId)` → stream messages
- `AttendanceController` (GetxController):
  - `sessions: RxList<AttendanceModel>`
  - `currentSession: Rx<AttendanceModel?>`
  - `createSession(jobId, groupId, date, expectedTime)` → gọi service
  - `markRecord(candidateId, status)` → update record

#### B5 — EmployerGroupsScreen
- Danh sách các group chat (mỗi group = 1 job đã approved + có ứng viên được duyệt)
- Card: tên job, số thành viên, tin nhắn cuối cùng, thời gian
- FAB hoặc context: vào điểm danh cho group đó
- Navigation → GroupChatScreen

#### B6 — GroupChatScreen (nhắn tin)
- AppBar: tên job, số thành viên, nút điểm danh
- Danh sách tin nhắn (reverse ListView, real-time)
- Tin nhắn dạng bubble: text, schedule card, attendance_call card, system message
- Input bar: text + ảnh + nút gửi
- Special actions: "Chia sẻ lịch làm" → gửi message type='schedule', "Điểm danh" → navigate AttendanceScreen

#### B7 — AttendanceScreen
- Header: ngày hôm nay, job, giờ bắt đầu
- Danh sách workers dạng bảng: tên, ảnh avatar, trạng thái (✅ đúng giờ / ⏰ trễ / ❌ vắng)
- Nút "Bắt đầu điểm danh" → tạo session mới
- Mỗi worker: employer tap để chọn trạng thái, hoặc xem ảnh check-in mà worker tự upload
- Nút "Lưu điểm danh"

#### B8 — Tích hợp vào Candidates Screen
- Khi Employer duyệt ứng viên (status → 'accepted'):
  - Nếu chưa có `groupChatId` trên job: tạo group mới
  - Nếu đã có: add candidate vào `memberIds`
  - Hiển thị SnackBar "Đã tạo nhóm chat / Đã thêm vào nhóm"

#### B9 — Tab Navigation
- Thêm tab "Nhóm" (icon: `Icons.group`) vào `EmployerMainNavigationScreen`
- Index: sau "Thống kê" → index 3
- Destination: `EmployerGroupsScreen`

---

### Routes cần thêm
```dart
static const groupsList   = '/employer-groups';
static const groupChat    = '/group-chat';      // args: groupId
static const attendance   = '/attendance';       // args: groupId, jobId
```

### Quy tắc quan trọng khi code feature này
- Mọi message phải có `senderId = currentUser.uid`
- Chỉ Employer mới có thể tạo group, gửi `schedule`/`attendance_call` messages
- Khi tạo attendance session: kiểm tra `(jobId + date)` chưa tồn tại trước khi tạo mới
- Upload ảnh điểm danh: path = `attendance/{attendanceId}/{candidateId}_checkin.jpg`
- Không dùng số để đại diện role, luôn dùng string: `"employer"`, `"candidate"`

---

## Luồng hoạt động chính — Group Chat & Điểm danh

```
Employer duyệt ứng viên
    → Group chat tự động tạo / ứng viên được add vào
    → Employer vào tab "Nhóm" xem danh sách nhóm
    → Mở nhóm → nhắn tin, gửi lịch, bấm "Điểm danh"
    → Màn hình điểm danh: đánh dấu đúng giờ / trễ / vắng → lưu
```
