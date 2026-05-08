import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bank_account_model.dart';

class BankAccountService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  CollectionReference get _bankRef =>
      _firestore.collection('users').doc(uid).collection('bank_accounts');

  Future<void> addBank(BankAccountModel bank) async {
    await _bankRef.add(bank.toMap());
  }

  Future<void> updateBank(BankAccountModel bank) async {
    await _bankRef.doc(bank.id).update(bank.toMap());
  }

  Future<void> deleteBank(String id) async {
    await _bankRef.doc(id).delete();
  }

  Stream<List<BankAccountModel>> getBanks() {
    return _bankRef.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        return BankAccountModel.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }).toList(),
    );
  }
}
