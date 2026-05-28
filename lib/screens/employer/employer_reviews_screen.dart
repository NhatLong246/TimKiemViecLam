import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/employer_review_controller.dart';
import '../../data/models/employer_review_model.dart';

class EmployerReviewsScreen extends StatelessWidget {
  const EmployerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EmployerReviewController());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Obx(() {
        final summary = ctrl.summary.value;
        return CustomScrollView(
          slivers: [
            // ─── AppBar ───────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              leading: const BackButton(color: Colors.white),
              title: const Text(
                'Đánh giá từ ứng viên',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.employerGradient,
                  ),
                  child: Obx(() => _RatingSummaryHeader(
                        summary: ctrl.summary.value,
                        isLoading: ctrl.isLoading.value,
                      )),
                ),
                collapseMode: CollapseMode.parallax,
              ),
              backgroundColor: AppColors.employerPrimary,
            ),

            // ─── Nội dung ─────────────────────────────────
            if (ctrl.isLoading.value)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.employerPrimary),
                ),
              )
            else if (ctrl.errorMessage.value.isNotEmpty)
              SliverFillRemaining(
                child: _ErrorState(
                  message: ctrl.errorMessage.value,
                  onRetry: ctrl.refresh,
                ),
              )
            else if (ctrl.reviews.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else ...[
              // Tiêu đề danh sách
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Tất cả đánh giá (${summary.totalCount})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
              ),
              // Danh sách review
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _ReviewCard(review: ctrl.reviews[index]),
                    childCount: ctrl.reviews.length,
                  ),
                ),
              ),
            ],
          ],
        );
      }),
      // Nút làm mới
      floatingActionButton: Obx(() => ctrl.isLoading.value
          ? const SizedBox.shrink()
          : FloatingActionButton.small(
              onPressed: ctrl.refresh,
              backgroundColor: AppColors.employerPrimary,
              tooltip: 'Làm mới',
              child: const Icon(Icons.refresh, color: Colors.white),
            )),
    );
  }
}

// ─── Rating Summary Header ──────────────────────────────────────────────────

class _RatingSummaryHeader extends StatelessWidget {
  const _RatingSummaryHeader({
    required this.summary,
    required this.isLoading,
  });

  final EmployerReviewSummary summary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Điểm trung bình
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.totalCount == 0
                    ? '—'
                    : summary.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              _StarRow(
                  rating: summary.averageRating, size: 18, color: Colors.amber),
              const SizedBox(height: 4),
              Text(
                '${summary.totalCount} đánh giá',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Thanh phân phối sao
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = summary.distribution[star] ?? 0;
                final pct = summary.totalCount == 0
                    ? 0.0
                    : count / summary.totalCount;
                return _DistributionRow(
                    star: star, count: count, percent: pct);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow(
      {required this.star, required this.count, required this.percent});

  final int star;
  final int count;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text('$star', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(width: 2),
          const Icon(Icons.star, size: 10, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.white24,
                color: Colors.amber,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review Card ────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final EmployerReviewItem review;

  @override
  Widget build(BuildContext context) {
    final dateStr = review.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(review.createdAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewer header
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.employerPrimary.withOpacity(0.12),
                  backgroundImage: (review.reviewerAvatarUrl?.isNotEmpty ?? false)
                      ? NetworkImage(review.reviewerAvatarUrl!)
                      : null,
                  child: (review.reviewerAvatarUrl?.isEmpty ?? true)
                      ? Text(
                          _initials(review.reviewerName),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.employerPrimary,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Tên + ngày
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName.isEmpty
                            ? 'Người dùng'
                            : review.reviewerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF212121),
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                // Điểm số
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.employerGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          size: 13, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Sao đánh giá
            const SizedBox(height: 8),
            _StarRow(
                rating: review.rating,
                size: 16,
                color: Colors.amber.shade700),
            // Bình luận
            if (review.comment?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Star Row ───────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow(
      {required this.rating, required this.size, required this.color});

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i + 1 <= rating;
        final half = !filled && (i + 0.5) < rating;
        return Icon(
          filled
              ? Icons.star
              : half
                  ? Icons.star_half
                  : Icons.star_border,
          size: size,
          color: color,
        );
      }),
    );
  }
}

// ─── Empty & Error States ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Chưa có đánh giá nào',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF757575)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Khi ứng viên hoàn thành công việc\nvà đánh giá, nó sẽ hiển thị ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.employerPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}
