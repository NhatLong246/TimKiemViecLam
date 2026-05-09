# FRONTEND & UI ARCHITECTURE

## 1. Bố cục & Phân chia Logic
- Tách biệt hoàn toàn giao diện (UI) và logic (Business Logic).
- Ưu tiên sử dụng `StatelessWidget` tối đa. Chỉ sử dụng `StatefulWidget` khi thực sự cần quản lý state cục bộ phức tạp.
- Cấu trúc thư mục UI: Phân chia rõ ràng `/screens` (các trang chính), `/widgets` (các component dùng chung), và `/theme` (chứa màu sắc, font chữ).
- Quản lý điều hướng: Sử dụng Named Routes một cách nhất quán để dễ dàng theo dõi và truyền tham số giữa các màn hình thay vì dùng Unnamed Routes lộn xộn.

## 2. Tiêu chuẩn Giao diện (Vibe/Design System)
- **Responsive:** UI phải hiển thị đẹp trên mọi kích thước màn hình điện thoại. Luôn bọc các list bằng `ListView` hoặc `SingleChildScrollView` để tránh lỗi tràn màn hình (overflow).
- **Tái sử dụng:** Buttons, Input Fields, và Cards phải dùng custom widgets có sẵn trước khi tạo mới:
  - `PrimaryButton` — `lib/common/widgets/primary_button.dart`
  - `CustomTextField` — `lib/common/widgets/custom_textfield.dart`
  - `SocialLoginButton` — `lib/common/widgets/social_login_button.dart`
  - `ProfileMenuItem` — `lib/common/widgets/profile_menu_item.dart`
  - `ProgressDots` — `lib/common/widgets/progress_dots.dart`
- **Màu sắc:** Chỉ dùng constants từ `lib/common/styles/app_colors.dart`. Không hardcode màu hex trực tiếp.
- **Typography:** Chỉ dùng constants từ `lib/common/styles/app_text_styles.dart`.

## 3. Navigation
- **Luôn dùng:** `Get.toNamed(AppRoutes.xxx)` hoặc `Get.offAllNamed(AppRoutes.xxx)`
- **KHÔNG dùng:** `Navigator.push()`, `Navigator.pushNamed()`, unnamed routes
- **Route constants:** Chỉ định nghĩa trong `lib/routes/app_routes.dart` — KHÔNG hardcode string `/ten-route` trực tiếp

## 4. Cấu trúc màn hình chuẩn
```dart
// Screen chỉ chứa UI
class XxxScreen extends StatelessWidget {
  const XxxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<XxxController>(); // hoặc Get.put()
    return Scaffold(...);
  }
}
// Business logic trong Controller
class XxxController extends GetxController { ... }
// Data trong Service
class XxxService { ... }
```

## 5. Điều hướng theo Role sau khi Login
- `role == "candidate"` → `Get.offAllNamed(AppRoutes.home)` (Candidate home)
- `role == "employer"` → `Get.offAllNamed(AppRoutes.employerHome)` (Employer dashboard)
- `role == "admin"` → `Get.offAllNamed(AppRoutes.adminHome)` (Admin panel)