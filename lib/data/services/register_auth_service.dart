import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerUser({
    required UserModel userModel,
    required String password,
  }) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: userModel.email,
      password: password,
    );
    User? firebaseUser = credential.user;
    if (firebaseUser != null) {
      await firebaseUser.sendEmailVerification();
      String uid = firebaseUser.uid;
      UserModel updatedUserModel = UserModel(
        id: uid,
        firstName: userModel.firstName,
        lastName: userModel.lastName,
        username: userModel.username,
        email: userModel.email,
        phone: userModel.phone,
      );
      await _firestore
          .collection("users")
          .doc(uid)
          .set(updatedUserModel.toMap());
    }
    return firebaseUser;
  }
}
