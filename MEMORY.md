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
