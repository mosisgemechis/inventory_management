import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();

  factory ConnectionService({
    Connectivity? connectivity,
    HttpClient? httpClient,
    String? baseUrl,
  }) {
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _instance._overrideBaseUrl = baseUrl.trim();
      _instance._baseUrl = baseUrl.trim();
    }
    return _instance;
  }

  ConnectionService._internal()
      : _connectivity = Connectivity(),
        _http = HttpClient();

  final Connectivity _connectivity;
  final HttpClient _http;
  String? _overrideBaseUrl;
  String _baseUrl = 'http://127.0.0.1:8000';
  String get baseUrl => _baseUrl;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChanged => _statusController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pingTimer;
  Timer? _onlineDebounce;

  Future<void> initialize({String? customBaseUrl}) async {
    if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
      _overrideBaseUrl = customBaseUrl.trim();
    }
    // Always clear stale in-memory cache so platform detection runs fresh.
    AppConfig.clearCache();
    _baseUrl = _overrideBaseUrl ?? await AppConfig.apiBaseUrl;
    debugPrint('[ConnectionService] Active API Base URL: $_baseUrl');

    _connSub?.cancel();
    _connSub = _connectivity.onConnectivityChanged.listen((results) async {
      final networkAvailable = results.any((r) => r != ConnectivityResult.none);
      if (!networkAvailable) {
        debugPrint('[ConnectionService] Network interface lost — setting offline');
        _setOnline(false);
      } else {
        // Network interface appeared. Use force:true to clear the scan cooldown
        // so subnet discovery can find the backend PC at its Wi-Fi IP.
        debugPrint('[ConnectionService] Network interface restored — probing backend (force=true)');
        await checkBackendReachability(force: true);
      }
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      checkBackendReachability();
    });
  }

  DateTime? _lastCheckTime;

  /// Update online status directly from authoritative API responses.
  void reportSuccess() {
    _lastCheckTime = DateTime.now();
    _setOnline(true);
  }

  void reportFailure(dynamic error) {
    if (error is SocketException || error is TimeoutException || error.toString().contains('SocketException')) {
      _setOnline(false);
    }
  }

  /// Direct HTTP probe to /health endpoint.
  /// On failure, only re-resolves when the current URL is a non-loopback LAN
  /// address (hotspot IP may have changed). Never re-triggers discovery when
  /// already on 127.0.0.1 — avoids scan-storm / log-flood during offline mode.
  Future<bool> checkBackendReachability({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _isOnline && _lastCheckTime != null && now.difference(_lastCheckTime!).inSeconds < 10) {
      return true;
    }
    _lastCheckTime = now;

    // Stage 1: quick probe of current URL
    try {
      final uri = Uri.parse(_baseUrl.trimRight()).resolve('/health');
      final req = await _http.getUrl(uri).timeout(const Duration(seconds: 3));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      resp.drain();
      if (resp.statusCode == 200) {
        _setOnline(true);
        return true;
      }
    } catch (_) {}

    // Stage 2: Attempt re-discovery when current _baseUrl is unreachable.
    // When force=true (e.g. user initiated login or network change), always clear
    // the scan cooldown so subnet discovery can find the backend PC on Wi-Fi.
    // Also clear cooldown when _baseUrl is the loopback fallback (127.0.0.1) —
    // that means a previous scan returned nothing and we should retry sooner.
    if (_overrideBaseUrl == null) {
      final isLoopbackFallback = _baseUrl.contains('127.0.0.1');
      if (force || isLoopbackFallback) {
        AppConfig.clearCacheAndCooldown();
      } else {
        AppConfig.clearCache();
      }
      try {
        final freshUrl = await AppConfig.apiBaseUrl;
        if (freshUrl.isNotEmpty) {
          final uri2 = Uri.parse(freshUrl.trimRight()).resolve('/health');
          final req2 = await _http.getUrl(uri2).timeout(const Duration(seconds: 3));
          final resp2 = await req2.close().timeout(const Duration(seconds: 3));
          resp2.drain();
          if (resp2.statusCode == 200) {
            _baseUrl = freshUrl;
            _setOnline(true);
            return true;
          }
        }
      } catch (_) {}
    }

    _setOnline(false);
    return false;
  }

  /// Returns true when the device has an active network interface.
  /// Intentionally does NOT fall back to checkBackendReachability to avoid recursion.
  Future<bool> hasNetworkInterface() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // assume network available if plugin fails
    }
  }

  /// Backwards-compatible alias.
  Future<bool> hasInternet() => hasNetworkInterface();

  void _setOnline(bool online) {
    if (!online) {
      // Going offline: cancel any pending "go online" debounce and immediately set offline
      _onlineDebounce?.cancel();
      _onlineDebounce = null;
      if (_isOnline != false) {
        _isOnline = false;
        debugPrint('[ConnectionService] Connection state changed: isOnline = false');
        if (!_statusController.isClosed) {
          _statusController.add(false);
        }
      }
    } else {
      // Going online: debounce to avoid false positives from brief LAN discovery hits.
      // Only emit true after the state stays online for 1.5 seconds.
      _onlineDebounce?.cancel();
      _onlineDebounce = Timer(const Duration(milliseconds: 1500), () {
        if (_isOnline != true) {
          _isOnline = true;
          debugPrint('[ConnectionService] Connection state changed: isOnline = true');
          if (!_statusController.isClosed) {
            _statusController.add(true);
          }
        }
      });
    }
  }

  void dispose() {
    _connSub?.cancel();
    _pingTimer?.cancel();
    _onlineDebounce?.cancel();
    _connSub = null;
    _pingTimer = null;
    _onlineDebounce = null;
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}
