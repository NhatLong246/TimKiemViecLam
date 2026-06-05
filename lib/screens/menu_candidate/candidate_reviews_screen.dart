import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/candidate_dashboard_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/candidate_dashboard_models.dart';
import 'candidate_menu_scaffold.dart';

class CandidateReviewsScreen extends StatefulWidget {
  const CandidateReviewsScreen({super.key});

  @override
  State<CandidateReviewsScreen> createState() => _CandidateReviewsScreenState();
}

class _CandidateReviewsScreenState extends State<CandidateReviewsScreen> {
  final _ctrl = Get.put(CandidateDashboardController());

  @override
  void initState() {
    super.initState();
    _ctrl.loadReviews();
  }

  double get _myRating =>
      Get.find<AuthController>().currentUser?.averageRating ?? 0;

  @override
  Widget build(BuildContext context) {
    return CandidateMenuScaffold(
      title: 'Uy tín & đánh giá',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReviewDialog(context),
        backgroundColor: candidateMenuPrimary,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Đánh giá NTD'),
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.reviews.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: candidateMenuPrimary),
          );
        }
        return RefreshIndicator(
          color: candidateMenuPrimary,
          onRefresh: _ctrl.loadReviews,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              _buildRatingHeader(),
              const SizedBox(height: 20),
              const Text(
                'Đánh giá bạn đã gửi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_ctrl.reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Chưa có đánh giá. Hoàn thành ca làm và đánh giá nhà tuyển dụng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ..._ctrl.reviews.map(_reviewCard),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRatingHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _myRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điểm uy tín của bạn',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < _myRating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NTD xem điểm này khi duyệt hồ sơ của bạn.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(CandidateReviewGiven r) {
    final date = r.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(r.createdAt!)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.employerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                ],
              ),
            ],
          ),
          Text(
            r.jobTitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.tags
                  .map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFE8F5E9),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(BuildContext context) async {
    final jobs = _ctrl.reviewableJobs.toList();
    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có công việc nào đã hoàn thành để đánh giá. Bạn chỉ có thể đánh giá NTD sau khi ca làm việc kết thúc.',
          ),
        ),
      );
      return;
    }

    ReviewableJob? selected = jobs.first;
    final commentCtrl = TextEditingController();
    double rating = 5;
    final tags = <String>{};
    const tagOptions = [
      'Đúng mô tả',
      'Trả đúng hạn',
      'Môi trường tốt',
      'Quản lý hỗ trợ',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Đánh giá nhà tuyển dụng',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ReviewableJob>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Công việc đã nhận',
                      border: OutlineInputBorder(),
                    ),
                    items: jobs
                        .map(
                          (j) => DropdownMenuItem(
                            value: j,
                            child: Text(
                              j.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () =>
                            setModalState(() => rating = (i + 1).toDouble()),
                        icon: Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  Wrap(
                    spacing: 8,
                    children: tagOptions.map((t) {
                      final selected = tags.contains(t);
                      return FilterChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (v) {
                          setModalState(() {
                            if (v) {
                              tags.add(t);
                            } else {
                              tags.remove(t);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nhận xét (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final job = selected;
                        if (job == null) return;
                        await _ctrl.submitReview(
                          jobId: job.jobId,
                          employerId: job.employerId,
                          rating: rating,
                          comment: commentCtrl.text.trim().isEmpty
                              ? null
                              : commentCtrl.text.trim(),
                          tags: tags.toList(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã gửi đánh giá'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: candidateMenuPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Gửi đánh giá'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
