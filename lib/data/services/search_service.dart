import '../models/job_post_model.dart';
import 'job_post_service.dart';

class SearchService {
  final JobPostService _jobPostService = JobPostService();

  // Helper để loại bỏ dấu tiếng Việt
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

  // ── Tìm kiếm và Lọc việc làm ───────────────────────────────────────────────
  Future<List<JobPostModel>> searchJobs({
    required String keyword,
    double? minSalary,
    double? maxSalary,
    String? location,
    String? jobType,
    String? category,
  }) async {

    final allJobs = await _jobPostService.getLatestActiveJobs();

    final normalizedKeyword = _removeVietnameseTones(keyword).toLowerCase().trim();

    final filtered = allJobs.where((job) {
      // 1. Keyword search (title, description, category)
      bool matchesKeyword = true;
      if (normalizedKeyword.isNotEmpty) {
        final t = _removeVietnameseTones(job.title).toLowerCase();
        final d = _removeVietnameseTones(job.description).toLowerCase();
        final c = _removeVietnameseTones(
          JobPostModel.categoryLabel(job.category),
        ).toLowerCase();
        matchesKeyword =
            t.contains(normalizedKeyword) ||
            d.contains(normalizedKeyword) ||
            c.contains(normalizedKeyword);
      }

      // 2. Salary filter
      bool matchesSalary = true;
      if (minSalary != null) {
        matchesSalary = matchesSalary && (job.salary >= minSalary);
      }
      if (maxSalary != null) {
        matchesSalary = matchesSalary && (job.salary <= maxSalary);
      }

      // 3. Location filter
      bool matchesLocation = true;
      if (location != null && location.isNotEmpty && location != 'Tất cả') {
        matchesLocation = _matchLocation(job.locationDisplay, location);
      }

      // 4. Job type filter
      bool matchesJobType = true;
      if (jobType != null && jobType != 'Tất cả') {
        final jType = job.jobType == 'part_time' ? 'Part-time' : 'Full-time';
        matchesJobType = jType == jobType;
      }

      // 5. Category filter
      bool matchesCategory = true;
      if (category != null && category.isNotEmpty && category != 'all' && category != 'Tất cả') {
        matchesCategory = job.category == category;
      }

      return matchesKeyword &&
          matchesSalary &&
          matchesLocation &&
          matchesJobType &&
          matchesCategory;
    }).toList();

    return filtered;
  }
}
