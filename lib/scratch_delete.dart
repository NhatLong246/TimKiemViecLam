import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final jobId = '123';
  final snaps = await FirebaseFirestore.instance
      .collection('jobs')
      .doc(jobId)
      .collection('attendance')
      .where('date', isGreaterThan: '2026-06-04')
      .get();
      
  print('Found ${snaps.docs.length} sessions to delete.');
  
  for (var doc in snaps.docs) {
    print('Deleting session: ${doc.id} (Date: ${doc.data()['date']})');
    
    // Xóa tất cả records bên trong subcollection 'records' của phiên này
    final recordsSnap = await doc.reference.collection('records').get();
    for (var r in recordsSnap.docs) {
      await r.reference.delete();
    }
    
    // Xóa phiên
    await doc.reference.delete();
  }
  
  print('Done deleting!');
}
