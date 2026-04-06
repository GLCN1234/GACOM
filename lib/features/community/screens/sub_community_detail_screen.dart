import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SubCommunityDetailScreen extends StatelessWidget {
  final String communityId;
  final String subId;
  const SubCommunityDetailScreen({super.key, required this.communityId, required this.subId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SUB-COMMUNITY')),
    body: const Center(child: Text('Sub-Community Detail', style: TextStyle(color: GacomColors.textMuted))),
  );
}
