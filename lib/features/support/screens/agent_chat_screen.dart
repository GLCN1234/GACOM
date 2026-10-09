import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Old agent view. Staff now work from the support desk, so this simply
/// forwards to it.
class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement('/support/desk');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Center(
          child: CircularProgressIndicator(color: GacomColors.deepOrange)),
    );
  }
}
