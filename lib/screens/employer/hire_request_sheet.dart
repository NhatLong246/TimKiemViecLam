import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/job_post_model.dart';
import '../../data/services/candidate_discovery_service.dart';

Future<void> showHireRequestSheet({
  required BuildContext context,
  required String candidateId,
  required String candidateName,
  String? jobTypeFilter,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.78,
      child: HireRequestSheet(
        candidateId: candidateId,
        candidateName: candidateName,
        jobTypeFilter: jobTypeFilter,
      ),
    ),
  );
}

class HireRequestSheet extends StatefulWidget {
  const HireRequestSheet({
    super.key,
    required this.candidateId,
    required this.candidateName,
    this.jobTypeFilter,
  });

  final String candidateId;
  final String candidateName;
  final String? jobTypeFilter;

  @override
  State<HireRequestSheet> createState() => _HireRequestSheetState();
}

class _HireRequestSheetState extends State<HireRequestSheet> {
  final _db = FirebaseFirestore.instance;
  final _service = CandidateDiscoveryService();

  List<JobPostModel> _jobs = const [];
  Set<String> _sentJobIds = const {};
  bool _loading = true;
  String? _sendingJobId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Phiên đăng nhập đã hết hạn.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _db.collection('jobPosts').where('employerId', isEqualTo: uid).get(),
        _db
            .collection('applications')
            .where('candidateId', isEqualTo: widget.candidateId)
            .get(),
        _db
            .collection('employerInterests')
            .where('candidateId', isEqualTo: widget.candidateId)
            .get(),
      ]);

      final applicationDocs = results[1].docs.where((doc) {
        final data = doc.data();
        final sameEmployer = data['employerId']?.toString() == uid;
        final status = (data['status'] ?? '').toString();
        return sameEmployer && (status == 'pending' || status == 'accepted');
      });
      final unavailableJobIds = applicationDocs
          .map((doc) => doc.data()['jobId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final sentJobIds = results[2].docs
          .where((doc) {
            final data = doc.data();
            final sameEmployer = data['employerId']?.toString() == uid;
            final status = (data['status'] ?? 'pending').toString();
            return sameEmployer &&
                (status == 'pending' || status == 'accepted');
          })
          .map((doc) => doc.data()['jobId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final now = DateTime.now();
      final jobs =
          results[0].docs
              .map((doc) {
                final data = Map<String, dynamic>.from(doc.data());
                data['jobId'] = doc.id;
                return JobPostModel.fromMap(data);
              })
              .where((job) {
                if (job.status != 'active' && job.status != 'approved') {
                  return false;
                }
                if (widget.jobTypeFilter != null &&
                    job.jobType != widget.jobTypeFilter) {
                  return false;
                }
                if (job.filledSlots >= job.slots) return false;
                if (unavailableJobIds.contains(job.jobId)) return false;
                if (job.applicationDeadline?.isBefore(now) == true) {
                  return false;
                }
                if (job.endDate?.isBefore(now) == true) return false;
                if (job.endDate == null &&
                    job.startDate.add(const Duration(days: 1)).isBefore(now)) {
                  return false;
                }
                return true;
              })
              .toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _sentJobIds = sentJobIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải danh sách công việc. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _send(JobPostModel job) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _sendingJobId != null) return;
    setState(() => _sendingJobId = job.jobId);
    try {
      final employerDoc = await _db.collection('users').doc(uid).get();
      final data = employerDoc.data() ?? const <String, dynamic>{};
      final employerName = (data['companyName'] ?? data['firstName'] ?? '')
          .toString()
          .trim();
      final sent = await _service.sendInterestNotification(
        candidateId: widget.candidateId,
        employerId: uid,
        employerName: employerName.isEmpty ? 'Nhà tuyển dụng' : employerName,
        jobId: job.jobId,
        jobTitle: job.title,
      );

      if (!mounted) return;
      if (!sent) {
        Get.snackbar(
          'Thông báo',
          'Bạn đã gửi lời mời cho công việc này rồi.',
          snackPosition: SnackPosition.BOTTOM,
        );
        setState(() => _sentJobIds = {..._sentJobIds, job.jobId});
        return;
      }

      Navigator.of(context).pop();
      Get.snackbar(
        'Đã gửi yêu cầu',
        'Lời mời làm việc đã được gửi đến ${widget.candidateName}.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Gửi thất bại',
        'Không thể gửi yêu cầu thuê. Vui lòng thử lại.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _sendingJobId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn công việc để gửi yêu cầu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gửi lời mời đến ${widget.candidateName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadJobs,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_jobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không có công việc phù hợp đang còn hạn và còn vị trí.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final job = _jobs[index];
        final alreadySent = _sentJobIds.contains(job.jobId);
        final sending = _sendingJobId == job.jobId;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                color: Color(0xFF7B1FA2),
              ),
            ),
            title: Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${job.salaryDisplay} • ${job.filledSlots}/${job.slots} người',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : alreadySent
                ? const Text(
                    'Đã gửi',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : FilledButton(
                    onPressed: _sendingJobId == null ? () => _send(job) : null,
                    child: const Text('Gửi'),
                  ),
          ),
        );
      },
    );
  }
}
