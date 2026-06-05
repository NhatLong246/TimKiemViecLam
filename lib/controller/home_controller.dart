import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class HomeController extends GetxController {
  final JobPostService _jobPostService = JobPostService();

  final RxList<JobPostModel> allJobs = <JobPostModel>[].obs;
  final RxList<JobPostModel> latestJobs = <JobPostModel>[].obs;
  final RxSet<String> appliedJobIds = <String>{}.obs;
  final RxMap<String, String> appliedJobStatus = <String, String>{}.obs;
  final RxInt profileViewCount = 0.obs;
  final RxInt interestCount = 0.obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<double?> filterMinSalary = Rx<double?>(null);
  final Rx<double?> filterMaxSalary = Rx<double?>(null);
  final RxString filterLocation = 'Tất cả'.obs;
  final RxString filterJobType = 'Tất cả'.obs;

  StreamSubscription? _applicationsSub;
  StreamSubscription? _profileViewsSub;
  StreamSubscription? _interestSub;
  StreamSubscription? _authSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      fetchLatestJobs();
      _listenToApplications(user?.uid);
      _listenToProfileViews(user?.uid);
      _listenToInterests(user?.uid);
    });
  }

  @override
  void onClose() {
    _applicationsSub?.cancel();
    _profileViewsSub?.cancel();
    _interestSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }

  void _listenToApplications(String? uid) {
    _applicationsSub?.cancel();
    if (uid == null) {
      appliedJobIds.clear();
      appliedJobStatus.clear();
      return;
    }

    _applicationsSub = FirebaseFirestore.instance
        .collection('applications')
        .where('candidateId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final jobId = data['jobId'] as String?;
        final status = data['status'] as String?;
        if (jobId == null || status == null) continue;
        if (status == 'pending' ||
            status == 'accepted' ||
            status == 'withdrawn') {
          map[jobId] = status;
        }
      }
      _setAppliedStatus(map);
    });
  }

  void _listenToProfileViews(String? uid) {
    _profileViewsSub?.cancel();
    profileViewCount.value = 0;
    if (uid == null) return;

    _profileViewsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) {
        profileViewCount.value = 0;
        return;
      }
      profileViewCount.value = _parseProfileViewCount(data);
    });
  }

  int _parseProfileViewCount(Map<String, dynamic> data) {
    for (final key in const [
      'profileViewCount',
      'profileViewsCount',
      'profileViews',
      'viewCount',
    ]) {
      final raw = data[key];
      if (raw is num) return raw.toInt();
      if (raw is List) return raw.length;
      if (raw is Map) return raw.length;
    }
    return 0;
  }

  void _listenToInterests(String? uid) {
    _interestSub?.cancel();
    interestCount.value = 0;
    if (uid == null) return;

    _interestSub = FirebaseFirestore.instance
        .collection('employerInterests')
        .where('candidateId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final uniqueEmployers = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final empId = data['employerId'] as String?;
        if (empId != null && empId.isNotEmpty) {
          uniqueEmployers.add(empId);
        }
      }
      interestCount.value = uniqueEmployers.length;
    });
  }

  Future<void> fetchLatestJobs() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final results = await Future.wait([
        _jobPostService.getLatestActiveJobs(),
        _fetchAppliedJobsOnce(),
      ]);
      allJobs.value = results[0] as List<JobPostModel>;
      _applyFilter();
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void applyAdvancedFilter({
    double? minSalary,
    double? maxSalary,
    required String location,
    required String jobType,
  }) {
    filterMinSalary.value = minSalary;
    filterMaxSalary.value = maxSalary;
    filterLocation.value = location;
    filterJobType.value = jobType;
    _applyFilter();
  }

  void _applyFilter() {
    latestJobs.value = allJobs.where((j) {
      if (filterJobType.value != 'Tất cả') {
        final jType = j.jobType == 'part_time' ? 'Part-time' : 'Full-time';
        if (jType != filterJobType.value) return false;
      }

      if (!_matchLocation(j.locationDisplay, filterLocation.value)) {
        return false;
      }

      if (filterMinSalary.value != null && j.salary < filterMinSalary.value!) {
        return false;
      }
      if (filterMaxSalary.value != null && j.salary > filterMaxSalary.value!) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _matchLocation(String jobLocation, String filterLocation) {
    if (filterLocation == 'Tất cả') return true;

    final jl = _removeVietnameseTones(jobLocation.toLowerCase());

    if (filterLocation == 'TP.HCM') {
      return jl.contains('hcm') || jl.contains('ho chi minh');
    }

    if (filterLocation == 'Hà Nội') {
      return jl.contains('ha noi') || RegExp(r'\bhn\b').hasMatch(jl);
    }

    if (filterLocation == 'Đà Nẵng') {
      return jl.contains('da nang') || RegExp(r'\bdn\b').hasMatch(jl);
    }

    if (filterLocation == 'Bình Dương') {
      return jl.contains('binh duong') || RegExp(r'\bbd\b').hasMatch(jl);
    }

    final fl = _removeVietnameseTones(filterLocation.toLowerCase());
    return jl.contains(fl);
  }

  String _removeVietnameseTones(String str) {
    str = str.replaceAll(
      RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'),
      'a',
    );
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(
      RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'),
      'o',
    );
    str = str.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    str = str.replaceAll(
      RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'),
      'A',
    );
    str = str.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    str = str.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    str = str.replaceAll(
      RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'),
      'O',
    );
    str = str.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');
    str = str.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');
    str = str.replaceAll(RegExp(r'[Đ]'), 'D');
    return str;
  }

  Future<void> _fetchAppliedJobsOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _setAppliedStatus({});
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('candidateId', isEqualTo: uid)
          .get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final jobId = data['jobId'] as String?;
        final status = data['status'] as String?;
        if (jobId == null || status == null) continue;
        if (status == 'pending' ||
            status == 'accepted' ||
            status == 'withdrawn') {
          map[jobId] = status;
        }
      }
      _setAppliedStatus(map);
    } catch (_) {}
  }

  void _setAppliedStatus(Map<String, String> map) {
    appliedJobStatus.assignAll(map);
    appliedJobStatus.refresh();

    appliedJobIds
      ..clear()
      ..addAll(
        map.entries
            .where((entry) =>
                entry.value == 'pending' || entry.value == 'accepted')
            .map((entry) => entry.key),
      );
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
