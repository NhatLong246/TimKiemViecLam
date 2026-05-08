import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Không tìm thấy người dùng');
      }
      if (!firebaseUser.emailVerified) {
        throw Exception('Email not verified');
      }
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Không tìm thấy dữ liệu người dùng');
      }
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      UserModel userModel = UserModel.fromMap(data);
      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Email không tồn tại');
      }
      if (e.code == 'wrong-password') {
        throw Exception('Mật khẩu không đúng');
      }
      if (e.code == 'invalid-email') {
        throw Exception('Email không hợp lệ');
      }
      if (e.code == 'user-disabled') {
        throw Exception('Tài khoản đã bị vô hiệu hóa');
      }
      throw Exception('Đăng nhập thất bại');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
