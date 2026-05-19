import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/login_controller.dart';

class AttendanceToolScreen extends StatelessWidget {
  const AttendanceToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().currentUser?.id ??
        FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text(
          'Công cụ điểm danh',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: uid == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('employerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                docs.sort((a, b) {
                  final da = (a.data()['date'] ?? '').toString();
                  final db = (b.data()['date'] ?? '').toString();
                  return db.compareTo(da);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Chưa có điểm danh. Ứng viên điểm danh đầu/cuối ca trong hội thoại tin nhắn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final date = (d['date'] ?? '').toString();
                    final jobId = (d['jobId'] ?? '').toString();
                    final records = d['records'] as List? ?? [];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày $date',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Job: $jobId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...records.map((r) {
                            if (r is! Map) return const SizedBox.shrink();
                            final cid = (r['candidateId'] ?? '').toString();
                            final inT = (r['checkInTime'] ?? '—').toString();
                            final outT = (r['checkOutTime'] ?? '—').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'UV ${cid.substring(0, cid.length.clamp(0, 8))}… · Vào $inT · Ra $outT',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
