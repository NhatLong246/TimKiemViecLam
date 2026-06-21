import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/employer_review_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/employer_review_service.dart';

class CandidatePublicReviewsScreen extends StatefulWidget {
  const CandidatePublicReviewsScreen({super.key, required this.candidate});

  final UserModel candidate;

  @override
  State<CandidatePublicReviewsScreen> createState() =>
      _CandidatePublicReviewsScreenState();
}

class _CandidatePublicReviewsScreenState
    extends State<CandidatePublicReviewsScreen> {
  final _service = EmployerReviewService();

  List<EmployerReviewItem> _reviews = const [];
  EmployerReviewSummary _summary = EmployerReviewSummary.fromList(const []);
  bool _loading = true;
  String? _error;
  int _selectedStars = 0;

  List<EmployerReviewItem> get _filteredReviews {
    if (_selectedStars == 0) return _reviews;
    return _reviews
        .where((review) => review.rating.round() == _selectedStars)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reviews = await _service.fetchReviews(
        targetUid: widget.candidate.id,
      );
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _summary = EmployerReviewSummary.fromList(reviews);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải đánh giá. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF15111A)
          : const Color(0xFFF8F5FB),
      appBar: AppBar(
        title: const Text(
          'Đánh giá người làm',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF7B1FA2),
        onRefresh: _loadReviews,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_outlined, size: 58, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadReviews,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }

    final filteredReviews = _filteredReviews;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildSummary(context),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedStars == 0
                    ? 'Tất cả đánh giá'
                    : 'Đánh giá $_selectedStars sao',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filteredReviews.length} đánh giá',
                style: const TextStyle(
                  color: Color(0xFF7B1FA2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildRatingFilter(),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredReviews.isEmpty)
          _buildEmptyState(context, filtered: _reviews.isNotEmpty)
        else
          ...filteredReviews.map(
            (review) => _buildReviewCard(context, review),
          ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return PopupMenuButton<int>(
      initialValue: _selectedStars,
      tooltip: 'Lọc theo số sao',
      onSelected: (stars) => setState(() => _selectedStars = stars),
      itemBuilder: (context) => [
        _buildFilterItem(0, 'Tất cả đánh giá'),
        const PopupMenuDivider(),
        for (var stars = 5; stars >= 1; stars--)
          _buildFilterItem(stars, '$stars sao'),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.25),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.filter_list_rounded,
                color: Color(0xFF7B1FA2),
                size: 22,
              ),
            ),
            if (_selectedStars != 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_selectedStars',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _buildFilterItem(int value, String label) {
    final selected = _selectedStars == value;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(
            value == 0 ? Icons.reviews_outlined : Icons.star_rounded,
            color: value == 0 ? const Color(0xFF7B1FA2) : Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_rounded,
              color: Color(0xFF7B1FA2),
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final name = widget.candidate.fullName.isEmpty
        ? 'Người làm'
        : widget.candidate.fullName;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E24AA), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _candidateAvatar(widget.candidate, 62),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _summary.totalCount == 0
                          ? 'Chưa có đánh giá'
                          : '${_summary.averageRating.toStringAsFixed(1)} / 5 • ${_summary.totalCount} lượt',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_summary.totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        _summary.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_summary.totalCount > 0) ...[
            const SizedBox(height: 18),
            ...List.generate(5, (index) {
              final star = 5 - index;
              final count = _summary.distribution[star] ?? 0;
              final ratio = count / _summary.totalCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$star',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, EmployerReviewItem review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comment = review.comment?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2131) : const Color(0xFFFCF7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8E24AA).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFFF3E5F5),
            backgroundImage: review.reviewerAvatarUrl?.isNotEmpty == true
                ? NetworkImage(review.reviewerAvatarUrl!)
                : null,
            child: review.reviewerAvatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    _initial(review.reviewerName),
                    style: const TextStyle(
                      color: Color(0xFF7B1FA2),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.reviewerName.isEmpty
                            ? 'Người dùng'
                            : review.reviewerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E24AA), Color(0xFF1565C0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (review.createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd/MM/yyyy').format(review.createdAt!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 17,
                    ),
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(comment, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool filtered = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8E24AA).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.reviews_outlined,
            size: 50,
            color: Color(0xFFB39DDB),
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Không có đánh giá $_selectedStars sao'
                : 'Người làm này chưa có đánh giá',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Widget _candidateAvatar(UserModel user, double size) {
  ImageProvider? image;
  if (user.avatarUrl?.isNotEmpty == true) {
    image = NetworkImage(user.avatarUrl!);
  } else if (user.avatarBase64?.isNotEmpty == true) {
    try {
      image = MemoryImage(base64Decode(user.avatarBase64!));
    } catch (_) {}
  }
  final name = user.fullName.isEmpty ? 'N' : user.fullName;
  return Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
    ),
    child: CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFF3E5F5),
      backgroundImage: image,
      child: image == null
          ? Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7B1FA2),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    ),
  );
}

String _initial(String name) {
  final value = name.trim();
  return value.isEmpty ? '?' : value[0].toUpperCase();
}
