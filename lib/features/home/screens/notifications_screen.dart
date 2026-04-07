import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('NOTIFICATIONS')),
    body: const Center(child: Text('Notifications coming soon', style: TextStyle(color: GacomColors.textMuted))),
  );
}
