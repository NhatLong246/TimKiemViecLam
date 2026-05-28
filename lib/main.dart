import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'controller/login_controller.dart';
import 'firebase_options.dart';

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hot restart (R) chạy lại main — tránh init Firebase/Firestore lần 2 gây treo.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  await initializeDateFormatting('vi', null);

  if (!Get.isRegistered<AuthController>()) {
    Get.put(AuthController(), permanent: true);
  }
}

void main() async {
  await _bootstrap();
  runApp(const MyApp());
  // Khôi phục phiên trên nền — không chặn splash/UI.
  Get.find<AuthController>().prepareSessionOnStartup();
}
