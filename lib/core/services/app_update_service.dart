import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable description of a published update.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.notes,
    required this.releaseUrl,
    required this.downloadUrl,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final String notes;
  final String releaseUrl;
  final String downloadUrl;
  final DateTime? publishedAt;

  bool get isAndroidApk =>
      downloadUrl.toLowerCase().endsWith('.apk') &&
      !kIsWeb &&
      Platform.isAndroid;

  bool get hasNotes => notes.trim().isNotEmpty;
}

/// Checks the published GitHub Releases feed for a newer build of this app.
///
/// Update channel: `https://api.github.com/repos/<owner>/<repo>/releases/latest`
/// (override with `UPDATE_FEED_URL` in `.env`).
///
/// The check is deliberately fail-safe: it is offline-first, never throws into
/// the UI, and never blocks startup. Installing a new build over the old one
/// keeps local data because the application id and the SQLite database file
/// are unchanged; schema upgrades are additionally backed up by
/// `AppDatabase` before migrations run.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// Repository that publishes release builds.
  static const String repository = 'mosisgemechis/inventory_management';

  static const String _defaultFeedUrl =
      'https://api.github.com/repos/$repository/releases/latest';

  /// How often an automatic check may run (launch + manual checks bypass this
  /// only when [checkForUpdate] is called with `ignoreCooldown: true`).
  static const Duration checkCooldown = Duration(hours: 6);

  static const String _prefsLastCheck = 'update_last_checked_at';
  static const String _prefsSkippedVersion = 'update_skipped_version';

  String? _cachedVersion;
  AppUpdateInfo? _cachedUpdate;

  /// Current running version, e.g. `1.0.0` plus its build number.
  Future<String> currentVersion({bool refresh = false}) async {
    if (!refresh && _cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      _cachedVersion = build.isEmpty ? info.version : '${info.version}+$build';
    } catch (e) {
      debugPrint('[UPDATE] Could not read package info: $e');
      _cachedVersion = '0.0.0';
    }
    return _cachedVersion!;
  }

  /// Returns update details when a strictly newer release exists, otherwise
  /// `null`. Never throws.
  ///
  /// [ignoreCooldown] forces a network check (used by a manual "Check now"
  /// action). [includeSkipped] re-offers a version the user postponed.
  Future<AppUpdateInfo?> checkForUpdate({
    bool ignoreCooldown = false,
    bool includeSkipped = false,
  }) async {
    final current = await currentVersion();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    if (!ignoreCooldown && prefs != null) {
      final lastCheck = prefs.getInt(_prefsLastCheck) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (age >= 0 && age < checkCooldown.inMilliseconds) {
        return _cachedUpdate;
      }
    }

    final release = await _fetchLatestRelease();
    if (prefs != null) {
      await prefs.setInt(_prefsLastCheck, DateTime.now().millisecondsSinceEpoch);
    }
    if (release == null) return _cachedUpdate;

    final latest = (release['tag_name'] as String? ?? '').trim();
    if (latest.isEmpty || compareVersions(latest, current) <= 0) {
      _cachedUpdate = null;
      return null;
    }

    if (!includeSkipped && prefs != null) {
      final skipped = prefs.getString(_prefsSkippedVersion);
      if (skipped != null && compareVersions(skipped, latest) >= 0) {
        return null;
      }
    }

    final info = AppUpdateInfo(
      currentVersion: current,
      latestVersion: latest,
      notes: (release['body'] as String? ?? '').trim(),
      releaseUrl: release['html_url'] as String? ?? '',
      downloadUrl: _preferredDownload(release) ??
          (release['html_url'] as String? ?? ''),
      publishedAt: DateTime.tryParse(release['published_at'] as String? ?? ''),
    );
    _cachedUpdate = info;
    return info;
  }

  /// Remembers that the user postponed [version], so the same release is not
  /// offered again on the next launch. A newer release is still offered.
  Future<void> postpone(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSkippedVersion, version);
    } catch (_) {}
  }

  /// Fetches the release JSON, returning `null` on any failure (offline,
  /// rate limit, repository without releases yet).
  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final override = _feedOverride();
    final uri = Uri.tryParse(override ?? _defaultFeedUrl);
    if (uri == null) return null;

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..findProxy = ((_) => 'DIRECT');

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'GM-Inventory-Updater');
      request.headers.set(HttpHeaders.acceptHeader,
          'application/vnd.github+json, application/json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        debugPrint(
            '[UPDATE] Update feed returned ${response.statusCode} (no update check performed)');
        return null;
      }
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[UPDATE] Update check failed: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  String? _feedOverride() {
    try {
      final value = dotenv.env['UPDATE_FEED_URL'];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    } catch (_) {
      // dotenv may not be loaded yet; fall back to the built-in feed.
    }
    return null;
  }

  /// Picks the artifact for this platform, preferring a release asset and
  /// falling back to the release page.
  String? _preferredDownload(Map<String, dynamic> release) {
    final assets = (release['assets'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((a) => a['browser_download_url'] as String? ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        const <String>[];
    if (assets.isEmpty) return null;

    List<String> extensions;
    if (kIsWeb) {
      extensions = const <String>[];
    } else if (Platform.isAndroid) {
      extensions = const <String>['.apk'];
    } else if (Platform.isWindows) {
      extensions = const <String>['.exe', '.msix', '.zip'];
    } else if (Platform.isMacOS) {
      extensions = const <String>['.dmg', '.pkg', '.zip'];
    } else if (Platform.isLinux) {
      extensions = const <String>['.AppImage', '.tar.gz', '.deb', '.zip'];
    } else {
      extensions = const <String>[];
    }

    for (final ext in extensions) {
      for (final url in assets) {
        if (url.toLowerCase().endsWith(ext.toLowerCase())) return url;
      }
    }
    return null;
  }

  /// Compares dotted version strings (`1.2.3+7`, `v1.2.3`, `1.2.3-beta`).
  /// Returns a negative number when [a] is older than [b].
  static int compareVersions(String a, String b) {
    List<int> parse(String value) {
      final core = value
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;
      return core
          .split('.')
          .map((part) =>
              int.tryParse(RegExp(r'\d+').firstMatch(part)?.group(0) ?? '') ?? 0)
          .toList();
    }

    final left = parse(a);
    final right = parse(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}
