import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/address_model.dart';

class AddressService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  CollectionReference get _addressRef =>
      _firestore.collection('users').doc(uid).collection('addresses');

  Future<void> addAddress(AddressModel address) async {
    await _addressRef.add(address.toMap());
  }

  Future<void> updateAddress(AddressModel address) async {
    await _addressRef.doc(address.id).update(address.toMap());
  }

  Future<void> deleteAddress(String id) async {
    await _addressRef.doc(id).delete();
  }

  Future<void> setDefaultAddress(String addressId) async {
    final snapshot = await _addressRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.update({'isDefault': false});
    }
    await _addressRef.doc(addressId).update({'isDefault': true});
  }

  Stream<List<AddressModel>> getAddresses() {
    return _addressRef.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        return AddressModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList(),
    );
  }
}
