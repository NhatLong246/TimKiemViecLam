import 'package:get/get.dart';
import '../data/models/candidate_dashboard_models.dart';
import '../data/services/candidate_dashboard_service.dart';
import 'login_controller.dart';

class CandidateDashboardController extends GetxController {
  final CandidateDashboardService _service = CandidateDashboardService();

  final payments = <CandidatePayment>[].obs;
  final reviews = <CandidateReviewGiven>[].obs;
  final reviewableJobs = <ReviewableJob>[].obs;
  final groups = <WorkGroup>[].obs;
  final summary = Rxn<CandidateEarningsSummary>();
  final isLoading = false.obs;
  final isWithdrawing = false.obs;
  final errorMessage = ''.obs;

  double get profileRating {
    final user = Get.find<AuthController>().currentUser;
    return user?.averageRating ?? 0;
  }

  Future<void> loadBenefits() async {
    await _load(() async {
      payments.assignAll(await _service.fetchPayments());
      summary.value = await _service.fetchSummary(
        payments: payments,
        profileRating: profileRating,
      );
    });
  }

  Future<void> loadReviews() async {
    await _load(() async {
      reviewableJobs.assignAll(await _service.fetchReviewableJobs());
      reviews.assignAll(await _service.fetchReviewsGiven());
    });
  }

  Future<void> loadGroups() async {
    await _load(() async {
      groups.assignAll(await _service.fetchWorkGroups());
    });
  }

  Future<void> submitReview({
    required String jobId,
    required String employerId,
    required double rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    await _service.submitReview(
      jobId: jobId,
      employerId: employerId,
      rating: rating,
      comment: comment,
      tags: tags,
    );
    await loadReviews();
  }

  Future<WorkGroup> createGroup(String name) async {
    final g = await _service.createGroup(name);
    await loadGroups();
    return g;
  }

  Future<WorkGroup> joinGroup(String code) async {
    final g = await _service.joinGroup(code);
    await loadGroups();
    return g;
  }

  Future<void> withdraw({
    required int amountVnd,
    String? note,
  }) async {
    isWithdrawing.value = true;
    try {
      await _service.withdraw(amountVnd: amountVnd, note: note);
      await loadBenefits();
    } finally {
      isWithdrawing.value = false;
    }
  }

  Future<void> _load(Future<void> Function() action) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await action();
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
