import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../data/models/job_post_model.dart';
import '../data/models/weather_model.dart';
import '../data/services/job_post_service.dart';
import '../data/services/weather_service.dart';

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

  final Rx<WeatherModel?> weather = Rx<WeatherModel?>(null);
  final RxBool isLoadingWeather = true.obs;
  final RxString weatherError = ''.obs;

  final Rx<double?> filterMinSalary = Rx<double?>(null);
  final Rx<double?> filterMaxSalary = Rx<double?>(null);
  final RxString filterLocation = 'Tất cả'.obs;
  final RxString filterJobType = 'Tất cả'.obs;
  final RxString filterCategory = 'all'.obs;
  final RxString filterGender = 'Tất cả'.obs;
  final RxString filterLanguage = 'Tất cả'.obs;
  final RxString filterLanguageLevel = 'Tất cả'.obs;
  final RxString filterExperience = 'Tất cả'.obs;

  StreamSubscription? _applicationsSub;
  StreamSubscription? _profileViewsSub;
  StreamSubscription? _interestSub;
  StreamSubscription? _authSub;
  StreamSubscription? _approvedJobsSub;
  StreamSubscription? _activeJobsSub;
  final Map<String, JobPostModel> _approvedLiveJobs = {};
  final Map<String, JobPostModel> _activeLiveJobs = {};
  bool _hasApprovedJobsSnapshot = false;
  bool _hasActiveJobsSnapshot = false;

  @override
  void onInit() {
    super.onInit();
    fetchWeather();
    _listenToLatestJobs();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      fetchLatestJobs();
      _listenToApplications(user?.uid);
      _listenToProfileViews(user?.uid);
      _listenToInterests(user?.uid);
    });
  }

  Future<void> fetchWeather() async {
    isLoadingWeather.value = true;
    weatherError.value = '';
    try {
      final w = await WeatherService().fetchWeather();
      weather.value = w;
    } catch (e) {
      weatherError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingWeather.value = false;
    }
  }

  @override
  void onClose() {
    _applicationsSub?.cancel();
    _profileViewsSub?.cancel();
    _interestSub?.cancel();
    _authSub?.cancel();
    _approvedJobsSub?.cancel();
    _activeJobsSub?.cancel();
    super.onClose();
  }

  void _listenToLatestJobs() {
    _approvedJobsSub?.cancel();
    _activeJobsSub?.cancel();

    _approvedJobsSub = FirebaseFirestore.instance
        .collection('jobPosts')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snap) {
          _hasApprovedJobsSnapshot = true;
          _replaceLiveJobs(_approvedLiveJobs, snap);
          _mergeLiveJobs();
        });

    _activeJobsSub = FirebaseFirestore.instance
        .collection('jobPosts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
          _hasActiveJobsSnapshot = true;
          _replaceLiveJobs(_activeLiveJobs, snap);
          _mergeLiveJobs();
        });
  }

  void _replaceLiveJobs(
    Map<String, JobPostModel> target,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    target
      ..clear()
      ..addEntries(
        snap.docs.map(
          (doc) => MapEntry(
            doc.id,
            JobPostModel.fromMap({...doc.data(), 'jobId': doc.id}),
          ),
        ),
      );
  }

  void _mergeLiveJobs() {
    if (!_hasApprovedJobsSnapshot || !_hasActiveJobsSnapshot) return;
    final merged = <String, JobPostModel>{
      ..._approvedLiveJobs,
      ..._activeLiveJobs,
    }.values.where(_isVisibleCandidateJob).toList();

    merged.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    allJobs.value = merged;
    _applyFilter();
    isLoading.value = false;
  }

  bool _isVisibleCandidateJob(JobPostModel job) {
    final deadline = job.applicationDeadline;
    return deadline == null || deadline.isAfter(DateTime.now());
  }

  void _listenToApplications(String? uid) {
    _applicationsSub?.cancel();
    if (uid == null) {
      _setAppliedStatus({});
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
                status == 'rejected' ||
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
    required String category,
    required String gender,
    required String language,
    required String languageLevel,
    required String experience,
  }) {
    filterMinSalary.value = minSalary;
    filterMaxSalary.value = maxSalary;
    filterLocation.value = location;
    filterJobType.value = jobType;
    filterCategory.value = category;
    filterGender.value = gender;
    filterLanguage.value = language;
    filterLanguageLevel.value = languageLevel;
    filterExperience.value = experience;
    _applyFilter();
  }

  void _applyFilter() {
    final filtered = allJobs.where((j) {
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

      if (filterCategory.value != 'all' && filterCategory.value != 'Tất cả') {
        if (j.category != filterCategory.value) return false;
      }

      // Language filter
      if (filterLanguage.value != 'Tất cả') {
        final req = (j.requirements ?? '').toLowerCase() + ' ' + j.description.toLowerCase();
        final normalizedReq = _removeVietnameseTones(req);
        final targetLang = filterLanguage.value.toLowerCase();
        
        bool langMatch = false;
        if (targetLang == 'tiếng anh') {
          langMatch = normalizedReq.contains('anh') || normalizedReq.contains('english') || normalizedReq.contains('ielts') || normalizedReq.contains('toeic');
        } else if (targetLang == 'tiếng trung') {
          langMatch = normalizedReq.contains('trung') || normalizedReq.contains('chinese') || normalizedReq.contains('hsk');
        } else if (targetLang == 'tiếng nhật') {
          langMatch = normalizedReq.contains('nhat') || normalizedReq.contains('japanese') || normalizedReq.contains('jlpt') || normalizedReq.contains('n1') || normalizedReq.contains('n2') || normalizedReq.contains('n3');
        } else if (targetLang == 'tiếng hàn') {
          langMatch = normalizedReq.contains('han') || normalizedReq.contains('korean') || normalizedReq.contains('topik');
        } else {
          langMatch = normalizedReq.contains(_removeVietnameseTones(targetLang));
        }

        if (!langMatch) return false;
        
        if (filterLanguageLevel.value != 'Tất cả') {
          final targetLevel = _removeVietnameseTones(filterLanguageLevel.value.toLowerCase());
          if (!normalizedReq.contains(targetLevel)) return false;
        }
      }

      // Experience filter
      if (filterExperience.value != 'Tất cả') {
        final req = (j.requirements ?? '').toLowerCase() + ' ' + j.description.toLowerCase();
        final normalizedReq = _removeVietnameseTones(req);
        
        final noExpTerms = ['khong yeu cau kinh nghiem', 'khong can kinh nghiem', 'chua co kinh nghiem', 'no experience'];
        bool explicitlyNoExp = noExpTerms.any((term) => normalizedReq.contains(term));
        
        final regex = RegExp(r'(\d+)\s*(nam|year)');
        final match = regex.firstMatch(normalizedReq);
        double reqYears = 0;
        if (match != null) {
          reqYears = double.tryParse(match.group(1) ?? '0') ?? 0;
        }
        
        if (explicitlyNoExp || (reqYears == 0 && !normalizedReq.contains('kinh nghiem'))) {
          if (filterExperience.value != 'no_exp') return false;
        } else {
          if (filterExperience.value == 'no_exp') {
            if (reqYears != 0) return false;
          } else if (filterExperience.value == 'under_1') {
            if (!(reqYears > 0 && reqYears < 1.0)) return false;
          } else if (filterExperience.value == '1_to_3') {
            if (!(reqYears >= 1.0 && reqYears <= 3.0)) return false;
          } else if (filterExperience.value == '3_to_5') {
            if (!(reqYears >= 3.0 && reqYears <= 5.0)) return false;
          } else if (filterExperience.value == 'over_5') {
            if (reqYears <= 5.0) return false;
          }
        }
      }

      return true;
    }).toList();

    filtered.sort(_compareDashboardJobs);
    latestJobs.value = filtered;
  }

  int _compareDashboardJobs(JobPostModel a, JobPostModel b) {
    final aPriority = _applicationSortPriority(appliedJobStatus[a.jobId]);
    final bPriority = _applicationSortPriority(appliedJobStatus[b.jobId]);
    if (aPriority != bPriority) return aPriority.compareTo(bPriority);

    final aTime = a.createdAt ?? a.startDate;
    final bTime = b.createdAt ?? b.startDate;
    return bTime.compareTo(aTime);
  }

  int _applicationSortPriority(String? status) {
    if (status == 'accepted') return 0;
    if (status == 'pending') return 1;
    return 2;
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
    str = str.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    str = str.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');
    str = str.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    str = str.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    str = str.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');
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
            status == 'rejected' ||
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
            .where(
              (entry) => entry.value == 'pending' || entry.value == 'accepted',
            )
            .map((entry) => entry.key),
      );
    _applyFilter();
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
