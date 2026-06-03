import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';
import 'account_uniqueness_service.dart';
import 'sqlite_cache_service.dart';
import 'login_history_service.dart';

class LoginAuthService {
  /// Web client ID (client_type 3) — bắt buộc để Firebase nhận idToken trên Android.
  static const String googleWebClientId =
      '630246371829-h6gobgkjqc6re38hnas9tpat38b1363p.apps.googleusercontent.com';

  static const Duration _firestoreTimeout = Duration(seconds: 8);
  static const Duration _authTimeout = Duration(seconds: 20);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: googleWebClientId,
  );
  final LoginHistoryService _history = LoginHistoryService();
  final AccountUniquenessService _uniqueness = AccountUniquenessService();

  // ─── Email / Password ──────────────────────────────────────

  Future<UserModel> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_authTimeout);
      final User? firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('Không tìm thấy người dùng');
      await firebaseUser.reload();
      final activeUser = _auth.currentUser ?? firebaseUser;
      if (!activeUser.emailVerified) {
        throw Exception('Email not verified');
      }
      await _syncFirestoreEmailVerified(activeUser);
      final user = await _loadUserProfileAfterSignIn(activeUser);
      _history.recordLogin(method: 'email').ignore();
      return user;
    } on TimeoutException {
      throw Exception(
        'Đăng nhập quá lâu. Kiểm tra mạng trên emulator (Wi‑Fi) và thử lại.',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  /// Sau khi Auth thành công: lấy profile Firestore, fallback cache / tối thiểu.
  Future<UserModel> _loadUserProfileAfterSignIn(User firebaseUser) async {
    try {
      return await _fetchAndCacheUser(firebaseUser.uid);
    } catch (_) {
      final cached = await SqliteCacheService.getCachedProfile(
        firebaseUser.uid,
      );
      if (cached != null) {
        return UserModel(
          id: firebaseUser.uid,
          role: cached['role'] as String? ?? 'candidate',
          firstName: cached['firstName'] as String? ?? '',
          lastName: cached['lastName'] as String? ?? '',
          username: firebaseUser.email?.split('@').first ?? firebaseUser.uid,
          email: cached['email'] as String? ?? firebaseUser.email ?? '',
          phone: cached['phone'] as String? ?? '',
          isVerified: true,
          isActive: true,
          avatarUrl: cached['avatarUrl'] as String? ?? firebaseUser.photoURL,
        );
      }
      throw Exception(
        'Tài khoản chưa có hồ sơ người dùng. Vui lòng đăng ký trước khi đăng nhập.',
      );
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────
  // Yêu cầu: thêm SHA-1 fingerprint vào Firebase Console

  Future<UserModel> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Đăng nhập Google bị hủy');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception(
          'Không lấy được token Google. Kiểm tra SHA-1 debug trong Firebase '
          'và bật đăng nhập Google trong Authentication.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể đăng nhập với Google');
      }

      await firebaseUser.reload();
      final activeUser = _auth.currentUser ?? firebaseUser;
      await _requireRegisteredSocialProfile(
        activeUser,
        providerId: GoogleAuthProvider.PROVIDER_ID,
        isNewAuthUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
      await _markFirestoreVerified(activeUser.uid);

      final user = await _fetchAndCacheUser(activeUser.uid);
      _history.recordLogin(method: 'google').ignore();
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    } catch (e) {
      final recovered = await restoreSessionFromFirebase();
      if (recovered != null) return recovered;
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  // ─── Facebook Sign-In ──────────────────────────────────────
  // Yêu cầu native config: App ID trong AndroidManifest.xml + iOS Info.plist

  Future<UserModel> loginWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      if (result.status != LoginStatus.success) {
        throw Exception('Đăng nhập Facebook bị hủy hoặc thất bại');
      }

      final OAuthCredential credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể đăng nhập với Facebook');
      }

      await _requireRegisteredSocialProfile(
        firebaseUser,
        providerId: FacebookAuthProvider.PROVIDER_ID,
        isNewAuthUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
      await _markFirestoreVerified(firebaseUser.uid);

      final fbUser = await _fetchAndCacheUser(firebaseUser.uid);
      _history.recordLogin(method: 'facebook').ignore();
      return fbUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // Email đã tồn tại → thử link qua Google
        try {
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) throw Exception('Đăng nhập Google bị hủy');
          final googleAuth = await googleUser.authentication;
          final googleCredential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final userCred = await _auth.signInWithCredential(googleCredential);
          if (e.credential != null) {
            await userCred.user!.linkWithCredential(e.credential!);
          }
          return await _fetchAndCacheUser(userCred.user!.uid);
        } catch (_) {
          throw Exception(
            'Email này đã được đăng ký bằng phương thức khác. Vui lòng đăng nhập bằng Google hoặc Email/Mật khẩu.',
          );
        }
      }
      throw Exception('[${e.code}] ${_mapAuthError(e.code)}');
    }
  }

  Future<UserModel> registerWithGoogle({
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Đăng ký Google bị hủy');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Không lấy được token Google. Vui lòng thử lại.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể đăng ký với Google');
      }

      final user = await _createSocialProfile(
        firebaseUser,
        providerId: GoogleAuthProvider.PROVIDER_ID,
        isNewAuthUser: userCredential.additionalUserInfo?.isNewUser ?? false,
        role: role,
        firstName: firstName,
        lastName: lastName,
        username: username,
        phone: phone,
        companyName: companyName,
        companyAddress: companyAddress,
      );
      _history.recordLogin(method: 'google').ignore();
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
    }
  }

  Future<UserModel> registerWithFacebook({
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
  }) async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      if (result.status != LoginStatus.success) {
        throw Exception('Đăng ký Facebook bị hủy hoặc thất bại');
      }

      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể đăng ký với Facebook');
      }

      final userData = await FacebookAuth.instance.getUserData();
      final user = await _createSocialProfile(
        firebaseUser,
        providerId: FacebookAuthProvider.PROVIDER_ID,
        isNewAuthUser: userCredential.additionalUserInfo?.isNewUser ?? false,
        role: role,
        firstName: firstName,
        lastName: lastName,
        username: username,
        phone: phone,
        companyName: companyName,
        companyAddress: companyAddress,
        providerName: userData['name']?.toString(),
        providerEmail: userData['email']?.toString(),
      );
      _history.recordLogin(method: 'facebook').ignore();
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'Email này đã được đăng ký bằng phương thức khác. Vui lòng đăng nhập bằng phương thức đã dùng trước đó.',
        );
      }
      throw Exception(_mapAuthError(e.code));
    }
  }

  /// Khôi phục [UserModel] từ Firebase Auth + Firestore (sau khi mở lại app).
  Future<UserModel?> restoreSessionFromFirebase() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    try {
      await _syncFirestoreEmailVerified(firebaseUser);
      return await _fetchAndCacheUser(firebaseUser.uid);
    } catch (_) {
      final cached = await SqliteCacheService.getCachedProfile(
        firebaseUser.uid,
      );
      if (cached != null) {
        return UserModel(
          id: firebaseUser.uid,
          role: cached['role'] as String? ?? 'candidate',
          firstName: cached['firstName'] as String? ?? '',
          lastName: cached['lastName'] as String? ?? '',
          username: firebaseUser.email?.split('@').first ?? firebaseUser.uid,
          email: cached['email'] as String? ?? firebaseUser.email ?? '',
          phone: cached['phone'] as String? ?? '',
          isVerified: true,
          isActive: true,
          avatarUrl: cached['avatarUrl'] as String? ?? firebaseUser.photoURL,
        );
      }
      await _auth.signOut();
      return null;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .get()
        .timeout(_firestoreTimeout);
  }

  Future<void> _requireRegisteredSocialProfile(
    User firebaseUser, {
    required String providerId,
    required bool isNewAuthUser,
  }) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final docSnap = await docRef.get().timeout(_firestoreTimeout);
    if (docSnap.exists) {
      final data = docSnap.data();
      if (data != null && (data['uid'] ?? '').toString().isEmpty) {
        await docRef.set({'uid': firebaseUser.uid}, SetOptions(merge: true));
      }
      return;
    }

    if (isNewAuthUser) {
      try {
        await firebaseUser.delete();
      } catch (_) {}
    }
    await _signOutSocialProvider(providerId);
    throw Exception(
      'Tài khoản chưa được đăng ký. Vui lòng vào Đăng ký, chọn đúng vai trò rồi đăng ký bằng Google/Facebook.',
    );
  }

  Future<UserModel> _createSocialProfile(
    User firebaseUser, {
    required String providerId,
    required bool isNewAuthUser,
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
    String? providerName,
    String? providerEmail,
  }) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final docSnap = await docRef.get().timeout(_firestoreTimeout);
    if (docSnap.exists) {
      await _signOutSocialProvider(providerId);
      throw Exception(
        'Tài khoản này đã được đăng ký. Vui lòng quay lại màn đăng nhập.',
      );
    }

    final profile = _socialUserFromFirebase(
      firebaseUser,
      role: role,
      firstName: firstName,
      lastName: lastName,
      username: username,
      phone: phone,
      companyName: companyName,
      companyAddress: companyAddress,
      providerName: providerName,
      providerEmail: providerEmail,
    );
    try {
      await _uniqueness.ensureEmailAvailable(
        profile.email,
        excludeUid: firebaseUser.uid,
      );
      await _uniqueness.ensurePhoneAvailable(
        profile.phone,
        excludeUid: firebaseUser.uid,
      );
      await docRef.set(profile.toMap()).timeout(_firestoreTimeout);
    } catch (e) {
      if (isNewAuthUser) {
        try {
          await firebaseUser.delete();
        } catch (_) {}
      }
      await _signOutSocialProvider(providerId);
      rethrow;
    }
    return _fetchAndCacheUser(firebaseUser.uid);
  }

  UserModel _socialUserFromFirebase(
    User firebaseUser, {
    required String role,
    String? firstName,
    String? lastName,
    String? username,
    String? phone,
    String? companyName,
    String? companyAddress,
    String? providerName,
    String? providerEmail,
  }) {
    final displayName =
        _nonEmpty(providerName) ?? firebaseUser.displayName ?? '';
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final email = _uniqueness.normalizeEmail(
      _nonEmpty(firebaseUser.email) ?? _nonEmpty(providerEmail) ?? '',
    );
    final resolvedFirstName =
        _nonEmpty(firstName) ?? (parts.isNotEmpty ? parts.last : '');
    final resolvedLastName =
        _nonEmpty(lastName) ??
        (parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : '');
    final resolvedUsername =
        _nonEmpty(username) ??
        (email.isNotEmpty ? email.split('@').first : firebaseUser.uid);

    return UserModel(
      id: firebaseUser.uid,
      role: role,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      username: resolvedUsername,
      email: email,
      phone: _uniqueness.normalizePhone(
        _nonEmpty(phone) ?? firebaseUser.phoneNumber ?? '',
      ),
      isVerified: true,
      isActive: true,
      avatarUrl: firebaseUser.photoURL,
      companyName: role == 'employer' ? _nonEmpty(companyName) : null,
      companyAddress: role == 'employer' ? _nonEmpty(companyAddress) : null,
    );
  }

  // ─── Logout ────────────────────────────────────────────────

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    await _auth.signOut();
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    if (uid != null) await SqliteCacheService.clearProfile(uid);
  }

  // ─── Helpers ───────────────────────────────────────────────

  Future<void> _signOutSocialProvider(String providerId) async {
    await _auth.signOut();
    if (providerId == GoogleAuthProvider.PROVIDER_ID) {
      await _googleSignIn.signOut();
    } else if (providerId == FacebookAuthProvider.PROVIDER_ID) {
      await FacebookAuth.instance.logOut();
    }
  }

  Future<void> _syncFirestoreEmailVerified(User firebaseUser) async {
    if (!firebaseUser.emailVerified) return;
    await _markFirestoreVerified(firebaseUser.uid);
  }

  Future<void> _markFirestoreVerified(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    final docSnap = await docRef.get().timeout(_firestoreTimeout);
    if (!docSnap.exists) return;
    if (docSnap.data()?['isVerified'] == true) return;
    await docRef
        .update({'isVerified': true, 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(_firestoreTimeout);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Fetch Firestore doc, cache vào SQLite, trả về UserModel
  Future<UserModel> _fetchAndCacheUser(String uid) async {
    final DocumentSnapshot doc = await _getUserDoc(uid);
    if (!doc.exists) throw Exception('Không tìm thấy dữ liệu người dùng');

    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    if ((data['uid'] ?? data['id'] ?? '').toString().isEmpty) {
      data['uid'] = uid;
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
      }, SetOptions(merge: true));
    }
    final user = UserModel.fromMap(data);

    // Cache vào SQLite
    await SqliteCacheService.upsertProfile(
      uid: uid,
      role: user.role,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
    );

    return user;
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email không tồn tại';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không đúng';
      case 'too-many-requests':
        return 'Quá nhiều lần thử, vui lòng thử lại sau';
      case 'account-exists-with-different-credential':
        return 'Email này đã được đăng ký bằng phương thức khác (Google hoặc Email). Vui lòng đăng nhập bằng phương thức đó.';
      default:
        return 'Đăng nhập thất bại';
    }
  }
}
