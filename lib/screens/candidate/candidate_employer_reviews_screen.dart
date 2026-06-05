import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/employer_review_controller.dart';

class CandidateEmployerReviewsScreen extends StatefulWidget {
  final String employerId;
  final String employerName;

  const CandidateEmployerReviewsScreen({
    super.key,
    required this.employerId,
    required this.employerName,
  });

  @override
  State<CandidateEmployerReviewsScreen> createState() => _CandidateEmployerReviewsScreenState();
}

class _CandidateEmployerReviewsScreenState extends State<CandidateEmployerReviewsScreen> {
  late final EmployerReviewController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(EmployerReviewController(), tag: widget.employerId);
    ctrl.targetUid = widget.employerId;
    ctrl.loadReviews();
  }

  Widget _buildStars(double rating, {double size = 16}) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đánh giá ${widget.employerName}'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFBFBFB),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.reviews.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        }
        if (ctrl.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ctrl.errorMessage.value),
                TextButton(onPressed: ctrl.refresh, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        if (ctrl.reviews.isEmpty) {
          return const Center(
            child: Text('Chưa có đánh giá nào.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        final summary = ctrl.summary.value;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                color: const Color(0xFF2E7D32).withOpacity(0.05),
                child: Column(
                  children: [
                    Text(
                      summary.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStars(summary.averageRating, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      'Dựa trên ${summary.totalCount} đánh giá',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final review = ctrl.reviews[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review.reviewerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (review.createdAt != null)
                                Text(
                                  DateFormat('dd/MM/yyyy').format(review.createdAt!),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildStars(review.rating.toDouble(), size: 16),
                          if (review.comment != null && review.comment!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              review.comment!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  childCount: ctrl.reviews.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
