import 'package:flutter/material.dart';
import '../messaging/conversation_list_screen.dart';

class EmployerMessagesScreen extends StatelessWidget {
  const EmployerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConversationListScreen(isEmployer: true);
  }
}
