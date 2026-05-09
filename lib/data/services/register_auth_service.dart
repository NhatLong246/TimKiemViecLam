import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'sqlite_cache_service.dart';

class RegisterAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerUser({
    required UserModel userModel,
    required String password,
  }) async {
    // 1. Tạo Firebase Auth user
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: userModel.email,
      password: password,
    );
    final User? firebaseUser = credential.user;
    if (firebaseUser == null) throw Exception('Không thể tạo tài khoản');

    final String uid = firebaseUser.uid;

    // 2. Duplicate check: kiểm tra uid đã tồn tại trong Firestore chưa
    final existingDoc = await _firestore.collection('users').doc(uid).get();
    if (existingDoc.exists) {
      throw Exception('Tài khoản đã tồn tại');
    }

    // 3. Gửi email xác thực
    await firebaseUser.sendEmailVerification();

    // 4. Lưu vào Firestore với đầy đủ fields theo schema
    final UserModel savedModel = userModel.copyWith(id: uid);
    await _firestore.collection('users').doc(uid).set(savedModel.toMap());

    // 5. Cache vào SQLite (cached_profile)
    await SqliteCacheService.upsertProfile(
      uid: uid,
      role: savedModel.role,
      firstName: savedModel.firstName,
      lastName: savedModel.lastName,
      email: savedModel.email,
      phone: savedModel.phone,
    );

    return firebaseUser;
  }
}
