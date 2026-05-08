import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Stream<DocumentSnapshot> getUserData() {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(uid).snapshots();
  }
}
