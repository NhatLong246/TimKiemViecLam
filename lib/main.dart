import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'controller/login_controller.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('vi', null);
  final authController = Get.put(AuthController());
  await authController.prepareSessionOnStartup();
  runApp(MyApp());
}
