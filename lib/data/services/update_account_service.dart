import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'file_upload_service.dart';
import '../models/job_criteria_model.dart';
import '../models/user_model.dart';
import '../models/work_experience_model.dart';

class UpdateAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateName({
    required String userId,
    required String firstName,
    required String lastName,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'firstName': firstName,
      'lastName': lastName,
    });
  }

  Future<void> updateUsername(String username) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'username': username,
    });
  }

  Future<void> updatePhone(String phone) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({'phone': phone});
  }

  Future<void> updateGender(String gender) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({'gender': gender});
  }

  Future<void> updateDateOfBirth(DateTime date) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'dateOfBirth': Timestamp.fromDate(date),
    });
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser!;
    final uid = user.uid;
    if (user.email == newEmail) {
      throw Exception("Email mới trùng với email hiện tại");
    }

    /// CHECK TRÙNG FIRESTORE
    final existingEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: newEmail)
        .get();
    if (existingEmail.docs.isNotEmpty) {
      throw Exception("Email đã tồn tại trong hệ thống");
    }
    try {
      /// Gửi email xác minh trước khi đổi
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception("Vui lòng đăng nhập lại để đổi email");
      } else if (e.code == 'email-already-in-use') {
        throw Exception("Email đã được sử dụng");
      } else if (e.code == 'invalid-email') {
        throw Exception("Email không hợp lệ");
      } else {
        throw Exception(e.message);
      }
    }
  }

  Future<void> syncEmailAfterVerification() async {
    final user = _auth.currentUser!;
    final uid = user.uid;
    await _firestore.collection('users').doc(uid).update({'email': user.email});
  }

  /// Đổi mật khẩu (tài khoản đăng nhập email/mật khẩu).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final hasPassword =
        user.providerData.any((p) => p.providerId == 'password');
    if (!hasPassword) {
      throw Exception(
        'Tài khoản đăng nhập bằng Google/Facebook không đổi mật khẩu tại đây.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('Tài khoản không có email để xác thực');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Mật khẩu hiện tại không đúng');
        case 'weak-password':
          throw Exception('Mật khẩu mới quá yếu (tối thiểu 6 ký tự)');
        case 'requires-recent-login':
          throw Exception('Vui lòng đăng nhập lại rồi thử đổi mật khẩu');
        default:
          throw Exception(e.message ?? 'Không thể đổi mật khẩu');
      }
    }
  }

  Stream<DocumentSnapshot> getUserData() {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Tải lại hồ sơ từ server (dùng cho pull-to-refresh).
  Future<UserModel?> refreshCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get(
      const GetOptions(source: Source.server),
    );
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> addWorkExperience(WorkExperienceModel experience) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'workExperiences': FieldValue.arrayUnion([experience.toMap()]),
      'hasWorkExperience': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWorkExperience(WorkExperienceModel experience) async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final raw = doc.data()?['workExperiences'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final index = list.indexWhere(
      (e) => e['id']?.toString() == experience.id,
    );
    if (index >= 0) {
      list[index] = experience.toMap();
    }

    await _firestore.collection('users').doc(uid).update({
      'workExperiences': list,
      'hasWorkExperience': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declareNoWorkExperience() async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'hasWorkExperience': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadAvatar(File file) async {
    final uid = _auth.currentUser!.uid;
    final url = await FileUploadService.uploadAnonymous(file);
    await _firestore.collection('users').doc(uid).update({
      'avatarUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return url;
  }

  Future<void> saveJobCriteria(JobCriteriaModel criteria) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'jobCriteria': criteria.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearJobCriteria() async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'jobCriteria': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateJobStatus({
    required String currentWorkStatus,
    required String jobSearchStatus,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'currentWorkStatus': currentWorkStatus,
      'jobSearchStatus': jobSearchStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bật/tắt cho phép NTD tìm thấy hồ sơ ứng viên.
  Future<void> setAllowEmployerDiscovery(bool value) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).set({
      'allowEmployerDiscovery': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeWorkExperience(String experienceId) async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final raw = doc.data()?['workExperiences'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['id']?.toString() != experienceId)
            .toList()
        : <Map<String, dynamic>>[];

    final updates = <String, dynamic>{
      'workExperiences': list,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (list.isEmpty) {
      updates['hasWorkExperience'] = FieldValue.delete();
    }
    await _firestore.collection('users').doc(uid).update(updates);
  }
}
