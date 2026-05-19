import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_post_model.dart';

class JobPostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'jobPosts';

  // ── Tạo bài đăng mới ───────────────────────────────────────────────────────
  Future<String> createJobPost(JobPostModel post) async {
    // Duplicate check: cùng title + employerId + startDate
    final existing = await _db
        .collection(_collection)
        .where('employerId', isEqualTo: post.employerId)
        .where('title', isEqualTo: post.title)
        .where('startDate', isEqualTo: Timestamp.fromDate(post.startDate))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Bài đăng với tiêu đề và ngày bắt đầu này đã tồn tại.');
    }

    final docRef = _db.collection(_collection).doc();
    final newPost = JobPostModel(
      jobId: docRef.id,
      employerId: post.employerId,
      title: post.title,
      description: post.description,
      category: post.category,
      jobType: post.jobType,
      location: post.location,
      salary: post.salary,
      salaryType: post.salaryType,
      slots: post.slots,
      filledSlots: 0,
      startDate: post.startDate,
      endDate: post.endDate,
      workHoursPerDay: post.workHoursPerDay,
      startTime: post.startTime,
      requirements: post.requirements,
      status: post.status,
      totalBudget: post.salary * post.slots,
    );

    await docRef.set(newPost.toMap());
    return docRef.id;
  }

  // ── Lấy tất cả bài đăng của employer ──────────────────────────────────────
  // Không dùng orderBy trên Firestore → tránh yêu cầu composite index
  // Sắp xếp theo createdAt giảm dần bên phía Dart
  Stream<List<JobPostModel>> getJobPostsByEmployer(String employerId) {
    return _db
        .collection(_collection)
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map((snap) {
          final posts = snap.docs
              .map((doc) => JobPostModel.fromMap(doc.data()))
              .toList();
          posts.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime); // mới nhất trước
          });
          return posts;
        });
  }

  // ── Lấy danh sách việc làm mới nhất (cho ứng viên) ───────────────────────
  Future<List<JobPostModel>> getLatestActiveJobs() async {
    // Lấy các bài đăng ở trạng thái approved hoặc active
    // Fetch riêng 2 query để tránh lỗi index
    final futures = await Future.wait([
      _db.collection(_collection).where('status', isEqualTo: 'approved').get(),
      _db.collection(_collection).where('status', isEqualTo: 'active').get(),
    ]);

    final allDocs = [...futures[0].docs, ...futures[1].docs];
    if (allDocs.isEmpty) return [];

    final jobs = allDocs
        .map((doc) => JobPostModel.fromMap(doc.data()))
        .toList();

    // Sắp xếp mới nhất trước
    jobs.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return jobs;
  }

  // ── Cập nhật trạng thái bài đăng ─────────────────────────────────────────
  Future<void> updateStatus(String jobId, String status) async {
    await _db.collection(_collection).doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Cập nhật bài đăng ────────────────────────────────────────────────────
  Future<void> updateJobPost(JobPostModel post) async {
    final data = post.toMap();
    data.remove('createdAt'); // Không ghi đè createdAt
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(_collection).doc(post.jobId).update(data);
  }

  // ── Xóa bài đăng (chỉ draft) ─────────────────────────────────────────────
  Future<void> deleteJobPost(String jobId) async {
    await _db.collection(_collection).doc(jobId).delete();
  }

  // ── Lấy 1 bài đăng ───────────────────────────────────────────────────────
  Future<JobPostModel?> getJobPostById(String jobId) async {
    final doc = await _db.collection(_collection).doc(jobId).get();
    if (!doc.exists) return null;
    return JobPostModel.fromMap(doc.data()!);
  }
}
