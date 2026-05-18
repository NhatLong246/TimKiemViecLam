import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';
import 'sqlite_cache_service.dart';
import 'login_history_service.dart';

class LoginAuthService {
  /// Web client ID (client_type 3) — bắt buộc để Firebase nhận idToken trên Android.
  static const String googleWebClientId =
      '630246371829-h6gobgkjqc6re38hnas9tpat38b1363p.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: googleWebClientId,
  );
  final LoginHistoryService _history = LoginHistoryService();

  // ─── Email / Password ──────────────────────────────────────

  Future<UserModel> loginWithEmailPassword(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('Không tìm thấy người dùng');
      if (!firebaseUser.emailVerified) throw Exception('Email not verified');
      final user = await _fetchAndCacheUser(firebaseUser.uid);
      _history.recordLogin(method: 'email').ignore();
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e.code));
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

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Không thể đăng nhập với Google');
      }

      await firebaseUser.reload();
      final activeUser = _auth.currentUser ?? firebaseUser;
      await _ensureFirestoreUser(activeUser);

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

      final OAuthCredential credential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('Không thể đăng nhập với Facebook');

      // Nếu là user mới → tạo document
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        final userData = await FacebookAuth.instance.getUserData();
        final newUser = UserModel(
          id: firebaseUser.uid,
          role: 'candidate',
          firstName: (userData['name'] as String? ?? '').split(' ').last,
          lastName: (userData['name'] as String? ?? '').split(' ').first,
          username: firebaseUser.email?.split('@').first ?? firebaseUser.uid,
          email: firebaseUser.email ?? '',
          phone: '',
          isVerified: true,
          isActive: true,
          avatarUrl: firebaseUser.photoURL,
        );
        await docRef.set(newUser.toMap());
      }

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
          throw Exception('Email này đã được đăng ký bằng phương thức khác. Vui lòng đăng nhập bằng Google hoặc Email/Mật khẩu.');
        }
      }
      throw Exception('[${e.code}] ${_mapAuthError(e.code)}');
    }
  }

  /// Khôi phục [UserModel] từ Firebase Auth + Firestore (sau khi mở lại app).
  Future<UserModel?> restoreSessionFromFirebase() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    try {
      await _ensureFirestoreUser(firebaseUser);
      return await _fetchAndCacheUser(firebaseUser.uid);
    } catch (_) {
      return _minimalUserFromFirebase(firebaseUser);
    }
  }

  Future<void> _ensureFirestoreUser(User firebaseUser) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      final data = docSnap.data();
      if (data != null && (data['uid'] ?? '').toString().isEmpty) {
        await docRef.set({'uid': firebaseUser.uid}, SetOptions(merge: true));
      }
      return;
    }

    final displayName = firebaseUser.displayName ?? '';
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    final newUser = UserModel(
      id: firebaseUser.uid,
      role: 'candidate',
      firstName: parts.isNotEmpty ? parts.last : '',
      lastName: parts.length > 1
          ? parts.sublist(0, parts.length - 1).join(' ')
          : '',
      username: firebaseUser.email?.split('@').first ?? firebaseUser.uid,
      email: firebaseUser.email ?? '',
      phone: '',
      isVerified: true,
      isActive: true,
      avatarUrl: firebaseUser.photoURL,
    );
    await docRef.set(newUser.toMap(), SetOptions(merge: true));
  }

  UserModel _minimalUserFromFirebase(User firebaseUser) {
    final displayName = firebaseUser.displayName ?? '';
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    return UserModel(
      id: firebaseUser.uid,
      role: 'candidate',
      firstName: parts.isNotEmpty ? parts.last : 'Người',
      lastName: parts.length > 1
          ? parts.sublist(0, parts.length - 1).join(' ')
          : 'dùng',
      username: firebaseUser.email?.split('@').first ?? firebaseUser.uid,
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber ?? '',
      isVerified: true,
      isActive: true,
      avatarUrl: firebaseUser.photoURL,
    );
  }

  // ─── Logout ────────────────────────────────────────────────

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    await _auth.signOut();
    await _googleSignIn.signOut();
    if (uid != null) await SqliteCacheService.clearProfile(uid);
  }

  // ─── Helpers ───────────────────────────────────────────────

  /// Fetch Firestore doc, cache vào SQLite, trả về UserModel
  Future<UserModel> _fetchAndCacheUser(String uid) async {
    final DocumentSnapshot doc =
        await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('Không tìm thấy dữ liệu người dùng');

    final data = doc.data() as Map<String, dynamic>;
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
      case 'user-not-found': return 'Email không tồn tại';
      case 'wrong-password': return 'Mật khẩu không đúng';
      case 'invalid-email': return 'Email không hợp lệ';
      case 'user-disabled': return 'Tài khoản đã bị vô hiệu hóa';
      case 'invalid-credential': return 'Thông tin đăng nhập không đúng';
      case 'too-many-requests': return 'Quá nhiều lần thử, vui lòng thử lại sau';
      case 'account-exists-with-different-credential': return 'Email này đã được đăng ký bằng phương thức khác (Google hoặc Email). Vui lòng đăng nhập bằng phương thức đó.';
      default: return 'Đăng nhập thất bại';
    }
  }
}
