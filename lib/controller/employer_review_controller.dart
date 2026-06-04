import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/employer_review_model.dart';
import '../data/services/employer_review_service.dart';

class EmployerReviewController extends GetxController {
  final EmployerReviewService _service = EmployerReviewService();

  final RxList<EmployerReviewItem> reviews = <EmployerReviewItem>[].obs;
  final Rx<EmployerReviewSummary> summary = EmployerReviewSummary.fromList([]).obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  late String targetUid;
  late String title;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['uid'] != null) {
      targetUid = args['uid'];
      title = args['title'] ?? 'Đánh giá';
    } else {
      targetUid = FirebaseAuth.instance.currentUser!.uid;
      title = 'Đánh giá từ ứng viên';
    }
    loadReviews();
  }

  Future<void> loadReviews() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _service.fetchReviews(targetUid: targetUid);
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
