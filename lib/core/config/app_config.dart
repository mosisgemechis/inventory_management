import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/database_service.dart';

/// Centralized, dynamic API base URL resolver.
///
/// Resolution order (first match wins):
///   1. `API_BASE_URL` in `.env` file
///   2. `api_base_url` key in app_settings DB  (LAN IPs are skipped on Desktop)
///   3. Platform-aware discovery:
///      • Desktop (Windows/macOS/Linux) → http://localhost:8000
///      • Android Emulator              → http://10.0.2.2:8000   (probed first)
///      • Physical Android device       → subnet-probe for host running :8000
abstract final class AppConfig {
  static const int _port = 8000;
  static const String _emulatorHost = '10.0.2.2'; // Android emulator host alias
  static String? _cachedBaseUrl;

  // Scan cooldown — prevents doing a full 253-host subnet scan more than once per minute.
  static DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(minutes: 1);
  static bool _isScanning = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<String> get apiBaseUrl async {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      debugPrint('[API CONFIG] Using cached backend = $_cachedBaseUrl');
      return _cachedBaseUrl!;
    }

    debugPrint('[API CONFIG] Resolving backend...');

    // 1. Explicit .env override
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      _cachedBaseUrl = _normalize(envUrl.trim());
      debugPrint('[API CONFIG] Backend resolved = $_cachedBaseUrl');
      return _cachedBaseUrl!;
    }

    // 2. Dynamic discovery: Probes ADB reverse (USB 127.0.0.1:8000) first,
    // emulator (10.0.2.2:8000) second, verified DB URL third, then subnet scan.
    _cachedBaseUrl = await _discoverUrl();
    debugPrint('[API CONFIG] Backend resolved = $_cachedBaseUrl');
    return _cachedBaseUrl!;
  }

  /// Override at runtime (e.g. from settings screen). Persists for this session.
  static void setApiBaseUrl(String url) {
    _cachedBaseUrl = _normalize(url.trim());
    debugPrint('[API CONFIG] Backend resolved = $_cachedBaseUrl');
  }

  /// Force fresh resolution on the next [apiBaseUrl] call.
  /// NOTE: Does NOT reset the scan cooldown so concurrent callers
  /// don't all trigger a subnet scan simultaneously.
  static void clearCache() {
    _cachedBaseUrl = null;
  }

  /// Clear cache AND reset scan cooldown — only call this intentionally
  /// (e.g. when the user explicitly changes the server address).
  static void clearCacheAndCooldown() {
    _cachedBaseUrl = null;
    _lastScanTime = null;
  }

  // ── Discovery ───────────────────────────────────────────────────────────────

  static Future<String> _discoverUrl() async {
    if (kIsWeb) return 'http://127.0.0.1:$_port';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$_port';
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return await _resolveAndroidUrl();
    }

    return 'http://127.0.0.1:$_port';
  }

  static Future<bool> _isEmulator() async {
    return await _tcpProbe(_emulatorHost, _port,
        timeout: const Duration(milliseconds: 300));
  }

  /// Android resolution:
  ///   a) Probe 127.0.0.1:8000 first → succeeds instantly when ADB reverse (USB) is active.
  ///   b) Probe 10.0.2.2:8000 second → succeeds instantly on Android Emulator.
  ///   c) Check stored DB URL (fast path — avoids scan when URL is known).
  ///   d) Probe every IPv4 address in the device's local subnet in parallel.
  ///      A 60-second cooldown prevents repeated scans on every connectivity check.
  ///   e) If nothing found, return http://127.0.0.1:8000 (IPv4 fallback).
  static Future<String> _resolveAndroidUrl() async {
    // (a) USB ADB Reverse check (127.0.0.1:8000)
    if (await _tcpProbe('127.0.0.1', _port, timeout: const Duration(milliseconds: 600))) {
      final url = 'http://127.0.0.1:$_port';
      debugPrint('[AppConfig] Device: ADB Reverse active on 127.0.0.1:$_port');
      // Persist so cold-starts skip the scan
      try { await DatabaseService().saveSetting('api_base_url', url); } catch (_) {}
      return url;
    }

    // (b) Android Emulator check (10.0.2.2:8000)
    if (await _isEmulator()) {
      final url = 'http://$_emulatorHost:$_port';
      debugPrint('[AppConfig] Device: Android Emulator');
      try { await DatabaseService().saveSetting('api_base_url', url); } catch (_) {}
      return url;
    }

    // (c) Fast path: use stored URL only if it is actually reachable right now
    try {
      final stored = await DatabaseService().getSetting('api_base_url');
      if (stored != null && stored.trim().isNotEmpty) {
        final url = _normalize(stored.trim());
        if (await _tcpProbe(Uri.parse(url).host, Uri.parse(url).port, timeout: const Duration(milliseconds: 600))) {
          debugPrint('[AppConfig] Using verified stored backend URL: $url');
          _cachedBaseUrl = url;
          return url;
        }
        debugPrint('[AppConfig] Stored backend URL unreachable: $url (clearing stale setting)');
        try { await DatabaseService().saveSetting('api_base_url', ''); } catch (_) {}
      }
    } catch (_) {}

    // (d) Cooldown guard — only scan once per minute to avoid log flood
    final now = DateTime.now();
    const fallback = 'http://127.0.0.1:$_port';
    if (_isScanning) {
      debugPrint('[AppConfig] Subnet scan already in progress — returning fallback.');
      return fallback;
    }
    if (_lastScanTime != null && now.difference(_lastScanTime!) < _scanCooldown) {
      debugPrint('[AppConfig] Subnet scan cooldown active — returning fallback.');
      return fallback;
    }

    _isScanning = true;
    _lastScanTime = now;
    debugPrint('[AppConfig] Scanning local subnet for development host on :$_port…');
    final discovered = await _subnetScan(_port);
    _isScanning = false;

    if (discovered != null) {
      debugPrint('[AppConfig] Development backend discovered: $discovered');
      try {
        await DatabaseService().saveSetting('api_base_url', discovered);
      } catch (_) {}
      _cachedBaseUrl = discovered;
      return discovered;
    }

    // (e) Nothing found — return IPv4 loopback fallback (unverified, do not cache)
    debugPrint('[AppConfig] No host found on subnet — using 127.0.0.1 fallback.');
    return fallback;
  }


  /// Scans every non-self IPv4 host in the device's local subnet (all /24
  /// prefixes found on active interfaces) using parallel TCP probes.
  ///
  /// Race pattern: returns the first host that responds, or null after [timeout].
  static Future<String?> _subnetScan(
    int port, {
    Duration probeTimeout = const Duration(milliseconds: 500),
    Duration scanTimeout = const Duration(seconds: 3),
  }) async {
    final Set<String> candidates = {};
    String? selfIp;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          if (parts.length != 4) continue;
          selfIp = ip;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (int i = 1; i <= 254; i++) {
            final candidate = '$prefix.$i';
            if (candidate != ip) candidates.add(candidate);
          }
        }
      }
    } catch (e) {
      debugPrint('[AppConfig] NetworkInterface error: $e');
    }

    if (candidates.isEmpty) {
      debugPrint('[AppConfig] No subnet candidates found (selfIp=$selfIp)');
      return null;
    }

    debugPrint('[AppConfig] Probing ${candidates.length} subnet candidates on :$port (selfIp=$selfIp)…');

    final completer = Completer<String?>();
    int remaining = candidates.length;

    for (final host in candidates) {
      _tcpProbe(host, port, timeout: probeTimeout).then((ok) {
        remaining--;
        if (ok && !completer.isCompleted) {
          completer.complete('http://$host:$port');
        } else if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future.timeout(scanTimeout, onTimeout: () {
      if (!completer.isCompleted) completer.complete(null);
      return null;
    });
  }

  /// Returns true if a TCP connection to [host]:[port] succeeds within [timeout].
  static Future<bool> _tcpProbe(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Utilities ───────────────────────────────────────────────────────────────

  /// Ensures the URL starts with http:// or https:// and has no trailing slash.
  static String _normalize(String url) {
    var u = url;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    // Remove accidental double-slashes in path (but keep ://)
    u = u.replaceAllMapped(
      RegExp(r'(?<!:)//'),
      (_) => '/',
    );
    return u.trimRight().endsWith('/')
        ? u.trimRight().substring(0, u.trimRight().length - 1)
        : u.trimRight();
  }
}
