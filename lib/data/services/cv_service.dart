import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'file_upload_service.dart';

/// CV cá nhân — lưu trên `users/{uid}` (skills, kinh nghiệm, cvUrl, …).
class CvService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return _db.collection('users').doc(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser() {
    final ref = _userRef;
    if (ref == null) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return ref.snapshots();
  }

  Future<Map<String, dynamic>?> fetchUserOnce() async {
    final ref = _userRef;
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return snap.data();
  }

  /// Upload file PDF/DOC → Storage `users/{uid}/cv.{ext}` → `cvUrl`.
  Future<String> uploadCvFile(File file, {required String fileName}) async {
    final ref = _userRef;
    if (ref == null) throw Exception('Chưa đăng nhập');

    final ext = _extension(fileName);
    if (!_allowedExt(ext)) {
      throw Exception('Chỉ hỗ trợ file PDF hoặc DOC/DOCX');
    }

    final storagePath = 'users/${ref.id}/cv$ext';
    final url = await FileUploadService.uploadAnonymous(file);

    await ref.update({
      'cvUrl': url,
      'cvFileName': fileName,
      'cvUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return url;
  }

  Future<void> removeCvFile() async {
    final ref = _userRef;
    if (ref == null) throw Exception('Chưa đăng nhập');

    final snap = await ref.get();
    final data = snap.data();
    final url = data?['cvUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      // Cannot delete anonymous uploads easily, just remove reference
    }

    await ref.update({
      'cvUrl': FieldValue.delete(),
      'cvFileName': FieldValue.delete(),
      'cvUpdatedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _extension(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return '.pdf';
    return name.substring(i).toLowerCase();
  }

  static bool _allowedExt(String ext) {
    return ext == '.pdf' || ext == '.doc' || ext == '.docx';
  }
}
