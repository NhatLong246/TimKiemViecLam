import 'package:get/get.dart';
import '../data/models/messaging_models.dart';
import '../data/services/messaging_service.dart';
import 'login_controller.dart';

class MessagingController extends GetxController {
  final MessagingService _service = MessagingService();

  final conversations = <ConversationThread>[].obs;
  final messages = <JobChatMessage>[].obs;
  final isLoading = false.obs;
  final isSending = false.obs;
  final errorMessage = ''.obs;

  final activeThread = Rxn<ConversationThread>();

  String get currentUid => Get.find<AuthController>().currentUser?.id ?? '';

  String get currentRole =>
      Get.find<AuthController>().currentUser?.role ?? 'candidate';

  bool get isEmployer => currentRole == 'employer';

  @override
  void onClose() {
    activeThread.value = null;
    super.onClose();
  }

  Future<void> loadInbox() async {
    final uid = currentUid;
    if (uid.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _service.syncChatsFromAcceptedApplications(uid, currentRole);
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void bindInboxStream() {
    final uid = currentUid;
    if (uid.isEmpty) return;

    _service.streamConversations(uid).listen(
      (list) => conversations.assignAll(list),
      onError: (e) {
        errorMessage.value = e.toString();
      },
    );
  }

  Future<void> openChat(ConversationThread thread) async {
    activeThread.value = thread;
    messages.clear();
    _service.streamMessages(thread.groupId).listen(
      (list) => messages.assignAll(list),
      onError: (e) {
        errorMessage.value = e.toString();
      },
    );
  }

  void closeChat() {
    activeThread.value = null;
    messages.clear();
  }

  Future<void> openChatByGroupId(String groupId) async {
    for (final c in conversations) {
      if (c.groupId == groupId) {
        await openChat(c);
        return;
      }
    }
    final thread = await _service.getThread(groupId, currentUid);
    if (thread != null) await openChat(thread);
  }

  Future<void> sendText(String text) async {
    final thread = activeThread.value;
    if (thread == null) return;

    isSending.value = true;
    try {
      await _service.sendText(thread.groupId, text);
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> checkIn() async {
    final thread = activeThread.value;
    if (thread == null || thread.candidateId == null) return;

    isSending.value = true;
    try {
      await _service.checkInShift(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: thread.candidateId!,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<void> checkOut() async {
    final thread = activeThread.value;
    if (thread == null || thread.candidateId == null) return;

    isSending.value = true;
    try {
      await _service.checkOutShift(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: thread.candidateId!,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendSchedule({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final thread = activeThread.value;
    if (thread == null || thread.candidateId == null) return;

    isSending.value = true;
    try {
      await _service.createSchedule(
        groupId: thread.groupId,
        jobId: thread.jobId,
        employerId: thread.employerId,
        candidateId: thread.candidateId!,
        date: date,
        startTime: startTime,
        endTime: endTime,
        jobTitle: thread.jobTitle,
        employerName: thread.peerName,
      );
    } finally {
      isSending.value = false;
    }
  }
}
