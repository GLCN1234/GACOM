import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

const _apkUrl = 'https://rxccipqvyrcfpsadgpzp.supabase.co/storage/v1/object/public/app-releases/gacom-latest.apk';

/// This button lives on the same Game Store screen whether someone's
/// using the website in a browser or the already-installed app — but
/// dart:io file operations (and the system installer handoff) genuinely
/// cannot work in a browser at all. On web, hand off to the browser's
/// own native download instead of trying to use mobile-only APIs.
Future<void> downloadAndInstallGacomApk(BuildContext context) async {
  if (kIsWeb) {
    await launchUrl(Uri.parse(_apkUrl), mode: LaunchMode.platformDefault);
    return;
  }
  await _downloadAndInstallOnMobile(context);
}

/// Real in-app download with progress, instead of handing off to the
/// browser's own generic download UI — downloads the APK to the app's
/// own cache, then triggers the system installer directly on
/// completion, matching how the Play Store's own install flow feels.
/// Only ever called on a real mobile install, never on web.
Future<void> _downloadAndInstallOnMobile(BuildContext context) async {
  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('Starting download...');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Downloading GACOM', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(value: value > 0 ? value : null, backgroundColor: GacomColors.border, color: GacomColors.deepOrange, minHeight: 8),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => Text('${(value * 100).toStringAsFixed(0)}%', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.deepOrange)),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (_, value, __) => Text(value, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
        ),
      ]),
    ),
  );

  try {
    // Dart's own temp directory — no plugin needed at all, sidesteps
    // the path_provider Android registration issue entirely.
    final dir = Directory.systemTemp;
    final savePath = '${dir.path}/gacom-latest.apk';

    await Dio().download(
      _apkUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );

    status.value = 'Ready to install...';
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    // Hands the file to Android's own installer — the same "verify and
    // install" flow the person described, not a raw browser download.
    await OpenFile.open(savePath);
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}
