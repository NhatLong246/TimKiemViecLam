import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/employer_review_model.dart';
import 'sqlite_cache_service.dart';

class EmployerReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Lấy danh sách đánh giá
  /// Ưu tiên Firestore, fallback SQLite khi offline
  Future<List<EmployerReviewItem>> fetchReviews({String? targetUid}) async {
    final uidToFetch = targetUid ?? _uid;
    try {
      // Query reviews collection: revieweeId == targetUid
      final snap = await _firestore
          .collection('reviews')
          .where('revieweeId', isEqualTo: uidToFetch)
          .get();

      if (snap.docs.isEmpty) return [];

      // Thu thập tất cả reviewerIds để batch fetch user info
      final reviewerIds =
          snap.docs.map((d) => d.data()['reviewerId'] as String? ?? '').toSet();

      // Batch fetch reviewer profiles (từng document)
      final reviewerMap = await _fetchReviewerProfiles(reviewerIds);

      // Map sang EmployerReviewItem
      final items = snap.docs.map((doc) {
        final data = doc.data();
        final rid = (data['reviewerId'] as String?) ?? '';
        final reviewer = reviewerMap[rid];
        return EmployerReviewItem.fromFirestore(
          {...data, 'reviewId': doc.id},
          reviewerName: reviewer?['name'] ?? 'Người dùng',
          reviewerAvatarUrl: reviewer?['avatarUrl'],
        );
      }).toList();

      // Sort client-side to avoid Firestore composite index requirement
      items.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(0);
        final dateB = b.createdAt ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      // Cache xuống SQLite
      await _cacheReviews(items, uidToFetch);
      return items;
    } catch (e) {
      // Fallback: đọc từ SQLite
      final cached = await SqliteCacheService.getCachedEmployerReviews(uidToFetch);
      if (cached.isNotEmpty) {
        return cached.map(EmployerReviewItem.fromSQLite).toList();
      }
      rethrow;
    }
  }

  /// Batch fetch thông tin reviewer (tên + avatar)
  Future<Map<String, Map<String, String?>>> _fetchReviewerProfiles(
      Set<String> uids) async {
    final result = <String, Map<String, String?>>{};
    if (uids.isEmpty) return result;

    // Firestore 'in' query giới hạn 30 phần tử mỗi lần
    final uidList = uids.toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < uidList.length; i += 30) {
      chunks.add(uidList.sublist(
          i, i + 30 > uidList.length ? uidList.length : i + 30));
    }

    for (final chunk in chunks) {
      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          final firstName = (d['firstName'] as String?) ?? '';
          final lastName = (d['lastName'] as String?) ?? '';
          result[doc.id] = {
            'name': '$firstName $lastName'.trim().isEmpty
                ? 'Người dùng'
                : '$firstName $lastName'.trim(),
            'avatarUrl': d['avatarUrl'] as String?,
          };
        }
      } catch (_) {
        // Bỏ qua lỗi fetch reviewer — dùng tên mặc định
      }
    }
    return result;
  }

  /// Cache danh sách review vào SQLite
  Future<void> _cacheReviews(List<EmployerReviewItem> items, String uidToFetch) async {
    try {
      // Xóa cache cũ trước khi ghi mới
      await SqliteCacheService.clearEmployerReviews(uidToFetch);
      for (final item in items) {
        await SqliteCacheService.upsertEmployerReview(item.toSQLiteMap(uidToFetch));
      }
    } catch (_) {
      // Cache lỗi không critical
    }
  }
}
