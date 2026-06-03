import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/employer_evaluate_candidates_controller.dart';
import '../../controller/employer_review_controller.dart';
import '../../data/models/employer_review_model.dart';

class EmployerReviewsScreen extends StatelessWidget {
  const EmployerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(EmployerReviewController());
    Get.put(EmployerEvaluateCandidatesController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.employerPrimary,
          foregroundColor: Colors.white,
          title: const Text(
            'Quản lý đánh giá',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Nhận về'),
              Tab(text: 'Cần đánh giá'),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.employerGradient,
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _ReceivedReviewsTab(),
            _EvaluateCandidatesTab(),
          ],
        ),
      ),
    );
  }
}

// ─── TAB 1: Received Reviews ──────────────────────────────────────────────────

class _ReceivedReviewsTab extends StatelessWidget {
  const _ReceivedReviewsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployerReviewController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        final summary = ctrl.summary.value;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.employerGradient,
                ),
                child: Obx(() => _RatingSummaryHeader(
                      summary: ctrl.summary.value,
                      isLoading: ctrl.isLoading.value,
                    )),
              ),
            ),
            if (ctrl.isLoading.value)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.employerPrimary),
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
              const SliverFillRemaining(child: _EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Chưa có đánh giá nào',
                subtitle: 'Khi ứng viên hoàn thành công việc\nvà đánh giá, nó sẽ hiển thị ở đây.',
              ))
            else ...[
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ReviewCard(review: ctrl.reviews[index]),
                    childCount: ctrl.reviews.length,
                  ),
                ),
              ),
            ],
          ],
        );
      }),
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

// ─── TAB 2: Evaluate Candidates ───────────────────────────────────────────────

class _EvaluateCandidatesTab extends StatelessWidget {
  const _EvaluateCandidatesTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployerEvaluateCandidatesController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.candidates.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.employerPrimary),
          );
        }
        if (ctrl.candidates.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            title: 'Chưa có ứng viên',
            subtitle: 'Bạn chưa có ca làm nào giải ngân thành công\nhoặc không có ứng viên để đánh giá.',
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.loadCandidates,
          color: AppColors.employerPrimary,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = ctrl.candidates[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.employerPrimary.withOpacity(0.12),
                        backgroundImage: (c.candidateAvatarUrl?.isNotEmpty ?? false)
                            ? NetworkImage(c.candidateAvatarUrl!)
                            : null,
                        child: (c.candidateAvatarUrl?.isEmpty ?? true)
                            ? Text(
                                _initials(c.candidateName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.employerPrimary,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.candidateName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.jobTitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (c.isReviewed)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text('Đã xong', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        )
                      else
                        OutlinedButton(
                          onPressed: () => _showRatingDialog(context, c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.employerPrimary,
                            side: const BorderSide(color: AppColors.employerPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Đánh giá'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showRatingDialog(BuildContext context, CandidateToEvaluate candidate) {
    final ctrl = Get.find<EmployerEvaluateCandidatesController>();
    double rating = 4;
    final commentCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Đánh giá ứng viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${candidate.candidateName}\n(${candidate.jobTitle})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      icon: Icon(
                        star <= rating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = star.toDouble()),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét (tùy chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Get.back();
              ctrl.submitRating(candidate.jobId, candidate.candidateId, rating, commentCtrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.employerPrimary),
            child: const Text('Gửi'),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF757575)),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
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
