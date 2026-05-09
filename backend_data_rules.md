# BACKEND, DATABASE & API LOGIC

## 1. Chiến lược Dữ liệu (Firebase & SQLite)
- **Firebase:** Đóng vai trò là Single Source of Truth (nguồn dữ liệu gốc) cho các thông tin online (tài khoản, danh sách công việc real-time).
- **SQLite:** Sử dụng để cache dữ liệu local, giúp sinh viên có thể xem lại công việc đã lưu ngay cả khi mất mạng.
- **Sync Logic:** Khi có mạng, ưu tiên fetch từ Firebase và lưu xuống SQLite. Khi mất mạng, đọc từ SQLite.

## 2. Xử lý API & Trùng lặp (Duplicate Keys)
- **Kiểm tra trùng lặp:** TRƯỚC KHI thực hiện bất kỳ lệnh `INSERT` nào vào SQLite hoặc `set()` vào Firebase, LUÔN LUÔN phải có logic kiểm tra sự tồn tại của khóa chính (Primary Key / Document ID).
- Bắt lỗi bằng `try-catch` nghiêm ngặt cho TẤT CẢ các lời gọi Firebase/API. In ra log rõ ràng khi có lỗi.
- Không bao giờ lưu trực tiếp dữ liệu thô. Mọi dữ liệu trả về từ Firebase/SQLite phải được parse qua các Model Classes (sử dụng `fromMap` và `toMap`).

## 3. Primary Keys theo Collection (xem `database_schema.md` để đầy đủ)
| Collection | PK | Cách kiểm tra duplicate |
|---|---|---|
| `users` | `uid` | `.doc(uid).get()` → `snapshot.exists` |
| `jobPosts` | `jobId` | auto-gen; check `title+employerId+startDate` |
| `applications` | `appId` | query `candidateId == x AND jobId == y` trước khi tạo |
| `groupChats` | `groupId` | check `jobPosts/{jobId}.groupChatId != null` |
| `reviews` | `reviewId` | query `reviewerId+revieweeId+jobId` trước khi tạo |
| `transactions` | `txnId` | auto-gen; dùng idempotency key |

## 4. Casting an toàn khi đọc từ Firestore
```dart
// Timestamp
(map['createdAt'] as Timestamp?)?.toDate()
// double (tránh lỗi int cast)
(map['salary'] as num?)?.toDouble() ?? 0.0
// String nullable
(map['avatarUrl'] as String?)
// List
(map['memberIds'] as List<dynamic>?)?.cast<String>() ?? []
```

## 5. SQLite — Luôn dùng UPSERT thay vì INSERT
```dart
// ĐÚNG
await db.rawInsert('INSERT OR REPLACE INTO cached_jobs VALUES (?,...)', [jobId,...]);
// SAI — có thể gây lỗi UNIQUE constraint
await db.rawInsert('INSERT INTO cached_jobs VALUES (?,...)', [jobId,...]);
```