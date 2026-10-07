import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/arena/screens/gacom_apk_downloader.dart';
import '../theme/app_theme.dart';

/// What the release manifest (latest.json) says about the newest app.
class AppUpdateInfo {
  final int build;
  final int minBuild;
  final String version;
  final List<String> notes;
  final String fullUrl;
  final String arm64Url;
  final double fullMb;
  final double arm64Mb;
  const AppUpdateInfo({
    required this.build,
    required this.minBuild,
    required this.version,
    required this.notes,
    required this.fullUrl,
    required this.arm64Url,
    required this.fullMb,
    required this.arm64Mb,
  });

  static double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  static AppUpdateInfo? parse(String body) {
    try {
      final dynamic j = jsonDecode(body);
      if (j is! Map) return null;
      final dynamic n = j['notes'];
      final List<String> notes = n is List ? n.map((dynamic e) => '$e').toList() : (n is String && n.isNotEmpty ? <String>[n] : <String>[]);
      final int build = (j['build'] is num) ? (j['build'] as num).toInt() : int.tryParse('${j['build']}') ?? 0;
      final int minBuild = (j['min_build'] is num) ? (j['min_build'] as num).toInt() : int.tryParse('${j['min_build']}') ?? 0;
      return AppUpdateInfo(
        build: build,
        minBuild: minBuild,
        version: '${j['version'] ?? ''}',
        notes: notes,
        fullUrl: '${j['full_url'] ?? AppUpdateService.fullUrl}',
        arm64Url: '${j['arm64_url'] ?? ''}',
        fullMb: _num(j['full_mb']),
        arm64Mb: _num(j['arm64_mb']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Checks for a newer GACOM on startup and offers a one-tap update.
/// Android app only; does nothing on the web or on other platforms.
class AppUpdateService {
  static const String base = 'https://rxccipqvyrcfpsadgpzp.supabase.co/storage/v1/object/public/app-releases';
  static const String manifestUrl = '$base/latest.json';
  static const String fullUrl = '$base/gacom-latest.apk';
  static const String arm64Url = '$base/gacom-latest-arm64.apk';
  static const String _snoozeKey = 'update_snooze_until';

  static bool _checked = false;

  static Future<AppUpdateInfo?> fetch() async {
    try {
      final http.Response r = await http
          .get(Uri.parse('$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return AppUpdateInfo.parse(r.body);
    } catch (_) {
      return null;
    }
  }

  /// The right file for this phone: the small 64-bit build when the phone
  /// supports it and the release has one, otherwise the standard build.
  static Future<String> urlFor(AppUpdateInfo info) async {
    try {
      final AndroidDeviceInfo d = await DeviceInfoPlugin().androidInfo;
      if (d.supportedAbis.contains('arm64-v8a') && info.arm64Url.isNotEmpty) return info.arm64Url;
    } catch (_) {}
    return info.fullUrl;
  }

  /// The build number this app was compiled with. release_android.sh passes
  /// it with --dart-define=APP_BUILD=<number>. A build made without it is 0,
  /// and then no update prompt is shown.
  static const int _compiledBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

  static Future<int> currentBuild() async => _compiledBuild;

  /// Call once the app is on screen. Shows a dialog only when a newer build exists.
  static Future<void> maybePrompt(BuildContext context) async {
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _checked = true;
    final AppUpdateInfo? info = await fetch();
    if (info == null) return;
    final int mine = await currentBuild();
    if (mine <= 0 || info.build <= mine) return;
    final bool forced = info.minBuild > mine;

    if (!forced) {
      try {
        final SharedPreferences p = await SharedPreferences.getInstance();
        final int until = p.getInt(_snoozeKey) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch < until) return;
      } catch (_) {}
    }
    if (!context.mounted) return;

    final String url = await urlFor(info);
    final double mb = url == info.arm64Url ? info.arm64Mb : info.fullMb;
    if (!context.mounted) return;

    final bool? go = await showDialog<bool>(
      context: context,
      barrierDismissible: !forced,
      builder: (BuildContext c) => WillPopScope(
        onWillPop: () async => !forced,
        child: AlertDialog(
          backgroundColor: GacomColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(forced ? 'Update required' : 'Update available', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(
              'GACOM ${info.version.isEmpty ? 'has a new version' : info.version}${mb > 0 ? '  -  ${mb.toStringAsFixed(0)} MB' : ''}',
              style: const TextStyle(color: GacomColors.deepOrange, fontWeight: FontWeight.w800),
            ),
            if (forced) ...<Widget>[
              const SizedBox(height: 6),
              const Text('This version is too old to keep working. Please update to continue.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
            ],
            if (info.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              for (final String n in info.notes.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    const Text('-  ', style: TextStyle(color: GacomColors.textSecondary)),
                    Expanded(child: Text(n, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 13, height: 1.3))),
                  ]),
                ),
            ],
            const SizedBox(height: 8),
            const Text('Your account and progress stay as they are. Android will ask you to confirm the install.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
          ]),
          actions: <Widget>[
            if (!forced) TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Later')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('UPDATE NOW'),
            ),
          ],
        ),
      ),
    );

    if (go == true) {
      if (!context.mounted) return;
      await downloadAndInstallGacomApk(context, url: url);
    } else {
      try {
        final SharedPreferences p = await SharedPreferences.getInstance();
        await p.setInt(_snoozeKey, DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch);
      } catch (_) {}
    }
  }
}
