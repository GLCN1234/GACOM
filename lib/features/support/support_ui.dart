import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/gacom_snackbar.dart';
import 'support_service.dart';

/// Shared look and small helpers for the support screens.
class SupportUi {
  static const appVersion = '1.0.0';

  static Map<String, dynamic> deviceInfo() => {
        'platform': defaultTargetPlatform.name,
        'is_web': kIsWeb,
        'app_version': appVersion,
      };

  static String pretty(String s) {
    if (s.isEmpty) return '';
    final t = s.replaceAll('_', ' ');
    return t[0].toUpperCase() + t.substring(1);
  }

  static String statusLabel(String s, {bool staff = false}) {
    switch (s) {
      case 'new':
        return 'New';
      case 'assistant_replied':
        return staff ? 'Assistant replied' : 'Ryan replied';
      case 'open':
        return staff ? 'Open' : 'With the team';
      case 'pending_user':
        return staff ? 'Waiting for user' : 'Waiting for you';
      case 'escalated':
        return 'Escalated';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return pretty(s);
    }
  }

  static Color statusColor(String s) {
    switch (s) {
      case 'new':
        return GacomColors.info;
      case 'assistant_replied':
        return GacomColors.violet;
      case 'open':
        return GacomColors.deepOrange;
      case 'pending_user':
        return GacomColors.warning;
      case 'escalated':
        return GacomColors.error;
      case 'resolved':
        return GacomColors.success;
      default:
        return GacomColors.textMuted;
    }
  }

  static Color priorityColor(String p) {
    switch (p) {
      case 'urgent':
        return GacomColors.error;
      case 'high':
        return GacomColors.deepOrange;
      case 'normal':
        return GacomColors.info;
      default:
        return GacomColors.textMuted;
    }
  }

  static bool isDone(String status) =>
      status == 'resolved' || status == 'closed';

  static String duration(Duration d) {
    final m = d.inMinutes.abs();
    if (m >= 1440) return '${m ~/ 1440}d ${(m % 1440) ~/ 60}h';
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m < 1 ? 1 : m}m';
  }

  /// "2h 10m left" or "overdue 15m".
  static String dueText(DateTime due) {
    final diff = due.difference(DateTime.now());
    return diff.isNegative
        ? 'Overdue ${duration(diff)}'
        : '${duration(diff)} left';
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  static String clock(DateTime t) {
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static BoxDecoration card({Color? border, Color? fill}) => BoxDecoration(
        color: fill ?? GacomColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? GacomColors.borderBright),
      );

  static TextStyle heading({double size = 16, Color? color}) => TextStyle(
        fontFamily: 'Rajdhani',
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: color ?? GacomColors.textPrimary,
      );

  static const body = TextStyle(
      fontSize: 14, height: 1.4, color: GacomColors.textPrimary);
  static const muted = TextStyle(fontSize: 12, color: GacomColors.textMuted);
}

class SupportChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const SupportChip(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class SupportEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const SupportEmpty(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: GacomColors.textMuted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: SupportUi.heading(size: 18)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: GacomColors.textSecondary, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

class SupportLoading extends StatelessWidget {
  const SupportLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: GacomColors.deepOrange));
}

/// Simple confirm dialog that returns true when confirmed.
Future<bool> supportConfirm(BuildContext context, String title, String message,
    {String confirm = 'Confirm'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GacomColors.elevatedCard,
      title: Text(title, style: SupportUi.heading(size: 18)),
      content: Text(message,
          style: const TextStyle(color: GacomColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return r == true;
}

/// Dialog with a multi-line text field. Returns the text or null if cancelled.
Future<String?> supportTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String confirm = 'Save',
  String initial = '',
  bool required = false,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GacomColors.elevatedCard,
      title: Text(title, style: SupportUi.heading(size: 18)),
      content: TextField(
        controller: ctrl,
        maxLines: 5,
        minLines: 3,
        maxLength: 2000,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (required && t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: Text(confirm)),
      ],
    ),
  );
}

/// Small tappable chip for a stored attachment. Opens a short-lived signed link.
class SupportAttachmentLink extends StatelessWidget {
  final String path;
  const SupportAttachmentLink(this.path, {super.key});

  Future<void> _open(BuildContext context) async {
    final url = await SupportService.attachmentUrl(path);
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        GacomSnackbar.show(context, 'Could not open this file right now',
            isError: true);
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final name = path.split('/').last;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GacomColors.borderBright),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.attach_file_rounded,
              size: 14, color: GacomColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: GacomColors.textSecondary)),
          ),
        ]),
      ),
    );
  }
}
