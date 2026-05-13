import 'package:cloud_firestore/cloud_firestore.dart';

class EmployerReviewItem {
  final String reviewId;
  final String jobId;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final double rating;
  final String? comment;
  final DateTime? createdAt;

  const EmployerReviewItem({
    required this.reviewId,
    required this.jobId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerAvatarUrl,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory EmployerReviewItem.fromFirestore(
    Map<String, dynamic> map, {
    String reviewerName = '',
    String? reviewerAvatarUrl,
  }) {
    return EmployerReviewItem(
      reviewId: (map['reviewId'] ?? '').toString(),
      jobId: (map['jobId'] ?? '').toString(),
      reviewerId: (map['reviewerId'] ?? '').toString(),
      reviewerName: reviewerName,
      reviewerAvatarUrl: reviewerAvatarUrl,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment']?.toString(),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  factory EmployerReviewItem.fromSQLite(Map<String, dynamic> m) {
    return EmployerReviewItem(
      reviewId: (m['reviewId'] as String?) ?? '',
      jobId: (m['jobId'] as String?) ?? '',
      reviewerId: (m['reviewerId'] as String?) ?? '',
      reviewerName: (m['reviewerName'] as String?) ?? 'Ẩn danh',
      reviewerAvatarUrl: m['reviewerAvatar'] as String?,
      rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
      comment: m['comment'] as String?,
      createdAt: m['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toSQLiteMap(String revieweeId) {
    return {
      'reviewId': reviewId,
      'revieweeId': revieweeId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerAvatar': reviewerAvatarUrl,
      'jobId': jobId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class EmployerReviewSummary {
  final double averageRating;
  final int totalCount;
  final Map<int, int> distribution; // star (1-5) → count

  const EmployerReviewSummary({
    required this.averageRating,
    required this.totalCount,
    required this.distribution,
  });

  factory EmployerReviewSummary.fromList(List<EmployerReviewItem> reviews) {
    if (reviews.isEmpty) {
      return const EmployerReviewSummary(
        averageRating: 0,
        totalCount: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }
    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double total = 0;
    for (final r in reviews) {
      total += r.rating;
      final star = r.rating.round().clamp(1, 5);
      dist[star] = (dist[star] ?? 0) + 1;
    }
    return EmployerReviewSummary(
      averageRating: total / reviews.length,
      totalCount: reviews.length,
      distribution: dist,
    );
  }
}
