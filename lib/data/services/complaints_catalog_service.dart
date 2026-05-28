import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/complaint_catalog_item.dart';

class ComplaintsCatalogService {
  final _db = FirebaseFirestore.instance;

  Future<List<ComplaintCatalogItem>> fetchForUser({
    required String role,
    required String uid,
  }) async {
    final items = <ComplaintCatalogItem>[];

    if (role == 'admin') {
      final inc = await _db.collection('incidents').limit(80).get();
      final job = await _db.collection('jobComplaints').limit(80).get();
      for (final d in inc.docs) {
        items.add(ComplaintCatalogItem.fromIncident(
          d.data(),
          d.id,
          direction: ComplaintDirection.sent,
        ));
      }
      for (final d in job.docs) {
        items.add(ComplaintCatalogItem.fromJobComplaint(
          d.data(),
          d.id,
          direction: ComplaintDirection.sent,
        ));
      }
    } else if (role == 'employer') {
      // NTD gửi: khiếu nại nhân viên
      final sentInc = await _db
          .collection('incidents')
          .where('reportedBy', isEqualTo: uid)
          .limit(50)
          .get();
      for (final d in sentInc.docs) {
        items.add(ComplaintCatalogItem.fromIncident(
          d.data(),
          d.id,
          direction: ComplaintDirection.sent,
        ));
      }
      // NTD nhận: UV khiếu nại công việc
      final receivedJob = await _db
          .collection('jobComplaints')
          .where('employerId', isEqualTo: uid)
          .limit(50)
          .get();
      for (final d in receivedJob.docs) {
        items.add(ComplaintCatalogItem.fromJobComplaint(
          d.data(),
          d.id,
          direction: ComplaintDirection.received,
        ));
      }
    } else {
      // UV gửi: khiếu nại công việc
      final sentJob = await _db
          .collection('jobComplaints')
          .where('candidateId', isEqualTo: uid)
          .limit(50)
          .get();
      for (final d in sentJob.docs) {
        items.add(ComplaintCatalogItem.fromJobComplaint(
          d.data(),
          d.id,
          direction: ComplaintDirection.sent,
        ));
      }
      // UV nhận: NTD khiếu nại nhân viên (về mình)
      final receivedInc = await _db
          .collection('incidents')
          .where('workerId', isEqualTo: uid)
          .limit(50)
          .get();
      for (final d in receivedInc.docs) {
        items.add(ComplaintCatalogItem.fromIncident(
          d.data(),
          d.id,
          direction: ComplaintDirection.received,
        ));
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}
