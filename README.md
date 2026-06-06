# ViecNow

ViecNow là ứng dụng kết nối việc làm được phát triển bằng Flutter, tập trung hỗ trợ
người tìm việc và nhà tuyển dụng trong toàn bộ quy trình tuyển dụng, làm việc và
thanh toán. Hệ thống hướng đến các công việc bán thời gian và toàn thời gian,
đặc biệt phù hợp với sinh viên, người lao động phổ thông và doanh nghiệp có nhu
cầu tuyển dụng linh hoạt.

Ứng dụng sử dụng Firebase làm nền tảng backend, GetX để quản lý trạng thái và
điều hướng, đồng thời tích hợp nhắn tin thời gian thực, gọi thoại/video, chấm
công GPS, thông báo đẩy, chatbot AI và ví thanh toán thử nghiệm.

## Mục tiêu dự án

- Số hóa quá trình tìm kiếm, ứng tuyển và quản lý công việc.
- Kết nối trực tiếp ứng viên với nhà tuyển dụng.
- Hỗ trợ quản lý ca làm, chấm công và giải ngân tiền công.
- Cung cấp kênh trao đổi minh bạch thông qua chat, gọi thoại/video và khiếu nại.
- Hỗ trợ quản trị viên giám sát một số nghiệp vụ quan trọng của nền tảng.

## Vai trò người dùng

| Vai trò | Chức năng chính |
| --- | --- |
| Ứng viên (`candidate`) | Tìm việc, ứng tuyển, quản lý hồ sơ/CV, xem lịch làm, chấm công, nhắn tin và theo dõi thu nhập |
| Nhà tuyển dụng (`employer`) | Đăng tin, quản lý ứng viên, phân công lịch làm, điểm danh, nhắn tin, đánh giá và giải ngân |
| Quản trị viên (`admin`) | Duyệt giải ngân và xử lý các khiếu nại trên hệ thống |

## Chức năng nổi bật

### Dành cho ứng viên

- Đăng ký, đăng nhập và quản lý thông tin tài khoản.
- Tạo hồ sơ nghề nghiệp gồm kỹ năng, kinh nghiệm, học vấn, dự án và chứng chỉ.
- Tìm kiếm công việc theo từ khóa, mức lương, vị trí và khoảng cách.
- Xem chi tiết, lưu và ứng tuyển công việc bán thời gian.
- Theo dõi lịch làm việc, phân công ca, chấm công bằng hình ảnh và vị trí GPS.
- Theo dõi thống kê công việc và thu nhập.
- Nhắn tin cá nhân, tham gia nhóm công việc và thực hiện cuộc gọi thoại/video.
- Gửi khiếu nại và đánh giá nhà tuyển dụng.

### Dành cho nhà tuyển dụng

- Tạo, chỉnh sửa, quản lý và theo dõi tin tuyển dụng.
- Tìm kiếm ứng viên, xem hồ sơ và duyệt hoặc từ chối đơn ứng tuyển.
- Tự động tạo nhóm chat khi ứng viên được chấp nhận.
- Lập lịch làm việc, phân công ca và theo dõi chấm công.
- Xử lý quy trình kết thúc công việc, đánh giá và giải ngân tiền công.
- Theo dõi thống kê tuyển dụng, chi tiêu và giá nhân công tham khảo.
- Quản lý ví và giao dịch thanh toán MoMo trong môi trường thử nghiệm.

### Giao tiếp và hỗ trợ

- Chat thời gian thực bằng Cloud Firestore.
- Chat cá nhân, chat nhóm, gửi ảnh, tệp, âm thanh, vị trí và lịch làm việc.
- Trả lời, thu hồi, ghim, tìm kiếm và tương tác với tin nhắn.
- Gọi thoại và gọi video thông qua Agora RTC.
- Thông báo trong ứng dụng, thông báo cục bộ và Firebase Cloud Messaging.
- Chatbot AI hỗ trợ tư vấn nghề nghiệp và giải đáp thông tin việc làm.

### Dành cho quản trị viên

- Duyệt hoặc từ chối yêu cầu giải ngân.
- Xem và xử lý danh mục khiếu nại.

> Màn hình quản trị hiện được tích hợp trong ứng dụng Flutter và chưa phải một
> hệ thống Web Admin độc lập.

## Công nghệ sử dụng

| Nhóm | Công nghệ |
| --- | --- |
| Ứng dụng | Flutter, Dart |
| Quản lý trạng thái và điều hướng | GetX |
| Xác thực | Firebase Authentication, Google Sign-In, Facebook Login |
| Cơ sở dữ liệu | Cloud Firestore, SQLite |
| Lưu trữ cục bộ | SharedPreferences, SQLite |
| Lưu trữ tệp | Firebase Storage |
| Thông báo | Firebase Cloud Messaging, Cloud Functions, Flutter Local Notifications |
| Gọi thoại/video | Agora RTC |
| Vị trí và bản đồ | Geolocator, OpenStreetMap/Nominatim, URL Launcher |
| Thanh toán thử nghiệm | MoMo Sandbox |
| AI và dữ liệu ngoài | OpenRouter, OpenWeatherMap |
| Biểu đồ và thống kê | fl_chart |

## Luồng nghiệp vụ chính

```text
Nhà tuyển dụng tạo tin
        |
Ứng viên tìm kiếm và ứng tuyển
        |
Nhà tuyển dụng duyệt ứng viên
        |
Hệ thống tạo nhóm chat công việc
        |
Phân công lịch làm và chấm công
        |
Xác nhận kết quả, đánh giá và giải ngân
        |
Quản trị viên xử lý khiếu nại khi phát sinh
```

## Cấu trúc dự án

```text
ViecNow/
├── android/                 # Cấu hình và mã nguồn Android
├── ios/                     # Cấu hình và mã nguồn iOS
├── web/                     # Cấu hình Flutter Web
├── assets/                  # Hình ảnh và tài nguyên ứng dụng
├── docs/                    # Tài liệu kỹ thuật bổ sung
├── functions/               # Firebase Cloud Functions gửi push notification
├── lib/
│   ├── app/                 # Cấu hình ứng dụng
│   ├── bindings/            # GetX bindings
│   ├── common/              # Style, state và widget dùng chung
│   ├── config/              # Cấu hình dịch vụ
│   ├── controller/          # GetX controllers
│   ├── data/
│   │   ├── models/          # Mô hình dữ liệu
│   │   └── services/        # Firestore, API và nghiệp vụ
│   ├── routes/              # Khai báo route
│   ├── screens/             # Giao diện theo từng nhóm chức năng
│   ├── utils/               # Tiện ích dùng chung
│   └── widgets/             # Widget tái sử dụng
├── test/                    # Kiểm thử Flutter
├── database_schema.md       # Mô tả cấu trúc dữ liệu
├── feature_map.md           # Bản đồ và trạng thái tính năng
├── project_overview.md      # Tổng quan nghiệp vụ
└── pubspec.yaml             # Dependencies và tài nguyên Flutter
```

## Yêu cầu môi trường

- Flutter SDK tương thích với Dart SDK `^3.11.0`.
- Android Studio hoặc Visual Studio Code có Flutter extension.
- Android SDK và thiết bị thật hoặc emulator.
- Node.js 20 và Firebase CLI nếu cần chạy hoặc triển khai Cloud Functions.
- Một dự án Firebase đã bật Authentication, Firestore, Storage và Messaging.

Kiểm tra môi trường Flutter:

```bash
flutter doctor
```

## Cài đặt và chạy dự án

1. Clone repository và chuyển vào thư mục dự án:

```bash
git clone <repository-url>
cd ViecNow
```

2. Cài đặt dependencies:

```bash
flutter pub get
```

3. Cấu hình Firebase cho dự án:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Lệnh trên cần tạo hoặc cập nhật các tệp cấu hình như
`lib/firebase_options.dart` và `android/app/google-services.json`.

4. Chạy ứng dụng:

```bash
flutter run
```

## Cấu hình dịch vụ ngoài

Một số tính năng chỉ hoạt động đầy đủ sau khi cung cấp thông tin cấu hình tương
ứng:

| Dịch vụ | Vị trí cấu hình hiện tại | Mục đích |
| --- | --- | --- |
| OpenRouter | `lib/data/services/gemini_service.dart` | Chatbot AI |
| OpenWeatherMap | `lib/data/services/weather_service.dart` | Thông tin thời tiết |
| Agora | `lib/screens/chat/call_screen.dart` | Gọi thoại/video |
| MoMo Sandbox | `lib/config/momo_config.dart` | Nạp, hoàn và thanh toán thử nghiệm |
| Firebase | `lib/firebase_options.dart`, cấu hình từng nền tảng | Auth, Firestore, Storage, FCM |

Tệp `api_keys.example.json` mô tả các khóa API mẫu nhưng hiện chưa được ứng dụng
nạp tự động. Khi phát triển tiếp, nên chuyển khóa và thông tin bí mật ra khỏi mã
nguồn, sử dụng biến môi trường hoặc backend bảo mật.

## Firebase Cloud Functions

Cloud Functions trong thư mục `functions/` được sử dụng để gửi push notification
khi Firestore phát sinh thông báo mới.

```bash
cd functions
npm install
cd ..
firebase login
firebase use <firebase-project-id>
firebase deploy --only functions
```

Chi tiết triển khai và kiểm tra push notification được mô tả tại
[`docs/PUSH_NOTIFICATIONS.md`](docs/PUSH_NOTIFICATIONS.md).

## Kiểm tra chất lượng

Phân tích mã nguồn:

```bash
flutter analyze
```

Chạy kiểm thử:

```bash
flutter test
```

Định dạng mã nguồn:

```bash
dart format lib test
```

## Trạng thái hiện tại

Phần lớn luồng nghiệp vụ cốt lõi dành cho ứng viên và nhà tuyển dụng đã được
triển khai. Một số chức năng vẫn đang trong quá trình hoàn thiện:

- Quy trình nộp CV riêng cho công việc toàn thời gian.
- Màn hình quản lý toàn bộ đơn ứng tuyển dành cho ứng viên.
- Nạp, rút tiền và lịch sử giao dịch ở mức sản phẩm thực tế.
- Quản lý người dùng và báo cáo tổng hợp dành cho quản trị viên.
- Hoàn thiện đánh giá hai chiều và xử lý dữ liệu nhóm chat cũ bị trùng.
- Mở rộng kiểm thử tự động, Firebase Security Rules và bảo vệ khóa API.

Trạng thái chi tiết của từng tính năng được theo dõi trong
[`feature_map.md`](feature_map.md).

## Tài liệu liên quan

- [`project_overview.md`](project_overview.md): tổng quan vai trò và nghiệp vụ.
- [`feature_map.md`](feature_map.md): danh sách và trạng thái các tính năng.
- [`database_schema.md`](database_schema.md): cấu trúc dữ liệu Firestore và SQLite.
- [`backend_data_rules.md`](backend_data_rules.md): quy tắc làm việc với dữ liệu.
- [`frontend_ui_rules.md`](frontend_ui_rules.md): quy tắc giao diện.

## Bảo mật

- Không commit khóa API, secret key hoặc thông tin tài khoản thật.
- Không sử dụng thông tin MoMo Sandbox hiện tại cho môi trường production.
- Cần triển khai Firebase Security Rules theo vai trò người dùng trước khi phát
  hành ứng dụng.
- Các nghiệp vụ thanh toán quan trọng nên được xác thực và xử lý ở backend.
- Agora production cần sử dụng token server thay vì tham gia phòng bằng token rỗng.

## Định hướng phát triển

- Gợi ý việc làm thông minh dựa trên hồ sơ và hành vi người dùng.
- Phân tích CV và đánh giá mức độ phù hợp với công việc bằng AI.
- Hoàn thiện Web Admin độc lập để quản lý toàn bộ nền tảng.
- Hoàn thiện ví, thanh toán, đối soát và xử lý tranh chấp.
- Tăng cường bảo mật, kiểm thử tự động và khả năng vận hành ở quy mô lớn.
- Nghiên cứu tích hợp hợp đồng lao động điện tử.

## Giấy phép

Dự án hiện được phát triển phục vụ mục đích học tập và nghiên cứu. Vui lòng liên
hệ nhóm phát triển trước khi sử dụng mã nguồn cho mục đích thương mại.
