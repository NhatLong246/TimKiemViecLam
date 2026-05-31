import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/candidate_profile_models.dart';

class CandidateProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<List<Map<String, dynamic>>> _readList(String field) async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    final raw = doc.data()?[field];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _writeList(String field, List<Map<String, dynamic>> list) async {
    await _firestore.collection('users').doc(_uid).update({
      field: list,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveSelfIntroduction(String text) async {
    await _firestore.collection('users').doc(_uid).update({
      'selfIntroduction': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveSkills(List<String> skills) async {
    await _firestore.collection('users').doc(_uid).update({
      'skills': skills.map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addEducation(EducationModel item) async {
    await _firestore.collection('users').doc(_uid).update({
      'educations': FieldValue.arrayUnion([item.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEducation(EducationModel item) async {
    final list = await _readList('educations');
    final index = list.indexWhere((e) => e['id']?.toString() == item.id);
    if (index >= 0) list[index] = item.toMap();
    await _writeList('educations', list);
  }

  Future<void> removeEducation(String id) async {
    final list = await _readList('educations');
    list.removeWhere((e) => e['id']?.toString() == id);
    await _writeList('educations', list);
  }

  Future<void> addProject(ProjectModel item) async {
    await _firestore.collection('users').doc(_uid).update({
      'projects': FieldValue.arrayUnion([item.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProject(ProjectModel item) async {
    final list = await _readList('projects');
    final index = list.indexWhere((e) => e['id']?.toString() == item.id);
    if (index >= 0) list[index] = item.toMap();
    await _writeList('projects', list);
  }

  Future<void> removeProject(String id) async {
    final list = await _readList('projects');
    list.removeWhere((e) => e['id']?.toString() == id);
    await _writeList('projects', list);
  }

  Future<void> addLanguage(LanguageModel item) async {
    final list = await _readList('languages');
    final exists = list.any((e) => e['id']?.toString() == item.id);
    if (exists) {
      await updateLanguage(item);
      return;
    }
    list.add(item.toMap());
    await _writeList('languages', list);
  }

  Future<void> updateLanguage(LanguageModel item) async {
    final list = await _readList('languages');
    final index = list.indexWhere((e) => e['id']?.toString() == item.id);
    if (index >= 0) list[index] = item.toMap();
    await _writeList('languages', list);
  }

  Future<void> removeLanguage(String id) async {
    final list = await _readList('languages');
    list.removeWhere((e) => e['id']?.toString() == id);
    await _writeList('languages', list);
  }

  Future<String> uploadCertificateImage(File file, String certificateId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$_uid/certificates/$certificateId.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> addCertificate(CertificateModel item) async {
    await _firestore.collection('users').doc(_uid).update({
      'certificates': FieldValue.arrayUnion([item.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCertificate(CertificateModel item) async {
    final list = await _readList('certificates');
    final index = list.indexWhere((e) => e['id']?.toString() == item.id);
    if (index >= 0) list[index] = item.toMap();
    await _writeList('certificates', list);
  }

  Future<void> removeCertificate(String id) async {
    final list = await _readList('certificates');
    list.removeWhere((e) => e['id']?.toString() == id);
    await _writeList('certificates', list);
  }
}
