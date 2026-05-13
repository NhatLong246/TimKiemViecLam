import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Ghi nhận một lần đăng nhập
  Future<void> recordLogin({required String method}) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('loginHistory')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
      'method': method,
      'platform': Platform.isAndroid ? 'Android' : 'iOS',
    });
  }

  /// Lấy danh sách lịch sử đăng nhập (mới nhất trước)
  Future<List<Map<String, dynamic>>> fetchHistory({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('loginHistory')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }
}
