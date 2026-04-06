import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: GacomColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Search players, communities, games...', border: InputBorder.none, hintStyle: TextStyle(color: GacomColors.textMuted)),
        ),
      ),
      body: const Center(child: Text('Type to search...', style: TextStyle(color: GacomColors.textMuted))),
    );
  }
}
