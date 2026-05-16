import '../models/job_post_model.dart';
import 'job_post_service.dart';

class SearchService {
  final JobPostService _jobPostService = JobPostService();

  // Helper để loại bỏ dấu tiếng Việt
  String _removeDiacritics(String str) {
    const withDia =
        'áàảãạăắằẳẵặâấầẩẫậêếềểễệéèẻẽẹíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÊẾỀỂỄỆÉÈẺẼẸÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    String result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  // ── Tìm kiếm và Lọc việc làm ───────────────────────────────────────────────
  Future<List<JobPostModel>> searchJobs({
    required String keyword,
    double? minSalary,
    double? maxSalary,
    String? location,
    String? jobType,
  }) async {
    // Để đơn giản và tránh lỗi index phức tạp, ta lấy tất cả job active/approved
    // rồi thực hiện filter ở client side (vì dữ liệu hiện tại chưa lớn).
    // Nếu ứng dụng lớn, cần dùng Algolia hoặc ElasticSearch.
    final allJobs = await _jobPostService.getLatestActiveJobs();

    final normalizedKeyword = _removeDiacritics(keyword).toLowerCase().trim();

    final filtered = allJobs.where((job) {
      // 1. Keyword search (title, description, category)
      bool matchesKeyword = true;
      if (normalizedKeyword.isNotEmpty) {
        final t = _removeDiacritics(job.title).toLowerCase();
        final d = _removeDiacritics(job.description).toLowerCase();
        final c = _removeDiacritics(
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
        final locCity = _removeDiacritics(
          job.location['city']?.toString() ?? '',
        ).toLowerCase();
        final locAddress = _removeDiacritics(
          job.location['address']?.toString() ?? '',
        ).toLowerCase();
        final queryLoc = _removeDiacritics(location).toLowerCase();
        matchesLocation =
            locCity.contains(queryLoc) || locAddress.contains(queryLoc);
      }

      // 4. Job type filter
      bool matchesJobType = true;
      if (jobType != null && jobType != 'Tất cả') {
        matchesJobType = job.jobType == jobType;
      }

      return matchesKeyword &&
          matchesSalary &&
          matchesLocation &&
          matchesJobType;
    }).toList();

    return filtered;
  }
}
