import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Danh sách ứng viên cho phép NTD tìm thấy hồ sơ (`allowEmployerDiscovery: true`).
class CandidateDiscoveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<UserModel>> fetchDiscoverableCandidates({
    String? keyword,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('users')
        .where('allowEmployerDiscovery', isEqualTo: true)
        .limit(limit)
        .get();

    var candidates = snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((u) => u.role == 'candidate' && u.isActive)
        .toList();

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      candidates = candidates.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }).toList();
    }

    return candidates;
  }
}
