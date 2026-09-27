import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import '../../../core/theme/app_theme.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart' as web_download;

const _apkUrl = 'https://rxccipqvyrcfpsadgpzp.supabase.co/storage/v1/object/public/app-releases/gacom-latest.apk';

/// One real progress-bar experience for both platforms — the only
/// difference is how the finished file gets delivered at the end,
/// since a browser can never hand a file directly to the system
/// installer the way an already-installed app can. On web, it's saved
/// as a correctly MIME-typed blob, which is what lets Chrome offer its
/// own "tap to install" action once the download finishes — the same
/// behavior people are used to seeing from other APK downloads.
Future<void> downloadAndInstallGacomApk(BuildContext context) async {
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
    if (kIsWeb) {
      // dio works on web too (via the browser's own fetch under the
      // hood), so the same real progress tracking applies here —
      // fetching raw bytes rather than saving to a real file system,
      // since a browser doesn't have one to write to directly.
      final response = await Dio().get<List<int>>(
        _apkUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      status.value = 'Starting install...';
      web_download.saveWebDownload(Uint8List.fromList(response.data!), 'gacom-latest.apk');
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    } else {
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

      // Hands the file to Android's own installer — the same "verify
      // and install" flow, not a raw browser download.
      await OpenFile.open(savePath);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}
