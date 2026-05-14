import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import 'sqlite_cache_service.dart';

/// Service: load & update Employer profile
/// Firebase = source of truth; SQLite = local cache (offline support)
class EmployerProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Fetch ────────────────────────────────────────────────

  /// Load profile: ưu tiên Firestore, fallback SQLite khi offline
  Future<UserModel> fetchProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(_uid).get();
      if (!doc.exists) throw Exception('Không tìm thấy hồ sơ người dùng');
      final map = doc.data()!;
      final model = UserModel.fromMap(map);
      // Cache xuống SQLite
      await _cacheToSQLite(model);
      return model;
    } catch (e) {
      // Fallback: đọc từ SQLite cache
      final cached = await SqliteCacheService.getCachedEmployerProfile(_uid);
      if (cached != null) return _fromSQLiteMap(cached);
      rethrow;
    }
  }

  // ─── Update fields ────────────────────────────────────────

  /// Cập nhật một hoặc nhiều field lên Firestore và đồng bộ cache
  Future<void> updateFields(Map<String, dynamic> fields) async {
    final payload = Map<String, dynamic>.from(fields)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(_uid).update(payload);
  }

  /// Cập nhật thông tin cá nhân
  Future<void> updatePersonalInfo({
    String? firstName,
    String? lastName,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    String? cccd,
    String? cccdImageUrl,
    String? cccdBackImageUrl,
  }) async {
    final Map<String, dynamic> data = {};
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (phone != null) data['phone'] = phone;
    if (gender != null) data['gender'] = gender;
    if (dateOfBirth != null) data['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    if (cccd != null) data['cccd'] = cccd;
    if (cccdImageUrl != null) data['cccdImageUrl'] = cccdImageUrl;
    if (cccdBackImageUrl != null) data['cccdBackImageUrl'] = cccdBackImageUrl;
    await updateFields(data);
  }

  /// Upload ảnh lên Firebase Storage, trả về download URL
  Future<String> uploadImage(File file, String storagePath) async {
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Cập nhật thông tin doanh nghiệp
  Future<void> updateCompanyInfo({
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyWebsite,
    String? companyTaxCode,
    String? companySize,
    String? businessType,
    String? companyDescription,
  }) async {
    final Map<String, dynamic> data = {};
    if (companyName != null) data['companyName'] = companyName;
    if (companyAddress != null) data['companyAddress'] = companyAddress;
    if (companyPhone != null) data['companyPhone'] = companyPhone;
    if (companyWebsite != null) data['companyWebsite'] = companyWebsite;
    if (companyTaxCode != null) data['companyTaxCode'] = companyTaxCode;
    if (companySize != null) data['companySize'] = companySize;
    if (businessType != null) data['businessType'] = businessType;
    if (companyDescription != null) data['companyDescription'] = companyDescription;
    await updateFields(data);
  }

  // ─── Helpers ──────────────────────────────────────────────

  Future<void> _cacheToSQLite(UserModel m) async {
    try {
      await SqliteCacheService.upsertEmployerProfile({
        'uid': m.id,
        'firstName': m.firstName,
        'lastName': m.lastName,
        'email': m.email,
        'phone': m.phone,
        'gender': m.gender,
        'dateOfBirth': m.dateOfBirth?.millisecondsSinceEpoch,
        'avatarUrl': m.avatarUrl,
        'cccd': m.cccd,
        'companyName': m.companyName,
        'companyAddress': m.companyAddress,
        'companyLogoUrl': m.companyLogoUrl,
        'companyPhone': m.companyPhone,
        'companyWebsite': m.companyWebsite,
        'companyTaxCode': m.companyTaxCode,
        'companySize': m.companySize,
        'businessType': m.businessType,
        'companyDescription': m.companyDescription,
        'walletBalance': m.walletBalance,
        'totalSpent': m.totalSpent,
        'isVerified': m.isVerified,
      });
    } catch (e) {
      // Cache lỗi không critical
    }
  }

  UserModel _fromSQLiteMap(Map<String, dynamic> m) {
    return UserModel(
      id: m['uid'] as String,
      role: 'employer',
      firstName: (m['firstName'] as String?) ?? '',
      lastName: (m['lastName'] as String?) ?? '',
      username: '',
      email: (m['email'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      gender: m['gender'] as String?,
      dateOfBirth: m['dateOfBirth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['dateOfBirth'] as int)
          : null,
      avatarUrl: m['avatarUrl'] as String?,
      cccd: m['cccd'] as String?,
      companyName: m['companyName'] as String?,
      companyAddress: m['companyAddress'] as String?,
      companyLogoUrl: m['companyLogoUrl'] as String?,
      companyPhone: m['companyPhone'] as String?,
      companyWebsite: m['companyWebsite'] as String?,
      companyTaxCode: m['companyTaxCode'] as String?,
      companySize: m['companySize'] as String?,
      businessType: m['businessType'] as String?,
      companyDescription: m['companyDescription'] as String?,
      walletBalance: (m['walletBalance'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0.0,
      isVerified: (m['isVerified'] as int?) == 1,
    );
  }
}
