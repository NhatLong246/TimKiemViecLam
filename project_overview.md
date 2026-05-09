# PROJECT OVERVIEW — ViecNow

> **AI: ĐỌC FILE NÀY ĐẦU TIÊN trước khi bắt đầu bất kỳ task nào.**

## 1. Thông tin cơ bản
- **Tên app:** ViecNow
- **Package name:** `viecnow`
- **Mô tả:** Nền tảng kết nối Nhà tuyển dụng ↔ Người tìm việc, tập trung công việc part-time/full-time cho sinh viên (bưng bê, lau dọn, phục vụ, pha chế,...)
- **Stack:** Flutter · GetX (state + navigation) · Firebase Auth · Cloud Firestore · SQLite · SharedPreferences

---

## 2. Vai trò người dùng (Roles)
| Giá trị `role` | Tên hiển thị | Quyền hạn chính |
|---|---|---|
| `"candidate"` | Người tìm việc | Tìm việc, nộp đơn, xem lịch làm, nhận lương |
| `"employer"` | Nhà tuyển dụng | Đăng job, nạp tiền, quản lý nhân sự, điểm danh |
| `"admin"` | Quản trị viên | Duyệt job, xử lý tranh chấp, quản lý nền tảng |

> **Field lưu role:** `users/{uid}.role` → `"candidate"` | `"employer"` | `"admin"`
> **KHÔNG dùng số (0,1,2) để đại diện role. Luôn dùng string.**

---

## 3. Loại công việc (Job Types)
| Giá trị `jobType` | Tên | Đặc điểm |
|---|---|---|
| `"part_time"` | Part-time | Ngắn hạn, theo ngày/công, không cần CV, thanh toán ngay khi hoàn thành |
| `"full_time"` | Full-time | Dài hạn, theo giờ/tháng, cần CV + phỏng vấn, thanh toán định kỳ |

---

## 4. Quy trình Part-time (luồng chính)
```
[Employer] Nạp tiền vào ví
    → Tạo job (chọn slots, salary/slot, địa chỉ, ngày làm)
    → [Admin] Kiểm duyệt → Duyệt / Từ chối
    → Hiển thị cho Candidates
    → [Candidate] Đề xuất tham gia
    → [Employer] Duyệt Candidate
    → Tạo Group Chat tự động
    → [Employer] Phổ biến công việc trong nhóm chat
    → [Candidate] Thêm vào Lịch làm
    → Tới ngày làm: [Employer] Điểm danh (đúng giờ / trễ / vắng)
    → [Employer + Candidate] Xác nhận hoàn thành
    → Thanh toán lương tự động từ ví Employer → ví/tài khoản Candidate
    → (Nếu tranh chấp) Candidates khác xác nhận → Trừ tiền / Yêu cầu bồi thường
```

## 5. Quy trình Full-time (luồng chính)
```
[Employer] Tạo job (lương theo giờ, số giờ/ngày, địa chỉ)
    → [Admin] Kiểm duyệt → Duyệt / Từ chối
    → Hiển thị cho Candidates
    → [Candidate] Nộp CV
    → [Employer] Gọi phỏng vấn
    → [Employer + Candidate] Xác nhận nhận việc
    → Tạo Group Chat tự động
    → [Employer] Thêm lịch làm hàng tuần vào nhóm chat
    → Điểm danh hàng ngày
    → Thanh toán lương vào ngày đã thỏa thuận (thông báo trong nhóm chat)
    → (Tranh chấp xử lý tương tự Part-time)
```

---

## 6. Tính năng đặc biệt
- **Nhóm User (Lead Group):** Candidates tự lập nhóm → Employer có thể thuê cả nhóm
- **Wallet (Ví Employer):** Nạp tiền trước → Hệ thống giữ → Thanh toán sau xác nhận
- **Điểm danh thông minh:** Dựa theo giờ thiết lập; tự tính trễ/đúng giờ/vắng; Employer có thể tùy chỉnh
- **Đánh giá 2 chiều:** Sau mỗi job, cả 2 phía đánh giá lẫn nhau
- **Tham khảo giá:** So sánh mức lương của job với mặt bằng chung khu vực (theo loại công việc, địa điểm)
- **Bảo hiểm lao động:** Hỗ trợ thông tin bảo hiểm cho người lao động

---

## 7. Dashboard Candidate (Bottom Navigation)
| Tab | Chức năng |
|---|---|
| Home | Feed công việc, tìm kiếm |
| Tham khảo | Giá mặt bằng chung (lương, đi lại, độ tuổi, sức khỏe) |
| Thống kê | Công việc đã làm, thu nhập |
| Lịch làm | Lịch tuần/tháng/năm |
| Phân loại | Danh mục công việc (bốc vác, phục vụ,...) |
| Hồ sơ | CV, đánh giá từ Employer |
| Chi tiết khác | Tin nhắn, phản hồi, kiến nghị |
| Tôi | Tài khoản, cài đặt |

## 8. Dashboard Employer (Bottom Navigation)
| Tab | Chức năng |
|---|---|
| Home | Tổng quan, tìm Candidate |
| Tham khảo | Giá mặt bằng chung |
| Thống kê | Jobs đã tạo, chi tiêu, số người thuê |
| Bài đăng | CRUD tin tuyển dụng |
| Hồ sơ người thuê | Danh sách Candidates đã/đang làm |
| Lịch làm | Quản lý lịch, điểm danh, đánh giá |
| Chi tiết khác | Tin nhắn, phản hồi |
| Tôi | Tài khoản, ví, cài đặt |

---

## 9. Trạng thái màn hình hiện tại
### ✅ Đã hoàn thành
- `SplashScreen`, `OnboardingScreen`
- Auth: `LoginScreen`, `RegisterScreen`, `ForgetPasswordScreen`, `VerifyEmailScreen`, `RegisterSuccessScreen`, `ResetEmailSentScreen`
- Profile: `UpdateAccountScreen`, `ChangeNameScreen`, `ChangeUsernameScreen`, `ChangeEmailScreen`, `ChangePhoneNumberScreen`, `ChangeGenderScreen`, `ChangeDateofBirthScreen`
- Bank Account: `MyBankAccountScreen`, `AddEditBankAccountScreen`
- Home skeleton: `MainNavigationScreen`, `HomeScreen`

### ❌ Chưa làm
- Job listing, Job Search, Job Detail, Apply Job
- Employer: Post Job, Manage Applications, Manage Employees
- Group Chat (in-app messaging)
- Attendance & Schedule
- Wallet: Deposit, Withdraw, Transaction History
- CV Builder (for full-time Candidates)
- Admin Panel
- Reviews & Ratings
- Reference Pricing (market rate comparison)
- Lead Group (nhóm User)

---

## 10. Lưu ý kỹ thuật quan trọng
- Navigation: Dùng **GetX named routes** (`Get.toNamed(AppRoutes.xxx)`), KHÔNG dùng `Navigator.push` hay unnamed routes
- State management: **GetX** (`GetxController`, `GetBuilder`, `Obx`)
- Auth state: `AuthController` (đặt trong `login_controller.dart`) — được `Get.put()` tại `main.dart`
- **`app_routes.dart` hiện có duplicate keys** (`forgetPassword` và `home` bị khai báo 2 lần trong `routes` map) — cần fix khi refactor routes
