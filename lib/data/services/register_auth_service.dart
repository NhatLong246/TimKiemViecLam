import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'account_uniqueness_service.dart';
import 'sqlite_cache_service.dart';

class RegisterAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountUniquenessService _uniqueness = AccountUniquenessService();

  Future<User?> registerUser({
    required UserModel userModel,
    required String password,
  }) async {
    final email = _uniqueness.normalizeEmail(userModel.email);
    final phone = _uniqueness.normalizePhone(userModel.phone);
    await _uniqueness.ensureEmailAvailable(email);
    await _uniqueness.ensurePhoneAvailable(phone);

    // 1. Tạo Firebase Auth user
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);
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
    final UserModel savedModel = userModel.copyWith(
      id: uid,
      email: email,
      phone: phone,
    );
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
