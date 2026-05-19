import 'package:cloud_firestore/cloud_firestore.dart';

/// Phân công công việc cho 1 thành viên trong ca
class WorkTask {
  final String userId;
  final String userName;
  final String content; // nội dung công việc được giao

  const WorkTask({
    required this.userId,
    required this.userName,
    required this.content,
  });

  factory WorkTask.fromMap(Map<String, dynamic> map) => WorkTask(
        userId: map['userId'] as String? ?? '',
        userName: map['userName'] as String? ?? '',
        content: map['content'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'content': content,
      };
}

/// Lịch làm việc của 1 ca / 1 ngày
class WorkScheduleModel {
  final String scheduleId;
  final String groupId;
  final String jobId;
  final String jobTitle;
  final String employerId;
  final String date;         // "YYYY-MM-DD"
  final String shiftStart;   // "HH:mm"
  final String shiftEnd;     // "HH:mm"
  final String generalContent;   // nội dung / yêu cầu chung
  final List<WorkTask> tasks;    // phân công theo người
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WorkScheduleModel({
    required this.scheduleId,
    required this.groupId,
    required this.jobId,
    required this.jobTitle,
    required this.employerId,
    required this.date,
    required this.shiftStart,
    required this.shiftEnd,
    required this.generalContent,
    required this.tasks,
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkScheduleModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawTasks = map['tasks'] as List? ?? [];
    return WorkScheduleModel(
      scheduleId: docId,
      groupId: map['groupId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      shiftStart: map['shiftStart'] as String? ?? '08:00',
      shiftEnd: map['shiftEnd'] as String? ?? '17:00',
      generalContent: map['generalContent'] as String? ?? '',
      tasks: rawTasks
          .map((t) => WorkTask.fromMap(t as Map<String, dynamic>))
          .toList(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'employerId': employerId,
        'date': date,
        'shiftStart': shiftStart,
        'shiftEnd': shiftEnd,
        'generalContent': generalContent,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
