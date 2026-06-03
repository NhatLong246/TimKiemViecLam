import 'package:cloud_firestore/cloud_firestore.dart';

class AccountUniquenessService {
  AccountUniquenessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String normalizeEmail(String email) => email.trim().toLowerCase();

  String normalizePhone(String phone) =>
      phone.trim().replaceAll(RegExp(r'\s+'), '');

  Future<void> ensureEmailAvailable(String email, {String? excludeUid}) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) return;

    final variants = <String>{email.trim(), normalized};
    for (final value in variants) {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: value)
          .limit(3)
          .get();
      if (_hasDifferentUser(snapshot.docs, excludeUid)) {
        throw Exception('Email đã tồn tại trong hệ thống');
      }
    }
  }

  Future<void> ensurePhoneAvailable(String phone, {String? excludeUid}) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return;

    final snapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: normalized)
        .limit(3)
        .get();
    if (_hasDifferentUser(snapshot.docs, excludeUid)) {
      throw Exception('Số điện thoại đã tồn tại trong hệ thống');
    }
  }

  bool _hasDifferentUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? excludeUid,
  ) {
    return docs.any((doc) {
      final data = doc.data();
      final uid = (data['uid'] ?? data['id'] ?? doc.id).toString();
      return excludeUid == null || uid != excludeUid;
    });
  }
}
