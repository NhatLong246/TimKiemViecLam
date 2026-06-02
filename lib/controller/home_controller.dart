import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/job_post_model.dart';
import '../data/services/job_post_service.dart';

class HomeController extends GetxController {
  final JobPostService _jobPostService = JobPostService();

  final RxList<JobPostModel> allJobs = <JobPostModel>[].obs;
  final RxList<JobPostModel> latestJobs = <JobPostModel>[].obs;
  final RxSet<String> appliedJobIds = <String>{}.obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  // Lọc
  final Rx<double?> filterMinSalary = Rx<double?>(null);
  final Rx<double?> filterMaxSalary = Rx<double?>(null);
  final RxString filterLocation = 'Tất cả'.obs;
  final RxString filterJobType = 'Tất cả'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLatestJobs();
  }

  Future<void> fetchLatestJobs() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final jobs = await _jobPostService.getLatestActiveJobs();
      allJobs.value = jobs;
      _applyFilter();
      await fetchAppliedJobs();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMessage.value = msg;
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
      // Lọc loại công việc
      if (filterJobType.value != 'Tất cả') {
        final jType = j.jobType == 'part_time' ? 'Part-time' : 'Full-time';
        if (jType != filterJobType.value) return false;
      }
      
      // Lọc khu vực
      if (!_matchLocation(j.locationDisplay, filterLocation.value)) return false;

      // Lọc lương
      if (filterMinSalary.value != null && j.salary < filterMinSalary.value!) return false;
      if (filterMaxSalary.value != null && j.salary > filterMaxSalary.value!) return false;

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

  Future<void> fetchAppliedJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('candidateId', isEqualTo: uid)
          .get();
      final newSet = snap.docs
          .map((d) => d.data()['jobId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      appliedJobIds.clear();
      appliedJobIds.addAll(newSet);
    } catch (e) {
      print('Lỗi fetchAppliedJobs: $e');
    }
  }

  Future<void> refreshJobs() async {
    await fetchLatestJobs();
  }
}
