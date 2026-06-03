import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/employer_home_controller.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';

const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
const _gradientBegin = Alignment.centerLeft;
const _gradientEnd = Alignment.centerRight;

enum _HistorySection { completedWork, removed }

class PostHistoryScreen extends StatefulWidget {
  const PostHistoryScreen({super.key});

  @override
  State<PostHistoryScreen> createState() => _PostHistoryScreenState();
}

class _PostHistoryScreenState extends State<PostHistoryScreen> {
  _HistorySection _selectedSection = _HistorySection.completedWork;

  @override
  Widget build(BuildContext context) {
    final homeCtrl = Get.find<EmployerHomeController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 72,
            toolbarHeight: 64,
            elevation: 0,
            backgroundColor: _gradientColors.last,
            titleSpacing: 0,
            title: const Text(
              'Lịch sử bài đăng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                ),
              ),
            ),
          ),
          Obx(() {
            final completedWork = homeCtrl.completedWorkPosts;
            final removed = homeCtrl.removedPosts;

            if (homeCtrl.isLoading.value) {
              return const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF7B1FA2)),
                  ),
                ),
              );
            }

            if (completedWork.isEmpty && removed.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              );
            }

            final selectedJobs =
                _selectedSection == _HistorySection.completedWork
                ? completedWork
                : removed;
            final selectedColor = _sectionColor(_selectedSection);

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSummaryRow(completedWork.length, removed.length),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    title: _sectionTitle(_selectedSection),
                    count: selectedJobs.length,
                    icon: _sectionIcon(_selectedSection),
                    color: selectedColor,
                  ),
                  if (selectedJobs.isEmpty)
                    _buildInlineEmpty(_sectionEmptyText(_selectedSection))
                  else
                    for (final job in selectedJobs)
                      _buildHistoryCard(context, job, _selectedSection),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int completedCount, int removedCount) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            section: _HistorySection.completedWork,
            label: 'Đã làm xong',
            value: completedCount,
            icon: Icons.done_all_rounded,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryTile(
            section: _HistorySection.removed,
            label: 'Hủy / xóa',
            value: removedCount,
            icon: Icons.remove_circle_outline_rounded,
            color: const Color(0xFFC62828),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required _HistorySection section,
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    final selected = _selectedSection == section;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedSection = section),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.6 : 0.22),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF616161),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sectionTitle(_HistorySection section) {
    return section == _HistorySection.completedWork
        ? 'Bài đã làm xong'
        : 'Bài đã hủy / đã xóa';
  }

  String _sectionEmptyText(_HistorySection section) {
    return section == _HistorySection.completedWork
        ? 'Chưa có bài đã hoàn tất công việc.'
        : 'Chưa có bài bị hủy do không đủ người hoặc bị xóa.';
  }

  IconData _sectionIcon(_HistorySection section) {
    return section == _HistorySection.completedWork
        ? Icons.task_alt_rounded
        : Icons.delete_sweep_outlined;
  }

  Color _sectionColor(_HistorySection section) {
    return section == _HistorySection.completedWork
        ? const Color(0xFF1565C0)
        : const Color(0xFFC62828);
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF212121),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEmpty(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF757575),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: [Color(0xFFF3E5F5), Color(0xFFE3F2FD)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 40,
                color: Color(0xFF7B1FA2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có dữ liệu lịch sử',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF616161),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bài đã làm xong hoặc bài đã hủy/xóa sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    JobPostModel job,
    _HistorySection section,
  ) {
    final typeLabel = job.jobType == 'part_time' ? 'Part-time' : 'Full-time';
    final statusColor = _statusColor(job, section);
    final statusLabel = _statusLabel(job, section);
    final dateLabel = section == _HistorySection.completedWork
        ? 'Kết thúc: ${_formatDate(job.endDate ?? job.startDate)}'
        : 'Cập nhật: ${_formatDate(job.updatedAt ?? job.createdAt ?? job.startDate)}';
    final reason = section == _HistorySection.completedWork
        ? 'Công việc đã làm xong'
        : job.status == 'deleted'
        ? 'Doanh nghiệp chủ động xóa bài'
        : 'Hủy do không đủ người';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    section == _HistorySection.completedWork
                        ? Icons.task_alt_rounded
                        : Icons.event_busy_outlined,
                    color: statusColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(
                  job.salaryDisplay,
                  const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32),
                ),
                _buildTag(
                  typeLabel,
                  const Color(0xFFE3F2FD),
                  const Color(0xFF1565C0),
                ),
                _buildTag(
                  '${job.filledSlots}/${job.slots} người',
                  const Color(0xFFF3E5F5),
                  const Color(0xFF7B1FA2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_on_outlined,
              job.locationDisplay.isNotEmpty
                  ? job.locationDisplay
                  : 'Chưa cập nhật địa điểm',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today_outlined, dateLabel),
            const SizedBox(height: 12),
            _buildActionButtons(job),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(JobPostModel job) {
    return OutlinedButton.icon(
      onPressed: () => Get.toNamed(
        AppRoutes.jobDetail,
        arguments: {'job': job, 'fromPostHistory': true},
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: Color(0xFF7B1FA2), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      icon: const Icon(
        Icons.article_outlined,
        color: Color(0xFF7B1FA2),
        size: 18,
      ),
      label: const Text(
        'Chi tiết',
        style: TextStyle(
          color: Color(0xFF7B1FA2),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _statusColor(JobPostModel job, _HistorySection section) {
    if (section == _HistorySection.completedWork) {
      return const Color(0xFF1565C0);
    }
    return job.status == 'deleted'
        ? const Color(0xFF6D4C41)
        : const Color(0xFFC62828);
  }

  String _statusLabel(JobPostModel job, _HistorySection section) {
    if (section == _HistorySection.completedWork) {
      return 'Đã làm xong';
    }
    return job.status == 'deleted' ? 'Đã xóa' : 'Đã hủy';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
