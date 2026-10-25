import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import 'chat_view.dart';

/// The AI Dorm Manager tab for a logged-in tenant or landlord.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChatView(mode: user.isLandlord ? 'landlord' : 'tenant');
  }
}

/// Opened from the login screen: a visitor without an account asks about the dorm.
class VisitorChatScreen extends StatelessWidget {
  const VisitorChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: brandAppBar('Ask about the dorm'),
      body: const ChatView(mode: 'visitor'),
    );
  }
}
