import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import '../../../core/theme/app_theme.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart' as web_download;

const _apkUrl = 'https://rxccipqvyrcfpsadgpzp.supabase.co/storage/v1/object/public/app-releases/gacom-latest.apk';

/// In the Android app: downloads the APK with a progress bar and hands it
/// to Android's installer. In a browser: opens the /download page.
Future<void> downloadAndInstallGacomApk(BuildContext context, {String? url}) async {
  // A browser cannot hand a file to the installer, so on the web we send
  // the person to the download page, which picks the right file and walks
  // them through installing it. The browser's own download manager is far
  // more reliable than holding the whole file in memory.
  if (kIsWeb) {
    web_download.openDownloadPage();
    return;
  }
  final String apk = url ?? _apkUrl;
  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('Starting download...');
  bool dialogOpen = true;

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
    {
      // Dart's own temp directory: no plugin needed at all, sidesteps
      // the path_provider Android registration issue entirely.
      final dir = Directory.systemTemp;
      final savePath = '${dir.path}/gacom-update.apk';
      final f = File(savePath);
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }

      await Dio().download(
        apk,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );

      if (await f.length() < 1024 * 1024) {
        throw Exception('The download did not finish. Please try again.');
      }

      status.value = 'Ready to install...';
      if (dialogOpen && context.mounted) Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;

      // Hands the file to Android's own installer: the same "verify
      // and install" flow, not a raw browser download.
      final result = await OpenFile.open(savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message.isEmpty ? 'Could not open the installer. Allow installs from GACOM in settings, then try again.' : result.message)));
      }
    }
  } catch (e) {
    if (context.mounted) {
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed. Check your connection and try again.')));
    }
  }
}
