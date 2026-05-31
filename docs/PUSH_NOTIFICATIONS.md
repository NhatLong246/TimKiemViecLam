# Push Notification — Triển khai

App đã tích hợp **FCM + flutter_local_notifications**. Push ra ngoài màn hình khóa cần **deploy Cloud Functions** một lần.

## Luồng hoạt động

1. App ghi thông báo vào Firestore (`notifications` hoặc `users/{uid}/notifications`)
2. Cloud Function tự gửi FCM tới thiết bị (đọc `fcmTokens` trên `users/{uid}`)
3. App foreground → hiện local notification; background/tắt → hệ điều hành hiện banner
4. Chạm notification → mở chat / điểm danh / màn thông báo tương ứng

## Bước deploy Cloud Functions (bắt buộc)

```bash
cd functions
npm install
cd ..
firebase login
firebase use timkiemvieclam-711c6
firebase deploy --only functions
```

Sau deploy, kiểm tra Firebase Console → Functions → 2 function:
- `onLegacyNotificationCreated`
- `onUserInboxNotificationCreated`

## Android

- Quyền `POST_NOTIFICATIONS` (Android 13+): app sẽ hỏi khi khởi động
- Channel: `viecnow_default`

## iOS (nếu build iOS)

1. Bật **Push Notifications** capability trong Xcode
2. Upload APNs key lên Firebase Console → Project Settings → Cloud Messaging

## Kiểm tra

1. Đăng nhập 2 tài khoản trên 2 máy / emulator
2. Gửi tin nhắn hoặc duyệt ứng viên
3. Máy nhận phải thấy banner ngoài app (Functions đã deploy)

## Ghi chú

- NTD nhận push qua inbox (`sendToUser`), không trùng legacy (`suppressPush`)
- Nhóm đã mute → không push tin nhắn
- Tắt loại thông báo trong Cài đặt → Cloud Function tôn trọng `notificationPrefs`
