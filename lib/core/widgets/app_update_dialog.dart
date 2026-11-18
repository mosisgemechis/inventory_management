import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/navigation.dart';
import '../services/app_update_service.dart';
import '../constants/colors.dart';

/// Checks for a newer release and, when one exists, shows the update dialog.
///
/// Safe to call on every launch: it never throws and does nothing when the
/// device is offline, the feed is unreachable, or the app is already current.
Future<void> checkForAppUpdateAndPrompt() async {
  try {
    final info = await AppUpdateService.instance.checkForUpdate();
    if (info == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showAppUpdateDialog(context, info);
  } catch (e) {
    debugPrint('[UPDATE] Prompt skipped: $e');
  }
}

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AppUpdateDialog(info: info),
  );

  if (action == 'later') {
    await AppUpdateService.instance.postpone(info.latestVersion);
    return;
  }
  if (action == 'update' && info.downloadUrl.isNotEmpty) {
    await _openUpdate(info);
  }
}

Future<void> _openUpdate(AppUpdateInfo info) async {
  final uri = Uri.tryParse(info.downloadUrl);
  if (uri == null) return;
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && info.releaseUrl.isNotEmpty) {
      await launchUrl(Uri.parse(info.releaseUrl),
          mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('[UPDATE] Could not open download link: $e');
  }
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.45;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.system_update_alt_rounded,
                color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Update available', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are on ${info.currentVersion} · latest is ${info.latestVersion}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            if (info.hasNotes) ...[
              const SizedBox(height: 14),
              const Text("What's new",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Text(info.notes),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _installHint(),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('later'),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop('update'),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update now'),
        ),
      ],
    );
  }

  String _installHint() {
    if (!kIsWeb && Platform.isAndroid) {
      return 'Your data stays on this device. Open the downloaded file to install '
          'the update over the current app (do not uninstall first).';
    }
    if (!kIsWeb && Platform.isWindows) {
      return 'Close the app, run the downloaded installer, and reopen it. Your '
          'local database and settings are kept.';
    }
    return 'Download the new build and install it over the current app. Your '
        'local data is kept.';
  }
}
