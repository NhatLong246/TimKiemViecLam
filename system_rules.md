# SYSTEM RULES & AI BEHAVIOR

---

## 0. GIAO THỨC TỰ ĐỘNG — Áp dụng cho MỌI yêu cầu (không cần nhắc lại)

> AI phải tự xác định loại task và đọc đúng file MD tương ứng **trước khi làm bất cứ điều gì**.

### Bảng tự động chọn file cần đọc theo loại task

| Loại task | Files bắt buộc đọc (theo thứ tự) |
|---|---|
| Bắt đầu session / không rõ context | `MEMORY.md` → `project_overview.md` |
| Tạo màn hình / widget mới | `MEMORY.md` → `project_overview.md` → `feature_map.md` → `frontend_ui_rules.md` → file screen liên quan |
| Tạo / sửa Model, Service, Controller | `MEMORY.md` → `database_schema.md` → `backend_data_rules.md` → file liên quan |
| Tích hợp Firebase / SQLite / API | `database_schema.md` → `backend_data_rules.md` |
| Sửa bug | `MEMORY.md` (xem Known Issues) → file bị lỗi |
| Thêm route / navigation | `project_overview.md` → `lib/routes/app_routes.dart` → `lib/routes/app_pages.dart` |
| Hoàn thành 1 feature | Cập nhật `feature_map.md` (đổi ❌ → ✅) + ghi vào `MEMORY.md` Session Log |
| Hỏi kế hoạch / thiết kế | `project_overview.md` → `feature_map.md` |

### Quy tắc tự phân loại
- Có từ "màn hình", "screen", "UI", "giao diện", "widget" → loại **UI**
- Có từ "model", "service", "firebase", "firestore", "sqlite", "data", "api" → loại **Data**
- Có từ "lỗi", "bug", "fix", "sửa", "không chạy" → loại **Bug**
- Có từ "làm", "tạo", "thêm tính năng" + tên feature → loại **UI + Data** (đọc cả hai nhánh)
- Không rõ loại → đọc `MEMORY.md` + `project_overview.md` trước, rồi hỏi lại nếu cần

---

## 1. Quy trình làm việc bắt buộc (Bảo vệ Token & Tránh sai sót)
- **Đọc trước khi viết:** Áp dụng bảng trên, đọc đủ context trước khi đề xuất code. Không được đoán mò.
- **Suy nghĩ từng bước:** Trước khi code, trình bày ngắn gọn: "Tôi sẽ tạo/sửa file X với logic Y."
- **Tối ưu Token:** Chỉ output phần code thay đổi. Dùng `// ... existing code ...` cho phần giữ nguyên. TUYỆT ĐỐI KHÔNG in lại toàn bộ file nếu chỉ sửa vài dòng.

## 2. Giới hạn quyền hạn (Guardrails)
- KHÔNG tự ý thêm package vào `pubspec.yaml` nếu chưa hỏi.
- KHÔNG tự ý xóa code cũ nếu chưa phân tích và được đồng ý.
- Chỉ tập trung task hiện tại, không tự ý refactor sang tính năng khác.

## 3. Chống "Quên" Code
- Sau mỗi feature hoàn thành: cập nhật `feature_map.md` + ghi vào `MEMORY.md` Session Log.
- Nếu phát hiện bug mới trong quá trình làm: ghi vào `MEMORY.md` phần Known Issues ngay lập tức.

## 4. Checklist trước khi output code
- [ ] Đã đọc đúng file MD theo bảng phân loại ở Mục 0?
- [ ] Tên field/collection có khớp với `database_schema.md`?
- [ ] Widget có sẵn trong `common/widgets/` đã được tận dụng chưa?
- [ ] Navigation dùng `Get.toNamed(AppRoutes.xxx)` chưa?
- [ ] Có duplicate key nào không (kiểm tra PK trước khi write Firebase/SQLite)?
