import 'package:get/get.dart';
import '../data/models/employer_review_model.dart';
import '../data/services/employer_review_service.dart';

class EmployerReviewController extends GetxController {
  final EmployerReviewService _service = EmployerReviewService();

  final RxList<EmployerReviewItem> reviews = <EmployerReviewItem>[].obs;
  final Rx<EmployerReviewSummary> summary = EmployerReviewSummary.fromList([]).obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadReviews();
  }

  Future<void> loadReviews() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _service.fetchReviews();
      reviews.assignAll(data);
      summary.value = EmployerReviewSummary.fromList(data);
    } catch (e) {
      errorMessage.value = 'Không thể tải đánh giá. Vui lòng thử lại.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => loadReviews();
}
