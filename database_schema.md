# DATABASE SCHEMA — ViecNow

> **AI: Đọc file này trước khi tạo bất kỳ Model, Service, hoặc query Firebase/SQLite nào.**
> Đây là nguồn duy nhất định nghĩa tên field, collection, và kiểu dữ liệu.

---

## FIREBASE FIRESTORE

### Quy tắc đặt tên
- Collection: `camelCase` (ví dụ: `jobPosts`)
- Document ID: dùng UID từ Firebase Auth (cho user) hoặc `doc().id` auto-generate
- Field timestamp: dùng `FieldValue.serverTimestamp()` khi `set/update`, parse thành `Timestamp` khi `fromMap`
- **DUPLICATE KEY RULE:** Mỗi collection có Primary Key (PK) riêng — AI phải kiểm tra PK tồn tại trước khi `set()` hoặc `add()`

---

### Collection: `users`
**Path:** `users/{uid}`
**PK:** `uid` (= Firebase Auth UID)
**Duplicate check:** `await db.collection('users').doc(uid).get()` → nếu `exists` thì không tạo mới

| Field | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `uid` | `String` | ✅ | Firebase Auth UID |
| `role` | `String` | ✅ | `"candidate"` \| `"employer"` \| `"admin"` |
| `firstName` | `String` | ✅ | Họ |
| `lastName` | `String` | ✅ | Tên |
| `username` | `String` | ✅ | Tên đăng nhập (unique) |
| `email` | `String` | ✅ | Email đăng nhập |
| `phone` | `String` | ✅ | Số điện thoại |
| `gender` | `String?` | ❌ | `"male"` \| `"female"` \| `"other"` |
| `dateOfBirth` | `Timestamp?` | ❌ | Ngày sinh |
| `avatarUrl` | `String?` | ❌ | URL ảnh đại diện |
| `cccd` | `String?` | ❌ | Số CCCD/CMND |
| `cccdImageUrl` | `String?` | ❌ | URL ảnh CCCD |
| `isVerified` | `bool` | ✅ | Email đã xác thực chưa |
| `isActive` | `bool` | ✅ | Tài khoản còn hoạt động không |
| `createdAt` | `Timestamp` | ✅ | `FieldValue.serverTimestamp()` |
| `updatedAt` | `Timestamp` | ✅ | `FieldValue.serverTimestamp()` |

**Chỉ cho Employer thêm:**
| Field | Kiểu | Mô tả |
|---|---|---|
| `companyName` | `String?` | Tên công ty |
| `companyAddress` | `String?` | Địa chỉ công ty |
| `companyLogoUrl` | `String?` | Logo công ty |
| `walletBalance` | `double` | Số dư ví (default: 0.0) |
| `totalDeposited` | `double` | Tổng tiền đã nạp (default: 0.0) |
| `totalSpent` | `double` | Tổng tiền đã chi (default: 0.0) |
| `walletSpendingLimit` | `double?` | Hạn mức chi mỗi giao dịch từ ví (`null` = không giới hạn) |

**Chỉ cho Candidate thêm:**
| Field | Kiểu | Mô tả |
|---|---|---|
| `skills` | `List<String>` | Kỹ năng (default: []) |
| `cvUrl` | `String?` | URL file CV (PDF/DOC trên Storage) |
| `cvFileName` | `String?` | Tên file CV đã upload |
| `cvUpdatedAt` | `Timestamp?` | Lần upload CV gần nhất |
| `selfIntroduction` | `String?` | Giới thiệu bản thân |
| `workExperiences` | `List<Map>` | Kinh nghiệm: `{id, company, position, startDate, endDate?, currentlyWorking, description}` |
| `hasWorkExperience` | `bool?` | `false` = khai báo chưa có kinh nghiệm |
| `educations` | `List<Map>` | Học vấn |
| `projects` | `List<Map>` | Dự án |
| `certificates` | `List<Map>` | Chứng chỉ |
| `languages` | `List<Map>` | Ngoại ngữ |
| `allowEmployerDiscovery` | `bool?` | Cho NTD tìm thấy hồ sơ |
| `averageRating` | `double` | Đánh giá trung bình (default: 0.0) |
| `totalJobsDone` | `int` | Tổng số job đã hoàn thành (default: 0) |

---

### Collection: `jobPosts`
**Path:** `jobPosts/{jobId}`
**PK:** `jobId` (auto-generate bằng `db.collection('jobPosts').doc().id`)
**Duplicate check:** Kiểm tra Employer không đăng 2 job trùng `title + employerId + startDate`

| Field | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `jobId` | `String` | ✅ | Auto-generated ID |
| `employerId` | `String` | ✅ | UID của Employer |
| `title` | `String` | ✅ | Tên công việc |
| `description` | `String` | ✅ | Mô tả chi tiết |
| `category` | `String` | ✅ | Danh mục (xem danh sách bên dưới) |
| `jobType` | `String` | ✅ | `"part_time"` \| `"full_time"` |
| `location` | `Map<String,dynamic>` | ✅ | `{address, city, district, lat, lng}` |
| `salary` | `double` | ✅ | Mức lương |
| `salaryType` | `String` | ✅ | `"per_day"` \| `"per_hour"` \| `"per_month"` \| `"fixed"` |
| `slots` | `int` | ✅ | Số lượng cần tuyển |
| `filledSlots` | `int` | ✅ | Số lượng đã tuyển (default: 0) |
| `startDate` | `Timestamp` | ✅ | Ngày bắt đầu |
| `endDate` | `Timestamp?` | ❌ | Ngày kết thúc (null = full-time không xác định) |
| `workHoursPerDay` | `double?` | ❌ | Số giờ làm/ngày |
| `startTime` | `String?` | ❌ | Giờ bắt đầu (format: "HH:mm") |
| `requirements` | `String?` | ❌ | Yêu cầu ứng viên |
| `status` | `String` | ✅ | `"pending"` \| `"approved"` \| `"active"` \| `"closed"` \| `"rejected"` |
| `totalBudget` | `double` | ✅ | `salary × slots` (khóa tiền Employer) |
| `groupChatId` | `String?` | ❌ | ID nhóm chat (tạo sau khi approved) |
| `createdAt` | `Timestamp` | ✅ | Server timestamp |
| `updatedAt` | `Timestamp` | ✅ | Server timestamp |

**Danh mục công việc (`category`):**
`"boc_vac"` | `"lau_don"` | `"bung_be"` | `"phuc_vu"` | `"pha_che"` | `"tiep_thi"` | `"van_chuyen"` | `"bao_ve"` | `"other"`

---

### Collection: `applications`
**Path:** `applications/{appId}`
**PK:** `appId` (auto-generate)
**Duplicate check:** Mỗi `(candidateId + jobId)` chỉ được có 1 record → query trước khi tạo mới

| Field | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `appId` | `String` | ✅ | Auto-generated ID |
| `jobId` | `String` | ✅ | Ref đến `jobPosts/{jobId}` |
| `candidateId` | `String` | ✅ | UID của Candidate |
| `employerId` | `String` | ✅ | UID của Employer (denormalized) |
| `status` | `String` | ✅ | `"pending"` \| `"accepted"` \| `"rejected"` \| `"withdrawn"` |
| `cvUrl` | `String?` | ❌ | URL CV (chỉ cho full-time) |
| `coverLetter` | `String?` | ❌ | Thư xin việc |
| `appliedAt` | `Timestamp` | ✅ | Server timestamp |
| `updatedAt` | `Timestamp` | ✅ | Server timestamp |

---

### Collection: `groupChats`
**Path:** `groupChats/{groupId}`
**PK:** `groupId` (auto-generate, lưu vào `jobPosts/{jobId}.groupChatId`)
**Duplicate check:** Mỗi `jobId` chỉ có 1 group → kiểm tra `jobPosts/{jobId}.groupChatId != null`

| Field | Kiểu | Mô tả |
|---|---|---|
| `groupId` | `String` | Auto-generated ID |
| `jobId` | `String` | Ref đến job |
| `jobTitle` | `String` | Tên job (denormalized để hiển thị nhanh) |
| `employerId` | `String` | UID Employer (admin của group) |
| `memberIds` | `List<String>` | Danh sách UID members (Candidates được duyệt) |
| `createdAt` | `Timestamp` | Server timestamp |

**Sub-collection: `groupChats/{groupId}/messages/{msgId}`**

| Field | Kiểu | Mô tả |
|---|---|---|
| `msgId` | `String` | Auto-generated |
| `senderId` | `String` | UID người gửi |
| `content` | `String` | Nội dung tin nhắn |
| `type` | `String` | `"text"` \| `"schedule"` \| `"attendance_call"` \| `"system"` |
| `attachmentUrl` | `String?` | URL file đính kèm |
| `createdAt` | `Timestamp` | Server timestamp |

---

### Collection: `schedules`
**Path:** `schedules/{scheduleId}`
**PK:** `scheduleId`
**Duplicate check:** `(jobId + candidateId + date)` chỉ được 1 record

| Field | Kiểu | Mô tả |
|---|---|---|
| `scheduleId` | `String` | Auto-generated |
| `jobId` | `String` | Ref đến job |
| `candidateId` | `String` | UID Candidate |
| `employerId` | `String` | UID Employer |
| `date` | `String` | Format: `"YYYY-MM-DD"` |
| `startTime` | `String` | Format: `"HH:mm"` |
| `endTime` | `String` | Format: `"HH:mm"` |
| `status` | `String` | `"scheduled"` \| `"completed"` \| `"cancelled"` |
| `jobTitle` | `String?` | Denormalized — tên job (hiển thị lịch) |
| `jobLocation` | `String?` | Denormalized — địa điểm làm |
| `employerName` | `String?` | Denormalized — tên công ty / employer |
| `createdAt` | `Timestamp` | Server timestamp |

---

### Collection: `attendance`
**Path:** `attendance/{attendanceId}`
**PK:** `attendanceId`
**Duplicate check:** `(jobId + date)` chỉ được 1 attendance record per Employer

| Field | Kiểu | Mô tả |
|---|---|---|
| `attendanceId` | `String` | Auto-generated |
| `jobId` | `String` | Ref đến job |
| `groupId` | `String` | Ref đến group chat |
| `employerId` | `String` | Người điểm danh |
| `date` | `String` | `"YYYY-MM-DD"` |
| `expectedStartTime` | `String` | Giờ bắt đầu quy định (`"HH:mm"`) |
| `records` | `List<Map>` | `[{candidateId, checkInTime, status: "on_time"\|"late"\|"absent", lateMinutes}]` |
| `createdAt` | `Timestamp` | Server timestamp |

---

### Collection: `walletTransactions`
**Path:** `walletTransactions/{txId}`
**PK:** `txId` (auto-generate)
**Duplicate check:** MoMo nạp tiền — `orderId` unique per flow; chi ví — `idempotencyKey` nếu có

| Field | Kiểu | Mô tả |
|---|---|---|
| `userId` | `String` | UID employer |
| `type` | `String` | `"deposit"` \| `"payment"` \| `"withdrawal"` \| `"refund"` |
| `amount` | `double` | Số tiền (dương) |
| `description` | `String` | Mô tả hiển thị |
| `status` | `String` | `"pending"` \| `"completed"` \| `"failed"` |
| `paymentMethod` | `String?` | `"momo"` \| `"wallet"` |
| `orderId` | `String?` | Mã đơn MoMo |
| `requestId` | `String?` | Request MoMo |
| `payUrl` | `String?` | URL thanh toán MoMo |
| `momoTransId` | `String?` | Mã giao dịch MoMo sau khi thành công |
| `refundedAmount` | `double` | Số tiền đã hoàn từ giao dịch nạp (default: 0) |
| `refundOrderId` | `String?` | Mã đơn hoàn tiền MoMo (rút) |
| `sourceDepositOrderId` | `String?` | orderId giao dịch nạp gốc (rút) |
| `jobId` | `String?` | Job liên quan (khi chi) |
| `idempotencyKey` | `String?` | Tránh trừ ví trùng |
| `balanceBefore` | `double?` | Số dư trước (chi ví) |
| `balanceAfter` | `double?` | Số dư sau (chi ví) |
| `createdAt` | `Timestamp` | Server timestamp |
| `completedAt` | `Timestamp?` | Khi `status == completed` |

---

### Collection: `transactions`
**Path:** `transactions/{txnId}`
**PK:** `txnId` (auto-generate)
**Duplicate check:** Kiểm tra idempotency key trước khi tạo transaction mới

| Field | Kiểu | Mô tả |
|---|---|---|
| `txnId` | `String` | Auto-generated |
| `userId` | `String` | UID chủ sở hữu |
| `type` | `String` | `"deposit"` \| `"payment"` \| `"withdrawal"` \| `"refund"` \| `"hold"` |
| `amount` | `double` | Số tiền (luôn dương) |
| `balanceBefore` | `double` | Số dư trước giao dịch |
| `balanceAfter` | `double` | Số dư sau giao dịch |
| `jobId` | `String?` | Ref nếu liên quan đến job |
| `relatedUserId` | `String?` | UID đối tác (Candidate hoặc Employer) |
| `note` | `String?` | Ghi chú |
| `status` | `String` | `"pending"` \| `"completed"` \| `"failed"` |
| `createdAt` | `Timestamp` | Server timestamp |

---

### Collection: `disbursementNotices`
**Path:** `disbursementNotices/{noticeId}`  
Sau giải ngân — `employerAck` và `adminAck` phải `true` trước khi NTD xóa `jobPosts`.

| Field | Kiểu | Mô tả |
|---|---|---|
| `jobId` | `String` | ✅ |
| `groupId` | `String` | ✅ |
| `employerId` | `String` | ✅ |
| `workDate` | `String` | `YYYY-MM-DD` |
| `amount` | `double` | Số tiền giải ngân |
| `status` | `String` | `pending_ack` \| `cleared` |
| `employerAck` | `bool` | NTD đã xác nhận |
| `adminAck` | `bool` | Admin đã xác nhận |
| `createdAt` | `Timestamp` | ✅ |

### Collection: `jobComplaints`
**Path:** `jobComplaints/{complaintId}`  
Khiếu nại công việc từ ứng viên sau khi hoàn thành.

| Field | Kiểu | Mô tả |
|---|---|---|
| `jobId` | `String` | ✅ |
| `groupId` | `String` | ✅ |
| `employerId` | `String` | ✅ |
| `candidateId` | `String` | ✅ |
| `jobTitle` | `String` | ✅ |
| `description` | `String` | ✅ |
| `imageBase64s` | `List<String>` | Minh chứng |
| `status` | `String` | `pending` \| … |
| `createdAt` | `Timestamp` | ✅ |

**`jobPosts` thêm field:** `imageUrls` (`List<String>`) — ảnh minh họa bài đăng (base64 hoặc URL).

---

### Collection: `reviews`
**Path:** `reviews/{reviewId}`
**PK:** `reviewId`
**Duplicate check:** `(reviewerId + revieweeId + jobId)` chỉ được 1 đánh giá

| Field | Kiểu | Mô tả |
|---|---|---|
| `reviewId` | `String` | Auto-generated |
| `jobId` | `String` | Job liên quan |
| `reviewerId` | `String` | Người đánh giá |
| `revieweeId` | `String` | Người được đánh giá |
| `rating` | `double` | 1.0 → 5.0 |
| `comment` | `String?` | Nội dung đánh giá |
| `createdAt` | `Timestamp` | Server timestamp |

---

## SQLITE (Local Cache)

> **Mục đích:** Cache dữ liệu để xem offline. KHÔNG phải nguồn dữ liệu chính.
> Sync: Firebase → SQLite mỗi khi có kết nối mạng.

### Table: `cached_jobs`
```sql
CREATE TABLE IF NOT EXISTS cached_jobs (
    jobId TEXT PRIMARY KEY,
    employerId TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT,
    jobType TEXT,
    location TEXT,         -- JSON string của Map location
    salary REAL,
    salaryType TEXT,
    slots INTEGER,
    startDate INTEGER,     -- Timestamp milliseconds
    status TEXT,
    cachedAt INTEGER       -- Timestamp milliseconds khi cache
);
```
**Duplicate key:** `jobId` — dùng `INSERT OR REPLACE INTO cached_jobs` thay vì `INSERT`

### Table: `saved_jobs`
```sql
CREATE TABLE IF NOT EXISTS saved_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    jobId TEXT NOT NULL UNIQUE,
    savedAt INTEGER
);
```
**Duplicate key:** `jobId` — dùng `INSERT OR IGNORE INTO saved_jobs`

### Table: `cached_profile`
```sql
CREATE TABLE IF NOT EXISTS cached_profile (
    uid TEXT PRIMARY KEY,
    role TEXT,
    firstName TEXT,
    lastName TEXT,
    email TEXT,
    phone TEXT,
    avatarUrl TEXT,
    cachedAt INTEGER
);
```
**Duplicate key:** `uid` — dùng `INSERT OR REPLACE INTO cached_profile`

---

## Quy tắc bắt buộc khi làm việc với schema này
1. **Không tự ý thêm field mới** vào Firestore mà không cập nhật file này trước.
2. **Tên field phải khớp chính xác** (case-sensitive) giữa Dart Model và Firestore document.
3. **Timestamp:** Luôn dùng `FieldValue.serverTimestamp()` khi write, cast `(map['field'] as Timestamp?)?.toDate()` khi read.
4. **Double precision:** Luôn dùng `(map['salary'] as num?)?.toDouble() ?? 0.0` để tránh lỗi int/double casting.
5. **Trước khi set() vào Firestore:** Kiểm tra document tồn tại bằng `.get()` → `snapshot.exists`.
6. **SQLite:** Luôn dùng `INSERT OR REPLACE` / `INSERT OR IGNORE` — không dùng bare `INSERT`.
